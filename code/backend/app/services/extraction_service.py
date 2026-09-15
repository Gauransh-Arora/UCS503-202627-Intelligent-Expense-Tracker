"""
Extraction Service — parses raw OCR text into structured transaction data.

Uses regex patterns to extract:
- Merchant name (first non-empty line)
- Total amount (last/largest monetary value)
- Tax amount
- Date
- Individual line items

Confidence score is based on how many fields were successfully extracted.
"""
import re
from datetime import datetime
from typing import Any

# ── Regex patterns ────────────────────────────────────────────────────────────

# Matches monetary amounts like 1,234.56 or 1234 or ₹430
_AMOUNT_PATTERN = re.compile(
    r"(?:₹|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TAX_PATTERN = re.compile(
    r"(?:tax|gst|sgst|cgst|igst|service\s+tax)[:\s]+(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TOTAL_PATTERN = re.compile(
    r"(?:total|grand\s+total|amount\s+due|amount\s+payable|net\s+amount|bill\s+amount)[:\s]+(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

# Date patterns: DD/MM/YYYY, DD-MM-YYYY, DD Mon YYYY, YYYY-MM-DD
_DATE_PATTERNS = [
    re.compile(r"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"),
    re.compile(r"\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})\b", re.IGNORECASE),
    re.compile(r"\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b"),
]

# Item line: "Pizza   300" or "Pizza x2  600"
_ITEM_PATTERN = re.compile(
    r"^(.+?)\s+(?:x\s*(\d+)\s+)?(\d+(?:\.\d{1,2})?)$",
    re.MULTILINE,
)

_SKIP_KEYWORDS = {
    "total", "subtotal", "tax", "gst", "sgst", "cgst", "discount",
    "amount", "bill", "receipt", "invoice", "cash", "card", "upi",
    "thank", "visit", "again", "date", "time", "order", "table",
    "customer", "phone", "address", "gstin", "fssai",
}


def extract_transaction_data(raw_text: str) -> dict[str, Any]:
    """
    Parse raw OCR text and return a dict with extracted fields.

    Returns:
        {
            "merchant_name": str | None,
            "amount": float | None,
            "tax_amount": float | None,
            "date": str | None,          # ISO format YYYY-MM-DD
            "items": list[dict],
            "confidence": float,         # 0.0 – 1.0
        }
    """
    lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
    result: dict[str, Any] = {
        "merchant_name": None,
        "amount": None,
        "tax_amount": None,
        "date": None,
        "items": [],
        "confidence": 0.0,
    }

    if not lines:
        return result

    # ── Merchant name ─────────────────────────────────────────────────────────
    # Usually the first 1–2 non-trivial lines
    result["merchant_name"] = _extract_merchant(lines)

    # ── Total amount ──────────────────────────────────────────────────────────
    result["amount"] = _extract_total(raw_text)

    # ── Tax amount ────────────────────────────────────────────────────────────
    tax_match = _TAX_PATTERN.search(raw_text)
    if tax_match:
        result["tax_amount"] = float(tax_match.group(1).replace(",", ""))

    # ── Date ──────────────────────────────────────────────────────────────────
    result["date"] = _extract_date(raw_text)

    # ── Line items ────────────────────────────────────────────────────────────
    result["items"] = _extract_items(lines)

    # ── Confidence ────────────────────────────────────────────────────────────
    fields_found = sum(
        1 for f in ["merchant_name", "amount", "date"]
        if result[f] is not None
    )
    result["confidence"] = round(fields_found / 3, 2)

    return result


def _extract_merchant(lines: list[str]) -> str | None:
    """Return the first non-numeric, non-trivial line as the merchant name."""
    for line in lines[:5]:  # check only first 5 lines
        clean = re.sub(r"[^a-zA-Z\s&'.]", "", line).strip()
        if len(clean) >= 3 and not any(kw in clean.lower() for kw in _SKIP_KEYWORDS):
            return line.strip()
    return lines[0] if lines else None


def _extract_total(text: str) -> float | None:
    """Find total amount — prefer explicit TOTAL label, else largest amount."""
    # Try explicit total label first
    total_match = _TOTAL_PATTERN.search(text)
    if total_match:
        return float(total_match.group(1).replace(",", ""))

    # Fall back to largest monetary value on page
    amounts = [
        float(m.group(1).replace(",", ""))
        for m in _AMOUNT_PATTERN.finditer(text)
    ]
    return max(amounts) if amounts else None


def _extract_date(text: str) -> str | None:
    """Extract and normalise the first date found to YYYY-MM-DD."""
    MONTH_MAP = {
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    }

    # DD/MM/YYYY or DD-MM-YYYY
    m = _DATE_PATTERNS[0].search(text)
    if m:
        day, month, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if year < 100:
            year += 2000
        try:
            return datetime(year, month, day).strftime("%Y-%m-%d")
        except ValueError:
            pass

    # DD Mon YYYY
    m = _DATE_PATTERNS[1].search(text)
    if m:
        day = int(m.group(1))
        month = MONTH_MAP.get(m.group(2)[:3].lower(), 0)
        year = int(m.group(3))
        if year < 100:
            year += 2000
        if month:
            try:
                return datetime(year, month, day).strftime("%Y-%m-%d")
            except ValueError:
                pass

    # YYYY-MM-DD
    m = _DATE_PATTERNS[2].search(text)
    if m:
        year, month, day = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            return datetime(year, month, day).strftime("%Y-%m-%d")
        except ValueError:
            pass

    return None


def _extract_items(lines: list[str]) -> list[dict]:
    """Extract individual item lines from receipt text."""
    items = []
    for line in lines:
        # Skip total/header lines
        lower = line.lower()
        if any(kw in lower for kw in _SKIP_KEYWORDS):
            continue

        m = _ITEM_PATTERN.match(line)
        if m:
            name = m.group(1).strip()
            qty = int(m.group(2)) if m.group(2) else 1
            price = float(m.group(3).replace(",", ""))

            # Basic sanity: item name should have letters
            if re.search(r"[a-zA-Z]", name) and price > 0:
                items.append({
                    "name": name,
                    "quantity": qty,
                    "unit_price": round(price / qty, 2),
                    "total_price": price,
                })

    return items
