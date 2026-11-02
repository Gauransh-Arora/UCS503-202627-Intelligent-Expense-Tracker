"""
Bank Statement Parser Service
==============================
Parses uploaded bank-statement PDFs and CSVs into structured row data.

Features:
  - Multimodal Vision LLM parsing via Google Gemini (zero-OCR direct tabular extraction)
  - Delimiter & encoding sniffing for CSVs
  - Flexible column header synonym matching using bank_column_synonyms.json
  - Smart merchant extraction from messy Indian/international bank narrations (UPI, NEFT, IMPS, POS, ACH)
  - Running balance mathematical reconciliation
  - In-file and cross-history duplicate transaction detection
  - Category classification with user-preference feedback
"""
from __future__ import annotations

import csv
import io
import json
import logging
import re
from datetime import datetime, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.config import settings
from app.models.category import Category
from app.models.transaction import Transaction, TransactionStatus

logger = logging.getLogger(__name__)

# Common Indian bank date formats
_DATE_FORMATS = [
    "%d/%m/%Y",
    "%d-%m-%Y",
    "%Y-%m-%d",
    "%d %b %Y",
    "%d-%b-%Y",
    "%d/%b/%Y",
    "%d %B %Y",
    "%d %b %y",
    "%d-%b-%y",
    "%d/%b/%y",
    "%d-%m-%y",
    "%d/%m/%y",
    "%Y/%m/%d",
    "%m/%d/%Y",
    "%m/%d/%y",
]

_AMT_CLEAN = re.compile(r"[₹$,\s]")

# Load column synonyms
_SYNONYMS_FILE = Path(__file__).resolve().parent.parent / "data" / "bank_column_synonyms.json"
_COLUMN_SYNONYMS: dict[str, list[str]] = {}
if _SYNONYMS_FILE.exists():
    try:
        with open(_SYNONYMS_FILE, "r", encoding="utf-8") as f:
            _COLUMN_SYNONYMS = json.load(f)
    except Exception as exc:
        logger.warning(f"Failed to load bank column synonyms: {exc}")


