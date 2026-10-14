"""
Bank Statement Parser Service
==============================
Parses uploaded bank-statement PDFs (and CSVs) into structured row data.

Supported formats:
  - PDF  — extracted with pdfplumber (falls back to PyMuPDF / raw text)
  - CSV  — pandas / stdlib csv

Row schema (dict):
  {
      "date":        "YYYY-MM-DD",
      "description": str,
      "debit":       float | None,
      "credit":      float | None,
      "balance":     float | None,
      "category":    str | None,   # AI-guessed from description
  }
"""
from __future__ import annotations

import csv
import io
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# ── Common Indian bank date formats ──────────────────────────────────────────
_DATE_FORMATS = [
    "%d/%m/%Y",
    "%d-%m-%Y",
    "%Y-%m-%d",
    "%d %b %Y",
    "%d-%b-%Y",
    "%d/%b/%Y",
    "%d %B %Y",
    "%d-%m-%y",
    "%d/%m/%y",
]

# ── Amount pattern — strips ₹, commas, parentheses (Cr/Dr notation) ──────────
_AMT = re.compile(r"[₹,\s]")

# Simple keyword-based category guesser
_CATEGORY_RULES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\b(zomato|swiggy|domino|pizza|restaurant|cafe|food)\b", re.I), "Food & Dining"),
    (re.compile(r"\b(uber|ola|rapido|metro|irctc|flight|railway|train)\b", re.I), "Travel & Transport"),
    (re.compile(r"\b(amazon|flipkart|myntra|shopping|mall|mart)\b", re.I), "Shopping"),
    (re.compile(r"\b(netflix|spotify|hotstar|prime|subscription|adobe)\b", re.I), "Subscriptions"),
    (re.compile(r"\b(hospital|clinic|pharmacy|medical|doctor|apollo)\b", re.I), "Healthcare"),
    (re.compile(r"\b(electricity|water|gas|broadband|internet|wifi|jio|airtel|bsnl)\b", re.I), "Utilities"),
    (re.compile(r"\b(rent|maintenance|society|housing)\b", re.I), "Housing"),
    (re.compile(r"\b(salary|payroll|income|credit.*salary)\b", re.I), "Income"),
    (re.compile(r"\b(atm|cash|withdrawal)\b", re.I), "Cash"),
    (re.compile(r"\b(emi|loan|mortgage|insurance)\b", re.I), "Finance"),
    (re.compile(r"\b(school|college|tuition|education|course|udemy|coursera)\b", re.I), "Education"),
    (re.compile(r"\b(gym|fitness|sport|yoga)\b", re.I), "Health & Fitness"),
]


def _parse_amount(raw: str | None) -> float | None:
    """Convert an amount string like '₹1,234.56' or '(500.00)' to float."""
    if not raw:
        return None
    raw = raw.strip()
    if not raw or raw in ("-", "—", "N/A"):
        return None
    negative = raw.startswith("(") and raw.endswith(")")
    cleaned = _AMT.sub("", raw).replace("(", "").replace(")", "").strip()
    try:
        val = float(cleaned)
        return -val if negative else val
    except ValueError:
        return None


