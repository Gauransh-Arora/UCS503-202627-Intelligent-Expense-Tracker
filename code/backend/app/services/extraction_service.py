"""
Extraction Service — parses raw OCR text into structured transaction data.
Handles diverse document layouts:
- Bills / Receipts (supermarket itemized, restaurant with taxes/tips, fuel, pharmacy)
- UPI Payment Screenshots (Google Pay, PhonePe, Paytm, BHIM, Bank UPI)

Includes per-field confidence scoring, currency normalization, date normalization,
UPI status/direction detection, and line-item total cross-checking.
"""
from datetime import datetime
from decimal import Decimal, InvalidOperation
import re
from typing import Any

# ── Amount Normalization ───────────────────────────────────────────────────────

def normalize_amount_str(val_str: str) -> Decimal | None:
    """
    Parse varied currency strings into a Decimal:
    e.g. '1,234.50', '1,23,456.00', '1.234,50' (European), '1234', 'Rs. 500'
    """
    if not val_str:
        return None

    cleaned = val_str.strip()
    # Remove currency prefixes like Rs., INR, ₹, $
    cleaned = re.sub(r"^(?:₹|Rs\.?|INR|\$)\s*", "", cleaned, flags=re.IGNORECASE).strip()
    cleaned = re.sub(r"[₹$\s]", "", cleaned).strip()
    cleaned = re.sub(r"^[^\d]+", "", cleaned).strip()
    if not cleaned:
        return None

    # Handle European format: 1.234,50 -> 1234.50
    if re.search(r"^\d{1,3}(?:\.\d{3})+,\d{2}$", cleaned):
        cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "," in cleaned and "." in cleaned:
        # Standard: 1,234.56 or Indian 1,23,456.78
        cleaned = cleaned.replace(",", "")
    elif "," in cleaned and "." not in cleaned:
        # Either 1,234 (thousands) or 12,50 (decimal)
        parts = cleaned.split(",")
        if len(parts[-1]) == 2:
            cleaned = cleaned.replace(",", ".")
        else:
            cleaned = cleaned.replace(",", "")

    # Remove trailing dots or dashes
    cleaned = re.sub(r"[-–—]$", "", cleaned).strip()

    try:
        dec = Decimal(cleaned)
        return dec if dec >= 0 else None
    except (InvalidOperation, ValueError):
        return None


# ── Regex Patterns ─────────────────────────────────────────────────────────────

# Currency-prefixed amount: ₹ 1,234.50, Rs. 500, INR 1200
_CURRENCY_AMOUNT_PATTERN = re.compile(
    r"(?:₹|Rs\.?|INR|(?:\b|^)R)\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TOTAL_PATTERN = re.compile(
    r"\b(?:grand\s+total|total\s+amount|paid\s+amount|final\s+amount|amount\s+due|amount\s+payable|net\s+amount|bill\s+amount|total)(?!\s+tax)[:\s]+(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_TAX_PATTERN = re.compile(
    r"\b(?:total\s+tax|gst|sgst|cgst|igst|vat|service\s+tax)(?:\s*\([^)]*\))?[:\s]+(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_DISCOUNT_PATTERN = re.compile(
    r"(?:discount|saving|offer|cashback)[:\s]+(?:₹|Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)",
    re.IGNORECASE,
)

_UTR_PATTERN = re.compile(
    r"(?:upi\s+ref\s*(?:no|id)?|utr(?:\s*no)?|txn\s*(?:id|ref)?|transaction\s*id)[:\s]*([0-9a-zA-Z]{6,30})",
    re.IGNORECASE,
)

# Date regexes
_DATE_PATTERNS = [
    # YYYY-MM-DD
    re.compile(r"\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b"),
    # DD Mon YYYY, 15th Sep 2026, 15-Sep-26, 14Oct2026
    re.compile(
        r"\b(\d{1,2})(?:st|nd|rd|th)?[\s\/\-]*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\/\-]*(\d{2,4})\b",
        re.IGNORECASE,
    ),
    # DD/MM/YYYY or DD-MM-YYYY
    re.compile(r"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"),
]