def _clean_merchant_from_narration(narration: str) -> str:
    """Extract clean merchant or payee name from banking narrations."""
    text = narration.strip()
    if not text:
        return "Unknown"

    # Pattern: UPI/123456/MERCHANT/BANK or UPI-123456-MERCHANT
    upi_match = re.search(r"UPI[/-](?:[^/-]+[/-])?([A-Za-z0-9\s&._]+?)(?:[/-]|$)", text, re.I)
    if upi_match and len(upi_match.group(1).strip()) > 2:
        cand = upi_match.group(1).strip()
        # Exclude numeric refs
        if not re.match(r"^\d+$", cand):
            return cand

    # Pattern: POS <REF> <MERCHANT> <CITY>
    pos_match = re.search(r"^POS(?:\s+\d+)?\s+(.+)$", text, re.I)
    if pos_match:
        cand = pos_match.group(1).strip()
        cand = re.sub(
            r"\s+(?:MUMBAI|DELHI|BENGALURU|BANGALORE|HYDERABAD|CHENNAI|KOLKATA|PUNE|AHMEDABAD|JAIPUR|CHANDIGARH|GURGAON|NOIDA|\d+)$",
            "",
            cand,
            flags=re.I,
        ).strip()
        if len(cand) > 2:
            return cand

    # Pattern: NEFT / IMPS / ACH / RTGS [CR/DR] [-/ ] [REF] - [NAME]
    transfer_match = re.search(
        r"(?:NEFT|IMPS|RTGS|ACH)(?:\s*(?:CR|DR))?[\s/-]+(?:\w*\d\w*[\s/-]+)?([A-Za-z0-9\s&._]+)",
        text,
        re.I,
    )
    if transfer_match and len(transfer_match.group(1).strip()) > 2:
        cand = transfer_match.group(1).strip()
        if not re.match(r"^\d+$", cand):
            return cand

    # Remove generic transaction noise words
    cleaned = re.sub(r"\b(BIL|INB|INF|VPS|EBA|DEP|WDL|CHQ|TRANSFER|PURCHASE|PYMT|PAYMENT)\b", "", text, flags=re.I)
    cleaned = re.sub(r"[/\\:*?\"<>|\-_]", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    tokens = [tok for tok in cleaned.split() if not re.match(r"^\d+$", tok)]
    if tokens:
        return " ".join(tokens[:4])

    return text[:40]


def _parse_amount(raw: Any) -> Optional[float]:
    """Convert an amount string or number to a rounded float."""
    if raw is None:
        return None
    raw_str = str(raw).strip()
    if not raw_str or raw_str in ("-", "—", "N/A", "null", "None"):
        return None
    negative = raw_str.startswith("(") and raw_str.endswith(")")
    cleaned = _AMT_CLEAN.sub("", raw_str).replace("(", "").replace(")", "").strip()
    # Check for trailing Dr/Cr
    if cleaned.lower().endswith("dr"):
        cleaned = cleaned[:-2].strip()
    elif cleaned.lower().endswith("cr"):
        cleaned = cleaned[:-2].strip()

    try:
        val = float(cleaned)
        return -val if negative else val
    except ValueError:
        return None


def _parse_date(raw: str) -> Optional[str]:
    """Try known date formats; return YYYY-MM-DD string or None."""
    if not raw:
        return None
    raw = raw.strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(raw, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None


def _match_column_name(header: str) -> Optional[str]:
    """Match a header column string against the synonyms dictionary."""
    clean = header.strip().lower()
    for standard_col, synonyms in _COLUMN_SYNONYMS.items():
        for syn in synonyms:
            if syn == clean:
                return standard_col
            # Substring match if clean has extra punctuation
            if len(syn) > 3 and syn in clean:
                return standard_col
    return None


def _guess_category(description: str) -> str:
    """Guess category using keywords."""
    from app.services.categorization_service import categorize_transaction
    cat, _ = categorize_transaction(description=description)
    return cat or "Others"


def _extract_text_from_pdf(file_path: str) -> str:
    """Extract raw text from PDF using pdfplumber or PyMuPDF or pypdf."""
    try:
        import pdfplumber
        text_parts: list[str] = []
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    text_parts.append(t)
        if text_parts:
            return "\n".join(text_parts)
    except Exception:
        pass

    try:
        import fitz  # PyMuPDF
        doc = fitz.open(file_path)
        return "\n".join(page.get_text() for page in doc)
    except Exception:
        pass

    return ""


def _parse_pdf_text(raw_text: str) -> tuple[list[dict], dict[str, Any]]:
    """Heuristically parse bank statement text into tabular rows."""
    lines = [ln.strip() for ln in raw_text.splitlines() if ln.strip()]
    rows: list[dict] = []
    meta: dict[str, Any] = {
        "bank_name": None,
        "account_number": None,
        "period_from": None,
        "period_to": None,
    }

    header_block = "\n".join(lines[:35])
    for line in lines[:10]:
        if len(line) >= 4 and re.search(r"[a-zA-Z]", line):
            clean = re.sub(r"[^a-zA-Z\s&.]", "", line).strip()
            if len(clean) >= 4:
                meta["bank_name"] = clean[:60]
                break

    acc_m = re.search(
        r"(?:account\s*(?:number|no\.?|#)\s*[:\-]?\s*)(\*{0,4}\d[\d\s\*]{3,})",
        header_block,
        re.I,
    )
    if acc_m:
        acc = re.sub(r"\s+", "", acc_m.group(1))
        meta["account_number"] = f"...{acc[-4:]}" if len(acc) > 4 else acc

    period_m = re.search(
        r"(?:from|period)[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})"
        r".*?(?:to)[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})",
        header_block,
        re.I | re.S,
    )
    if period_m:
        meta["period_from"] = _parse_date(period_m.group(1))
        meta["period_to"] = _parse_date(period_m.group(2))

    date_pattern = re.compile(
        r"^(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4})"
        r"\s+(.+?)"
        r"\s+([\d,]+\.\d{2}|-|—)"
        r"(?:\s+([\d,]+\.\d{2}|-|—))?"
        r"(?:\s+([\d,]+\.\d{2}|-|—))?$",
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

        debit: Optional[float] = None
        credit: Optional[float] = None
        balance: Optional[float] = None

        if amt3 is not None:
            # 3-column table: Column 1 is Debit, Column 2 is Credit, Column 3 is Balance
            balance = amt3
            debit = amt1
            credit = amt2
        elif amt2 is not None:
            debit = amt1
            credit = amt2
        else:
            desc_lower = description.lower()
            if any(k in desc_lower for k in ("cr", "credit", "salary", "refund")):
                credit = amt1
            else:
                debit = amt1

        if description:
            merchant = _clean_merchant_from_narration(description)
            rows.append(
                {
                    "date": date_str,
                    "description": description,
                    "merchant": merchant,
                    "debit": debit if debit and debit > 0 else None,
                    "credit": credit if credit and credit > 0 else None,
                    "balance": balance,
                    "category": _guess_category(description),
                    "is_duplicate": False,
                }
            )

    return rows, meta


def _parse_csv(file_path: str) -> tuple[list[dict], dict[str, Any]]:
    """Parse CSV bank statement with delimiter and header sniffing."""
    rows: list[dict] = []
    meta: dict[str, Any] = {
        "bank_name": None,
        "account_number": None,
        "period_from": None,
        "period_to": None,
        "delimiter": ",",
    }

    # Try encodings
    content = ""
    for enc in ("utf-8-sig", "utf-8", "latin-1", "cp1252"):
        try:
            with open(file_path, "r", encoding=enc) as f:
                content = f.read()
                break
        except UnicodeDecodeError:
            continue

    if not content:
        return rows, meta

    lines = [ln for ln in content.splitlines() if ln.strip()]
    if not lines:
        return rows, meta

    # Header discovery
    header_idx = 0
    delimiter = ","
    for i, line in enumerate(lines[:25]):
        lower = line.lower()
        if ("date" in lower or "txn" in lower) and any(
            k in lower for k in ("amount", "debit", "credit", "withdrawal", "narration", "particulars", "description")
        ):
            header_idx = i
            # Sniff delimiter on header line
            for cand_delim in (",", ";", "\t", "|"):
                if line.count(cand_delim) >= 2:
                    delimiter = cand_delim
                    break
            break

    meta["delimiter"] = delimiter
    csv_text = "\n".join(lines[header_idx:])
    reader = csv.DictReader(io.StringIO(csv_text), delimiter=delimiter)
    if not reader.fieldnames:
        return rows, meta

    # Map column headers
    col_mapping: dict[str, str] = {}
    for raw_col in reader.fieldnames:
        matched = _match_column_name(raw_col)
        if matched and matched not in col_mapping:
            col_mapping[matched] = raw_col

    dates: list[str] = []
    for csv_row in reader:
        date_raw = csv_row.get(col_mapping.get("date", ""), "")
        date_str = _parse_date(date_raw)
        if not date_str:
            continue

        desc_raw = csv_row.get(col_mapping.get("description", ""), "").strip()
        ref_raw = csv_row.get(col_mapping.get("reference", ""), "").strip()

        debit = _parse_amount(csv_row.get(col_mapping.get("debit", ""), None))
        credit = _parse_amount(csv_row.get(col_mapping.get("credit", ""), None))
        balance = _parse_amount(csv_row.get(col_mapping.get("balance", ""), None))

        # Check for single amount + type column
        if debit is None and credit is None:
            raw_amt = _parse_amount(csv_row.get(col_mapping.get("amount", ""), None))
            type_raw = str(csv_row.get(col_mapping.get("type", ""), "")).lower().strip()
            if raw_amt is not None:
                if "cr" in type_raw or "credit" in type_raw or "deposit" in type_raw:
                    credit = abs(raw_amt)
                elif "dr" in type_raw or "debit" in type_raw or "withdrawal" in type_raw:
                    debit = abs(raw_amt)
                else:
                    if raw_amt < 0:
                        debit = abs(raw_amt)
                    else:
                        debit = raw_amt

        dates.append(date_str)
        merchant = _clean_merchant_from_narration(desc_raw)
        rows.append(
            {
                "date": date_str,
                "description": desc_raw,
                "merchant": merchant,
                "reference": ref_raw,
                "debit": debit if debit and debit > 0 else None,
                "credit": credit if credit and credit > 0 else None,
                "balance": balance,
                "category": _guess_category(desc_raw),
                "is_duplicate": False,
            }
        )

    if dates:
        dates_sorted = sorted(dates)
        meta["period_from"] = dates_sorted[0]
        meta["period_to"] = dates_sorted[-1]

    return rows, meta


def _reconcile_balances(rows: list[dict]) -> bool:
    """Verify if row running balances match previous balance + credit - debit."""
    reconciled = True
    checked_count = 0
    for i in range(1, len(rows)):
        prev_bal = rows[i - 1].get("balance")
        curr_bal = rows[i].get("balance")
        debit = rows[i].get("debit") or 0.0
        credit = rows[i].get("credit") or 0.0
        if prev_bal is not None and curr_bal is not None:
            # Check forward or reverse ordering
            expected_fwd = round(prev_bal + credit - debit, 2)
            expected_rev = round(prev_bal - credit + debit, 2)
            if abs(expected_fwd - curr_bal) < 0.05 or abs(expected_rev - curr_bal) < 0.05:
                checked_count += 1
            else:
                reconciled = False
    return reconciled if checked_count >= 2 else True


def mark_duplicates(
    user_id: Any,
    rows: list[dict],
    db: Session,
) -> list[dict]:
    """
    Check for potential duplicates:
    1. Within the statement file itself.
    2. Against the user's confirmed transaction history in the database.
    """
    # 1. Intra-file duplicate check
    seen_in_file: set[tuple] = set()
    for row in rows:
        key = (
            row.get("date"),
            round(row.get("debit") or 0.0, 2),
            round(row.get("credit") or 0.0, 2),
            (row.get("merchant") or "").lower().strip(),
        )
        if key in seen_in_file:
            row["is_duplicate"] = True
            row["duplicate_reason"] = "Duplicate row within statement file"
        else:
            seen_in_file.add(key)

    # 2. Cross-history check
    if not rows:
        return rows

    dates = [r["date"] for r in rows if r.get("date")]
    if not dates:
        return rows

    min_date = min(dates)
    max_date = max(dates)
    try:
        start_dt = datetime.strptime(min_date, "%Y-%m-%d").date() - timedelta(days=2)
        end_dt = datetime.strptime(max_date, "%Y-%m-%d").date() + timedelta(days=2)

        existing_txns = (
            db.query(Transaction)
            .filter(
                Transaction.user_id == user_id,
                Transaction.status == TransactionStatus.CONFIRMED.value,
                Transaction.date >= start_dt,
                Transaction.date <= end_dt,
            )
            .all()
        )

        for row in rows:
            if row.get("is_duplicate"):
                continue
            debit = row.get("debit")
            if debit is None or debit <= 0:
                continue

            row_date = datetime.strptime(row["date"], "%Y-%m-%d").date()
            row_amt = Decimal(str(round(debit, 2)))
            row_merchant = (row.get("merchant") or "").lower().strip()

            for txn in existing_txns:
                # Match if within 1 day, identical amount, and matching merchant
                date_diff = abs((txn.date - row_date).days)
                amt_diff = abs(Decimal(str(txn.amount)) - row_amt)
                if date_diff <= 1 and amt_diff < Decimal("0.01"):
                    txn_merchant = (txn.merchant or "").lower().strip()
                    if row_merchant in txn_merchant or txn_merchant in row_merchant or not row_merchant:
                        row["is_duplicate"] = True
                        row["duplicate_reason"] = f"Matches existing transaction from {txn.date} ({txn.merchant})"
                        break
    except Exception as exc:
        logger.warning(f"Error checking duplicates: {exc}")

    return rows


def parse_bank_statement(file_path: str, user_id: Optional[Any] = None, db: Optional[Session] = None) -> dict[str, Any]:
    """Parse a bank statement file (PDF or CSV) using high-speed local parser with Vision LLM fallback."""
    path = Path(file_path)
    ext = path.suffix.lower()

    # 1. Local parser for CSV
    if ext == ".csv":
        rows, meta = _parse_csv(file_path)
        is_reconciled = _reconcile_balances(rows)
        meta["balance_reconciled"] = is_reconciled
        if user_id and db:
            rows = mark_duplicates(user_id, rows, db)
        total_debits = sum(r["debit"] or 0 for r in rows)
        total_credits = sum(r["credit"] or 0 for r in rows)
        return {
            "rows": rows,
            "bank_name": meta.get("bank_name"),
            "account_number": meta.get("account_number"),
            "period_from": meta.get("period_from"),
            "period_to": meta.get("period_to"),
            "raw_text": "",
            "total_debits": round(total_debits, 2),
            "total_credits": round(total_credits, 2),
            "balance_reconciled": is_reconciled,
        }

    # 2. For PDF: Try fast local extraction first (takes 1-2s and avoids LLM timeouts on large files)
    raw_text = ""
    try:
        raw_text = _extract_text_from_pdf(file_path)
        if raw_text and len(raw_text.strip()) > 50:
            rows, meta = _parse_pdf_text(raw_text)
            if rows and len(rows) > 0:
                is_reconciled = _reconcile_balances(rows)
                meta["balance_reconciled"] = is_reconciled
                if user_id and db:
                    rows = mark_duplicates(user_id, rows, db)
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
                    "balance_reconciled": is_reconciled,
                }
    except Exception as exc:
        logger.warning(f"Local PDF text parsing skipped or failed: {exc}")

    # 3. Vision LLM fallback (for scanned PDFs, image-only statements, or unstructured layouts)
    if ext == ".pdf" and getattr(settings, "EXTRACTION_PROVIDER", "gemini") == "gemini":
        try:
            from app.services.vision_service import is_vision_available, parse_bank_statement_with_vision
            if is_vision_available():
                vision_res = parse_bank_statement_with_vision(file_path)
                if vision_res and vision_res.get("rows"):
                    if user_id and db:
                        vision_res["rows"] = mark_duplicates(user_id, vision_res["rows"], db)
                    return vision_res
        except Exception as exc:
            logger.warning(f"Vision bank statement parsing fell back: {exc}")

    # 4. Final fallback
    rows, meta = _parse_pdf_text(raw_text)
    is_reconciled = _reconcile_balances(rows)
    meta["balance_reconciled"] = is_reconciled

    if user_id and db:
        rows = mark_duplicates(user_id, rows, db)

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
        "balance_reconciled": is_reconciled,
    }
