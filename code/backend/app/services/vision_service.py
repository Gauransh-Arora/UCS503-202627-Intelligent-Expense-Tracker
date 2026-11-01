"""
Vision LLM Service
===================
Uses Google Gemini (Multimodal Vision) to parse:
1. Receipts / Bills / Invoices
2. UPI Payment Screenshots (Google Pay, PhonePe, Paytm, BHIM)
3. Multi-page Bank Statement PDFs

Bypasses brittle OCR engines and manual regex pipelines by leveraging
multimodal reasoning directly on document images and PDFs.
"""
from __future__ import annotations

import json
import logging
import mimetypes
import os
from pathlib import Path
from typing import Any, Optional

from app.config import settings

logger = logging.getLogger(__name__)

# Lazy singleton client
_GEMINI_CLIENT = None
_INIT_ATTEMPTED = False


def get_gemini_client():
    """Lazily initialize Google GenAI client if API key is configured."""
    global _GEMINI_CLIENT, _INIT_ATTEMPTED
    if not _INIT_ATTEMPTED:
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY")
        if api_key and api_key.strip():
            try:
                from google import genai
                _GEMINI_CLIENT = genai.Client(api_key=api_key.strip())
                logger.info("Google GenAI (Gemini) client initialized successfully.")
            except Exception as e:
                logger.warning(f"Failed to initialize Google GenAI client: {e}")
                _GEMINI_CLIENT = None
        else:
            logger.info("GEMINI_API_KEY is not set. Vision LLM will be disabled until key is provided.")
        _INIT_ATTEMPTED = True
    return _GEMINI_CLIENT


def is_vision_available() -> bool:
    """Return True if Gemini API key is configured and client is ready."""
    return get_gemini_client() is not None


def _get_mime_type(path: Path) -> str:
    ext = path.suffix.lower()
    mapping = {
        ".pdf": "application/pdf",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".heic": "image/heic",
    }
    return mapping.get(ext, mimetypes.guess_type(str(path))[0] or "application/octet-stream")