# Line items pattern: "Margherita Pizza x 2 400.00" or "Coke 60.00"
_ITEM_PATTERN = re.compile(
    r"^(.+?)\s+(?:x\s*(\d+)\s+)?([\d,]+(?:\.\d{1,2})?)$",
    re.MULTILINE,
)

_SKIP_KEYWORDS = {
    "total", "subtotal", "sub-total", "tax", "gst", "sgst", "cgst", "igst", "vat",
    "discount", "amount", "bill", "receipt", "invoice", "cash", "card", "upi",
    "thank", "visit", "again", "date", "time", "order", "table", "cashier",
    "customer", "phone", "address", "gstin", "fssai", "pos", "terminal",
}

_UPI_KEYWORDS = {
    "transaction id", "banking name", "upi id", "upi screenshot",
    "bhim", "gpay", "google pay", "phonepe", "paytm", "payment initiated",
    "debited account", "debited from", "to upi", "split this expense",
    "paid to", "payment to", "completed", "successful",
}

MONTH_MAP = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}


def normalize_date(text: str) -> str | None:
    """Extract and normalise the first date found to ISO YYYY-MM-DD."""
    if not text:
        return None

    # 1. YYYY-MM-DD
    m = _DATE_PATTERNS[0].search(text)
    if m:
        try:
            year, month, day = int(m.group(1)), int(m.group(2)), int(m.group(3))
            return datetime(year, month, day).strftime("%Y-%m-%d")
        except ValueError:
            pass

    # 2. DD Mon YYYY / 15th Sep 2026 / 15-Sep-26
    m = _DATE_PATTERNS[1].search(text)
    if m:
        try:
            day = int(m.group(1))
            month = MONTH_MAP.get(m.group(2)[:3].lower(), 0)
            year = int(m.group(3))
            if year < 100:
                year += 2000
            if month:
                return datetime(year, month, day).strftime("%Y-%m-%d")
        except ValueError:
            pass

    # 3. DD/MM/YYYY or MM/DD/YYYY
    m = _DATE_PATTERNS[2].search(text)
    if m:
        try:
            val1, val2, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
            if year < 100:
                year += 2000

            # Disambiguate day-first vs month-first: in India/standard bills day comes first
            if val1 > 12:  # Must be Day/Month
                day, month = val1, val2
            elif val2 > 12:  # Must be Month/Day
                day, month = val2, val1
            else:
                # Default day-first
                day, month = val1, val2

            return datetime(year, month, day).strftime("%Y-%m-%d")
        except ValueError:
            pass

    return None