def _parse_date(raw: str) -> str | None:
    """Try known date formats; return YYYY-MM-DD string or None."""
    raw = raw.strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(raw, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None


def _guess_category(description: str) -> str | None:
    for pattern, category in _CATEGORY_RULES:
        if pattern.search(description):
            return category
    return "Others"


# ── PDF parsing ───────────────────────────────────────────────────────────────

def _extract_text_from_pdf(file_path: str) -> str:
    """Extract raw text from PDF using pdfplumber (preferred) or fallback."""
    try:
        import pdfplumber  # type: ignore

        text_parts: list[str] = []
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    text_parts.append(t)
        return "\n".join(text_parts)
    except ImportError:
        pass

    try:
        import fitz  # PyMuPDF  # type: ignore

        doc = fitz.open(file_path)
        return "\n".join(page.get_text() for page in doc)
    except ImportError:
        pass

    return ""


def _parse_pdf_text(raw_text: str) -> tuple[list[dict], dict[str, Any]]:
    """
    Heuristically parse bank statement text into rows.

    Returns (rows, meta) where meta includes bank_name, account_number, period.
    """
    lines = [ln.strip() for ln in raw_text.splitlines() if ln.strip()]
    rows: list[dict] = []
    meta: dict[str, Any] = {
        "bank_name": None,
        "account_number": None,
        "period_from": None,
        "period_to": None,
    }

    # ── Extract meta from top of statement ───────────────────────────────────
    header_block = "\n".join(lines[:30])

    # Bank name: first non-numeric meaningful line
    for line in lines[:10]:
        if len(line) >= 4 and re.search(r"[a-zA-Z]", line):
            clean = re.sub(r"[^a-zA-Z\s&.]", "", line).strip()
            if len(clean) >= 4:
                meta["bank_name"] = clean[:60]
                break

    # Account number
    acc_m = re.search(
        r"(?:account\s*(?:number|no\.?|#)\s*[:\-]?\s*)(\*{0,4}\d[\d\s\*]{3,})",
        header_block,
        re.I,
    )
    if acc_m:
        acc = re.sub(r"\s+", "", acc_m.group(1))
        meta["account_number"] = f"...{acc[-4:]}" if len(acc) > 4 else acc

    # Period
    period_m = re.search(
        r"(?:from|period)[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})"
        r".*?(?:to)[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})",
        header_block,
        re.I | re.S,
    )
    if period_m:
        meta["period_from"] = _parse_date(period_m.group(1))
        meta["period_to"] = _parse_date(period_m.group(2))

    # ── Detect and parse tabular rows ────────────────────────────────────────
    # Pattern: a line that starts with a date-like token followed by description + amounts
    date_pattern = re.compile(
        r"^(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4})"
        r"\s+(.+?)"
        r"\s+([\d,]+\.\d{2}|-|—)"     # amount 1
        r"(?:\s+([\d,]+\.\d{2}|-|—))?"  # amount 2 (optional)
        r"(?:\s+([\d,]+\.\d{2}|-|—))?$",  # balance (optional)
    )

    for line in lines:
        m = date_pattern.match(line)
        if not m:
            continue

        date_str = _parse_date(m.group(1))
        if not date_str:
            continue

        description = m.group(2).strip()
        amt1 = _parse_amount(m.group(3))
        amt2 = _parse_amount(m.group(4)) if m.lastindex >= 4 else None
        amt3 = _parse_amount(m.group(5)) if m.lastindex >= 5 else None

        # Heuristic: if three amounts, last is balance
        debit: float | None = None
        credit: float | None = None
        balance: float | None = None

        if amt3 is not None:
            balance = amt3
            # Determine debit vs credit from keywords
            desc_lower = description.lower()
            if any(k in desc_lower for k in ("dr", "debit", "withdrawal", "payment", "purchase")):
                debit = amt1
                credit = amt2 if amt2 and amt2 > 0 else None
            else:
                credit = amt1
                debit = amt2 if amt2 and amt2 > 0 else None
        elif amt2 is not None:
            debit = amt1
            credit = amt2
        else:
            # Fallback: single amount, classify by description
            desc_lower = description.lower()
            if any(k in desc_lower for k in ("cr", "credit", "salary", "refund")):
                credit = amt1
            else:
                debit = amt1

        if description:
            rows.append(
                {
                    "date": date_str,
                    "description": description,
                    "debit": debit if debit and debit > 0 else None,
                    "credit": credit if credit and credit > 0 else None,
                    "balance": balance,
                    "category": _guess_category(description),
                }
            )

    return rows, meta


# ── CSV parsing ───────────────────────────────────────────────────────────────

def _parse_csv(file_path: str) -> tuple[list[dict], dict[str, Any]]:
    """Parse a CSV bank statement. Attempts to auto-detect column headers."""
    rows: list[dict] = []
    meta: dict[str, Any] = {
        "bank_name": None,
        "account_number": None,
        "period_from": None,
        "period_to": None,
    }

    with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
        content = f.read()

    # Skip metadata lines before actual table header
    lines = content.splitlines()
    header_idx = 0
    for i, line in enumerate(lines):
        lower = line.lower()
        if "date" in lower and (
            "amount" in lower
            or "debit" in lower
            or "credit" in lower
            or "withdrawal" in lower
        ):
            header_idx = i
            break

    csv_text = "\n".join(lines[header_idx:])
    reader = csv.DictReader(io.StringIO(csv_text))
    if not reader.fieldnames:
        return rows, meta

    # Normalize column names
    col_map: dict[str, str] = {}
    for col in (reader.fieldnames or []):
        lc = col.lower().strip()
        if "date" in lc and "date" not in col_map:
            col_map["date"] = col
        elif any(k in lc for k in ("description", "narration", "particulars", "remarks", "details")):
            col_map["description"] = col
        elif any(k in lc for k in ("debit", "withdrawal", "dr")):
            col_map["debit"] = col
        elif any(k in lc for k in ("credit", "deposit", "cr")):
            col_map["credit"] = col
        elif "balance" in lc:
            col_map["balance"] = col

    dates: list[str] = []
    for csv_row in reader:
        date_raw = csv_row.get(col_map.get("date", ""), "")
        date_str = _parse_date(date_raw)
        if not date_str:
            continue

        description = csv_row.get(col_map.get("description", ""), "").strip()
        debit = _parse_amount(csv_row.get(col_map.get("debit", ""), ""))
        credit = _parse_amount(csv_row.get(col_map.get("credit", ""), ""))
        balance = _parse_amount(csv_row.get(col_map.get("balance", ""), ""))

        dates.append(date_str)
        rows.append(
            {
                "date": date_str,
                "description": description,
                "debit": debit if debit and debit > 0 else None,
                "credit": credit if credit and credit > 0 else None,
                "balance": balance,
                "category": _guess_category(description),
            }
        )

    if dates:
        dates_sorted = sorted(dates)
        meta["period_from"] = dates_sorted[0]
        meta["period_to"] = dates_sorted[-1]

    return rows, meta


# ── Public API ────────────────────────────────────────────────────────────────

def parse_bank_statement(file_path: str) -> dict[str, Any]:
    """
    Parse a bank statement file (PDF or CSV).

    Returns:
        {
            "rows": [...],         # list of parsed transaction dicts
            "bank_name": str|None,
            "account_number": str|None,
            "period_from": str|None,   # YYYY-MM-DD
            "period_to":   str|None,
            "raw_text":    str,
            "total_debits":   float,
            "total_credits":  float,
        }
    """
    path = Path(file_path)
    ext = path.suffix.lower()

    raw_text = ""
    if ext == ".csv":
        rows, meta = _parse_csv(file_path)
    elif ext in (".pdf",):
        raw_text = _extract_text_from_pdf(file_path)
        rows, meta = _parse_pdf_text(raw_text)
    else:
        # Try PDF extraction for unknown types
        raw_text = _extract_text_from_pdf(file_path)
        rows, meta = _parse_pdf_text(raw_text)

    total_debits = sum(r["debit"] or 0 for r in rows)
    total_credits = sum(r["credit"] or 0 for r in rows)

    return {
        "rows": rows,
        "bank_name": meta.get("bank_name"),
        "account_number": meta.get("account_number"),
        "period_from": meta.get("period_from"),
        "period_to": meta.get("period_to"),
        "raw_text": raw_text,
        "total_debits": round(total_debits, 2),
        "total_credits": round(total_credits, 2),
    }