def parse_receipt_with_vision(file_path: str) -> Optional[dict[str, Any]]:
    """
    Extract structured receipt / bill / UPI screenshot data using Gemini Vision.
    Returns None if vision client is unavailable or if parsing fails.
    """
    client = get_gemini_client()
    if not client:
        return None

    path = Path(file_path).resolve()
    if not path.exists():
        alt = Path.cwd() / file_path
        if alt.exists():
            path = alt
        else:
            logger.warning(f"File not found for vision parsing: {file_path}")
            return None

    mime_type = _get_mime_type(path)
    with open(path, "rb") as f:
        file_bytes = f.read()

    from google.genai import types

    part = types.Part.from_bytes(data=file_bytes, mime_type=mime_type)

    prompt = """Analyze this receipt, bill, or UPI payment screenshot. Extract all transaction details accurately into JSON.

Respond ONLY with valid JSON conforming to this exact structure:
{
  "merchant_name": "clean brand/store or payee name (e.g., Starbucks, Fresh Choice Mart, Reena Garg)",
  "amount": 123.45,
  "date": "YYYY-MM-DD",
  "time": "HH:MM (24-hour format if visible, else null)",
  "category": "one of: Food & Dining, Groceries, Shopping, Utilities, Transportation, Entertainment, Health & Fitness, Personal Care, Travel, Education, Investments, Others",
  "tax_amount": 0.0,
  "payment_method": "one of: UPI, Cash, Card, Net Banking, or null",
  "reference": "UPI reference, UTR, invoice number, or bill number if available, else null",
  "confidence": 0.95,
  "raw_text": "verbatim text extracted from the document",
  "items": [
    {
      "name": "item name",
      "quantity": 1,
      "unit_price": 0.0,
      "total_price": 0.0
    }
  ]
}

Guidelines:
- Amount must be a positive number (grand total).
- For UPI screenshots, the merchant/payee is the recipient, and status must be confirmed.
- Items should list all purchased products or services if itemized on the bill. If not itemized, leave items as an empty array [].
- Never hallucinate details.
"""

    model_name = settings.GEMINI_MODEL or "gemini-1.5-flash"
    try:
        response = client.models.generate_content(
            model=model_name,
            contents=[part, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )

        if not response or not response.text:
            return None

        data = json.loads(response.text)
        # Ensure confidence is float between 0.0 and 1.0
        data["confidence"] = float(data.get("confidence") or 0.95)
        if "raw_text" not in data:
            data["raw_text"] = f"{data.get('merchant_name', '')} {data.get('amount', '')} {data.get('date', '')}"
        return data
    except Exception as exc:
        logger.warning(f"Gemini receipt parsing failed: {exc}")
        return None


def parse_bank_statement_with_vision(file_path: str) -> Optional[dict[str, Any]]:
    """
    Extract structured transactions from a multi-page PDF bank statement using Gemini Vision.
    Returns None if vision client is unavailable or if parsing fails.
    """
    client = get_gemini_client()
    if not client:
        return None

    path = Path(file_path).resolve()
    if not path.exists():
        alt = Path.cwd() / file_path
        if alt.exists():
            path = alt
        else:
            logger.warning(f"File not found for bank statement vision parsing: {file_path}")
            return None

    mime_type = _get_mime_type(path)
    with open(path, "rb") as f:
        file_bytes = f.read()

    from google.genai import types

    part = types.Part.from_bytes(data=file_bytes, mime_type=mime_type)

    prompt = """Analyze this bank statement document. Extract metadata and every single transaction row into structured JSON.

Respond ONLY with valid JSON conforming to this exact structure:
{
  "bank_name": "Name of the bank (e.g. HDFC Bank, Axis Bank, State Bank of India)",
  "account_number": "Masked account number (e.g. ...0422) if visible",
  "period_from": "YYYY-MM-DD (start of statement period, or null)",
  "period_to": "YYYY-MM-DD (end of statement period, or null)",
  "total_debits": 0.0,
  "total_credits": 0.0,
  "balance_reconciled": true,
  "rows": [
    {
      "date": "YYYY-MM-DD",
      "description": "Full narration or particulars from the statement",
      "merchant": "Clean payee or merchant name (e.g., Paytm, Amazon, Le Travenues Technology)",
      "reference": "Reference/Cheque/UTR number if available, else null",
      "debit": 1500.0,
      "credit": null,
      "balance": 112953.65,
      "category": "Estimated category (Food & Dining, Shopping, Utilities, Salary, Investments, Others)",
      "is_duplicate": false
    }
  ]
}

Guidelines:
- If a row is a debit (withdrawal/outgoing payment), set debit to the amount and credit to null.
- If a row is a credit (deposit/incoming payment/interest/salary/refund), set credit to the amount and debit to null.
- Do NOT include initial opening balances ('BALANCE FORWARD', 'BROUGHT FORWARD') as debits or credits; only include actual transactions.
- Format all dates in YYYY-MM-DD.
"""

    model_name = settings.GEMINI_MODEL or "gemini-1.5-flash"
    try:
        response = client.models.generate_content(
            model=model_name,
            contents=[part, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )

        if not response or not response.text:
            return None

        data = json.loads(response.text)

        # Validate rows and calculate totals if not provided
        rows = data.get("rows", [])
        total_debits = sum(float(r.get("debit") or 0.0) for r in rows)
        total_credits = sum(float(r.get("credit") or 0.0) for r in rows)

        data["total_debits"] = round(total_debits, 2)
        data["total_credits"] = round(total_credits, 2)
        if "balance_reconciled" not in data:
            data["balance_reconciled"] = True
        if "raw_text" not in data:
            data["raw_text"] = f"Bank statement parsed by Gemini: {data.get('bank_name', 'Bank Statement')}"

        return data
    except Exception as exc:
        logger.warning(f"Gemini bank statement parsing failed: {exc}")
        return None