def extract_transaction_data(raw_text: str, doc_type: str | None = None) -> dict[str, Any]:
    """
    Parse raw OCR text and return a structured dictionary with field confidences.

    Returns:
        {
            "merchant_name": str | None,
            "amount": float | None,
            "tax_amount": float | None,
            "date": str | None,          # YYYY-MM-DD
            "items": list[dict],
            "reference_number": str | None,
            "payment_status": str,       # 'success' | 'failed' | 'pending'
            "payment_direction": str,    # 'debit' | 'credit'
            "confidence": float,         # 0.0 – 1.0 overall
            "confidence_score": float,   # synonym
            "merchant": str | None,      # synonym
            "field_confidences": dict[str, float],
            "validation_flags": list[str],
        }
    """
    lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
    result: dict[str, Any] = {
        "merchant_name": None,
        "amount": None,
        "tax_amount": None,
        "date": None,
        "items": [],
        "reference_number": None,
        "payment_status": "success",
        "payment_direction": "debit",
        "confidence": 0.0,
        "confidence_score": 0.0,
        "merchant": None,
        "field_confidences": {
            "merchant_name": 0.0,
            "amount": 0.0,
            "date": 0.0,
            "items": 0.0,
            "taxes": 0.0,
        },
        "validation_flags": [],
    }

    if not lines:
        return result

    text_lower = raw_text.lower()
    if doc_type:
        is_upi = doc_type in ("upi_screenshot", "upi")
    else:
        is_upi = any(kw in text_lower for kw in _UPI_KEYWORDS)

    # 1. UPI payment status detection
    if "payment failed" in text_lower or "failed" in text_lower and "success" not in text_lower:
        result["payment_status"] = "failed"
        result["validation_flags"].append("Payment marked as failed in screenshot")
    elif "payment pending" in text_lower or "processing" in text_lower:
        result["payment_status"] = "pending"
        result["validation_flags"].append("Payment is still pending")

    # Direction detection (debit vs credit)
    if any(k in text_lower for k in ("received from", "credited to", "money received", "refund received")):
        result["payment_direction"] = "credit"
        result["validation_flags"].append("Incoming transfer / credit detected")

    # Reference / UTR
    utr_m = _UTR_PATTERN.search(raw_text)
    if utr_m:
        result["reference_number"] = utr_m.group(1).strip()

    if is_upi:
        _extract_upi(raw_text, lines, result)
    else:
        _extract_receipt(raw_text, lines, result)

    # Cross-check line items vs grand total
    if result["items"] and result["amount"]:
        items_sum = sum(i["total_price"] for i in result["items"])
        tax = result["tax_amount"] or 0.0
        expected_total = items_sum + tax
        actual_total = result["amount"]

        diff = abs(expected_total - actual_total)
        if diff > 2.0:
            result["validation_flags"].append(
                f"Items total (₹{items_sum:.2f}) + Tax (₹{tax:.2f}) differs from Grand Total (₹{actual_total:.2f})"
            )
            # Penalize confidence
            result["field_confidences"]["items"] = max(0.2, result["field_confidences"]["items"] - 0.3)
            result["field_confidences"]["amount"] = max(0.4, result["field_confidences"]["amount"] - 0.2)

    # Calculate composite overall confidence score
    if (
        result["merchant_name"]
        and result["amount"]
        and result["date"]
        and not result["validation_flags"]
        and result["payment_status"] == "success"
    ):
        result["confidence"] = 1.0
    else:
        weights = {"merchant_name": 0.35, "amount": 0.45, "date": 0.20}
        composite = sum(
            result["field_confidences"].get(k, 0.0) * w
            for k, w in weights.items()
        )
        if result["payment_status"] != "success":
            composite *= 0.5

        result["confidence"] = round(min(1.0, max(0.0, composite)), 2)

    result["confidence_score"] = result["confidence"]
    result["merchant"] = result["merchant_name"]
    return result


def _extract_upi(raw_text: str, lines: list[str], result: dict) -> None:
    """Extract fields from UPI payment screenshots."""
    # ── Amount ──────────────────────────────────────────────────────────────
    currency_matches = list(_CURRENCY_AMOUNT_PATTERN.finditer(raw_text))
    amounts = []
    for m in currency_matches:
        parsed = normalize_amount_str(m.group(1))
        if parsed and 0 < parsed < 1_000_000:
            amounts.append(float(parsed))

    if amounts:
        # The paid amount in UPI is typically the primary transfer value
        result["amount"] = min(amounts)
        result["field_confidences"]["amount"] = 0.95
    else:
        # Standalone large display number fallback
        _STANDALONE_NUM = re.compile(r"^\s*([\d,]+(?:\.\d{1,2})?)\s*$")
        for line in lines:
            m = _STANDALONE_NUM.match(line)
            if m:
                val = normalize_amount_str(m.group(1))
                if val and 0 < val < 1_000_000 and len(str(int(val))) <= 7:
                    result["amount"] = float(val)
                    result["field_confidences"]["amount"] = 0.80
                    break

        if result["amount"] is None:
            # Fallback near 'paid'
            paid_m = re.search(r"(?:paid|₹)\s*([\d,]+(?:\.\d{1,2})?)", raw_text, re.IGNORECASE)
            if paid_m:
                val = normalize_amount_str(paid_m.group(1))
                if val and 0 < val < 1_000_000:
                    result["amount"] = float(val)
                    result["field_confidences"]["amount"] = 0.70

    # ── Merchant ─────────────────────────────────────────────────────────────
    # Banking Name or Paid to
    banking_match = re.search(r"banking\s+name[:\s]*\n?([^\n\r]+)", raw_text, re.IGNORECASE)
    if banking_match:
        name = banking_match.group(1).strip()
        result["merchant_name"] = re.sub(r"[^\w\s&'.]", "", name).strip()
        result["field_confidences"]["merchant_name"] = 0.95
    else:
        to_match = re.search(
            r"(?:to\s+upi\s*id|paid\s+to|\bto\b)[:\s]*\n?([a-zA-Z0-9\s&'.-]+)",
            raw_text,
            re.IGNORECASE,
        )
        if to_match:
            candidate = to_match.group(1).strip().splitlines()[0]
            candidate = re.sub(r"\.+$", "", candidate).strip()
            if len(candidate) >= 3 and candidate.lower() not in ("upi", "gpay", "phonepe", "paytm"):
                result["merchant_name"] = candidate
                result["field_confidences"]["merchant_name"] = 0.85

    if not result["merchant_name"] and lines:
        for line in lines[:4]:
            clean = re.sub(r"[^a-zA-Z\s&'.]", "", line).strip()
            if len(clean) >= 4 and not any(kw in clean.lower() for kw in _SKIP_KEYWORDS):
                result["merchant_name"] = clean
                result["field_confidences"]["merchant_name"] = 0.60
                break

    # ── Date ─────────────────────────────────────────────────────────────────
    extracted_date = normalize_date(raw_text)
    if extracted_date:
        result["date"] = extracted_date
        result["field_confidences"]["date"] = 0.90

    result["items"] = []


