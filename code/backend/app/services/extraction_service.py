"""
Extraction Service — parses raw OCR text into structured transaction data.

Handles two major formats:
- RECEIPT/BILL: merchant header, line items, TOTAL label, GST, etc.
- UPI SCREENSHOT: Banking Name, Transaction ID, ₹amount in header, Date & Time

Confidence score is based on how many key fields were successfully extracted.
"""
import re
from datetime import datetime
from typing import Any

# ── Currency-prefixed amount (only these are real amounts, not IDs) ───────────
# Must have ₹ / Rs. / INR prefix to be considered an amount
_CURRENCY_AMOUNT_PATTERN = re.compile(
    r"(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TAX_PATTERN = re.compile(
    r"(?:tax|gst|sgst|cgst|igst|service\s+tax)[:\s]+(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TOTAL_PATTERN = re.compile(
    r"(?:total|grand\s+total|amount\s+due|amount\s+payable|net\s+amount|bill\s+amount)[:\s]+(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

# Date patterns: DD/MM/YYYY, DD-MM-YYYY, DD Mon YYYY, YYYY-MM-DD
# Also handles ordinal: 15th Sep 26 or 15 Sep 2026
_DATE_PATTERNS = [
    re.compile(r"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"),
    re.compile(r"\b(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})\b", re.IGNORECASE),
    re.compile(r"\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b"),
]

# Item line: "Pizza   300" or "Pizza x2  600"
_ITEM_PATTERN = re.compile(
    r"^(.+?)\s+(?:x\s*(\d+)\s+)?([\d,]+(?:\.\d{1,2})?)$",
    re.MULTILINE,
)

_SKIP_KEYWORDS = {
    "total", "subtotal", "tax", "gst", "sgst", "cgst", "discount",
    "amount", "bill", "receipt", "invoice", "cash", "card", "upi",
    "thank", "visit", "again", "date", "time", "order", "table",
    "customer", "phone", "address", "gstin", "fssai",
}

# UPI screenshot detection keywords
_UPI_KEYWORDS = {
    "transaction id", "banking name", "upi id", "upi screenshot",
    "bhim", "gpay", "phonepe", "paytm", "payment initiated",
    "debited account", "to upi", "split this expense",
}

MONTH_MAP = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
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

    text_lower = raw_text.lower()
    is_upi = any(kw in text_lower for kw in _UPI_KEYWORDS)

    if is_upi:
        _extract_upi(raw_text, lines, result)
    else:
        _extract_receipt(raw_text, lines, result)

    # ── Confidence ────────────────────────────────────────────────────────────
    fields_found = sum(
        1 for f in ["merchant_name", "amount", "date"]
        if result[f] is not None
    )
    result["confidence"] = round(fields_found / 3, 2)

    return result


def _extract_upi(raw_text: str, lines: list[str], result: dict) -> None:
    """Extract fields from UPI payment screenshots."""

    # ── Amount: try ₹-prefixed first, then smart fallbacks ───────────────────
    currency_amounts = [
        float(m.group(1).replace(",", ""))
        for m in _CURRENCY_AMOUNT_PATTERN.finditer(raw_text)
    ]
    if currency_amounts:
        # The actual paid amount is the smallest ₹ value
        # (avoids picking up large account numbers accidentally prefixed with ₹)
        result["amount"] = min(currency_amounts)
    else:
        # Fallback: Tesseract may miss the ₹ glyph from colored backgrounds.
        # Look for a standalone number on a line by itself (the big amount display)
        # near "Paid", "paid", or at the top of text. Filter out long IDs (>8 digits).
        _STANDALONE_NUM = re.compile(r"^\s*([\d,]+(?:\.\d{1,2})?)\s*$")
        text_lower = raw_text.lower()
        paid_pos = text_lower.find("paid")

        for line in lines:
            m = _STANDALONE_NUM.match(line)
            if m:
                raw_num = m.group(1).replace(",", "")
                # Reject numbers that look like transaction IDs (>8 digits)
                if len(raw_num.replace(".", "")) <= 8:
                    val = float(raw_num)
                    if val > 0:
                        result["amount"] = val
                        break

        # Also try: number immediately after "Paid" in same/next line
        if result["amount"] is None and paid_pos != -1:
            after_paid = raw_text[paid_pos:]
            m = re.search(r"(?:paid|₹)\s*([\d,]+(?:\.\d{1,2})?)", after_paid, re.IGNORECASE)
            if m:
                val = float(m.group(1).replace(",", ""))
                if 0 < val < 1_000_000:
                    result["amount"] = val

    # ── Merchant: from "Banking Name" section ─────────────────────────────────
    banking_match = re.search(
        r"banking\s+name[:\s]*\n?(.+)", raw_text, re.IGNORECASE
    )
    if banking_match:
        result["merchant_name"] = banking_match.group(1).strip()
    else:
        # Fallback: "To UPI ID" recipient line
        to_match = re.search(
            r"to\s+upi\s*id[:\s]*\n?([^\n]+)", raw_text, re.IGNORECASE
        )
        if to_match:
            result["merchant_name"] = to_match.group(1).strip()

    # ── Date: handle ordinal formats like "15th Sep 26" ──────────────────────
    result["date"] = _extract_date(raw_text)

    # ── UPI screenshots rarely have line items ────────────────────────────────
    result["items"] = []


def _extract_receipt(raw_text: str, lines: list[str], result: dict) -> None:
    """Extract fields from receipt/bill format text."""

    # ── Merchant name ─────────────────────────────────────────────────────────
    result["merchant_name"] = _extract_merchant(lines)

    # ── Total amount: prefer explicit TOTAL label, then ₹-prefixed values ─────
    total_match = _TOTAL_PATTERN.search(raw_text)
    if total_match:
        result["amount"] = float(total_match.group(1).replace(",", ""))
    else:
        # Fall back only to currency-prefixed amounts (not bare numbers)
        currency_amounts = [
            float(m.group(1).replace(",", ""))
            for m in _CURRENCY_AMOUNT_PATTERN.finditer(raw_text)
        ]
        if currency_amounts:
            result["amount"] = max(currency_amounts)

    # ── Tax ───────────────────────────────────────────────────────────────────
    tax_match = _TAX_PATTERN.search(raw_text)
    if tax_match:
        result["tax_amount"] = float(tax_match.group(1).replace(",", ""))

    # ── Date ──────────────────────────────────────────────────────────────────
    result["date"] = _extract_date(raw_text)

    # ── Line items ────────────────────────────────────────────────────────────
    result["items"] = _extract_items(lines)


def _extract_merchant(lines: list[str]) -> str | None:
    """Return the first non-numeric, non-trivial line as the merchant name."""
    for line in lines[:5]:  # check only first 5 lines
        clean = re.sub(r"[^a-zA-Z\s&'.]", "", line).strip()
        if len(clean) >= 3 and not any(kw in clean.lower() for kw in _SKIP_KEYWORDS):
            return line.strip()
    return lines[0] if lines else None


def _extract_date(text: str) -> str | None:
    """Extract and normalise the first date found to YYYY-MM-DD."""

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

    # DD Mon YYYY or "15th Sep 26"
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
        lower = line.lower()
        if any(kw in lower for kw in _SKIP_KEYWORDS):
            continue

        m = _ITEM_PATTERN.match(line)
        if m:
            name = m.group(1).strip()
            qty = int(m.group(2)) if m.group(2) else 1
            price = float(m.group(3).replace(",", ""))

            if re.search(r"[a-zA-Z]", name) and price > 0:
                items.append({
                    "name": name,
                    "quantity": qty,
                    "unit_price": round(price / qty, 2),
                    "total_price": price,
                })

    return items