def _extract_receipt(raw_text: str, lines: list[str], result: dict) -> None:
    """Extract fields from itemized receipt/bill text."""
    # ── Merchant ─────────────────────────────────────────────────────────────
    for line in lines[:6]:
        clean = re.sub(r"[^a-zA-Z\s&'.]", "", line).strip()
        if len(clean) >= 3 and not any(kw in clean.lower() for kw in _SKIP_KEYWORDS):
            result["merchant_name"] = line.strip()
            result["field_confidences"]["merchant_name"] = 0.85
            break
    if not result["merchant_name"] and lines:
        result["merchant_name"] = lines[0].strip()
        result["field_confidences"]["merchant_name"] = 0.50

    # ── Total Amount ─────────────────────────────────────────────────────────
    total_m = _TOTAL_PATTERN.search(raw_text)
    if total_m:
        parsed = normalize_amount_str(total_m.group(1))
        if parsed:
            result["amount"] = float(parsed)
            result["field_confidences"]["amount"] = 0.95
    else:
        currency_amounts = []
        for m in _CURRENCY_AMOUNT_PATTERN.finditer(raw_text):
            p = normalize_amount_str(m.group(1))
            if p:
                currency_amounts.append(float(p))
        if currency_amounts:
            result["amount"] = max(currency_amounts)
            result["field_confidences"]["amount"] = 0.75

    # ── Tax Amount ───────────────────────────────────────────────────────────
    tax_m = _TAX_PATTERN.search(raw_text)
    if tax_m:
        tax_val = normalize_amount_str(tax_m.group(1))
        if tax_val:
            result["tax_amount"] = float(tax_val)
            result["field_confidences"]["taxes"] = 0.85

    # ── Date ─────────────────────────────────────────────────────────────────
    extracted_date = normalize_date(raw_text)
    if extracted_date:
        result["date"] = extracted_date
        result["field_confidences"]["date"] = 0.90

    # ── Items ────────────────────────────────────────────────────────────────
    items = []
    for line in lines:
        lower = line.lower()
        if any(kw in lower for kw in _SKIP_KEYWORDS):
            continue

        m = _ITEM_PATTERN.match(line)
        if m:
            name = m.group(1).strip()
            qty = int(m.group(2)) if m.group(2) else 1
            price_dec = normalize_amount_str(m.group(3))
            if price_dec and price_dec > 0 and re.search(r"[a-zA-Z]", name):
                price_f = float(price_dec)
                items.append({
                    "name": name,
                    "quantity": qty,
                    "unit_price": round(price_f / max(1, qty), 2),
                    "total_price": round(price_f, 2),
                })

    result["items"] = items
    if items:
        result["field_confidences"]["items"] = 0.85
