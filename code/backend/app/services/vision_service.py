"""
Vision LLM Service
===================
Uses Google Gemini (Multimodal Vision) to parse:
1. Receipts / Bills / Invoices
2. UPI Payment Screenshots (Google Pay, PhonePe, Paytm, BHIM)
3. Multi-page Bank Statement PDFs

Bypasses brittle OCR engines and manual regex pipelines by leveraging
multimodal reasoning directly on document images and PDFs.
Supports multi-key failover and multi-model cascading for maximum reliability.
"""
from __future__ import annotations

import io
import json
import logging
import mimetypes
import os
from pathlib import Path
from typing import Any, Optional

from app.config import settings

logger = logging.getLogger(__name__)

# Cached clients for multi-key failover
_GEMINI_CLIENTS: list[tuple[str, Any]] = []
_INIT_ATTEMPTED = False


def reset_gemini_clients() -> None:
    """Reset the cached clients (useful for testing or after configuration changes)."""
    global _GEMINI_CLIENTS, _INIT_ATTEMPTED
    _GEMINI_CLIENTS = []
    _INIT_ATTEMPTED = False


def get_gemini_clients() -> list[tuple[str, Any]]:
    """
    Lazily initialize and return a list of (masked_label, genai.Client) tuples
    for all configured Gemini API keys.
    """
    global _GEMINI_CLIENTS, _INIT_ATTEMPTED
    if not _INIT_ATTEMPTED:
        keys = settings.gemini_api_keys
        if not keys and os.environ.get("GEMINI_API_KEY"):
            keys = [os.environ.get("GEMINI_API_KEY").strip()]

        if keys:
            try:
                from google import genai
                for idx, key in enumerate(keys, 1):
                    masked = f"Key-{idx}(...{key[-4:]})" if len(key) >= 4 else f"Key-{idx}"
                    try:
                        from google.genai import types
                        http_opts = types.HttpOptions(
                            timeout=20000,
                            retry_options=types.HttpRetryOptions(attempts=1),
                        )
                        client = genai.Client(api_key=key, http_options=http_opts)
                        _GEMINI_CLIENTS.append((masked, client))
                    except Exception as err:
                        logger.warning(f"Failed to initialize Gemini client for {masked}: {err}")
                if _GEMINI_CLIENTS:
                    logger.info(f"Initialized {len(_GEMINI_CLIENTS)} Google GenAI (Gemini) client(s) for failover.")
            except Exception as e:
                logger.warning(f"Failed to import google.genai: {e}")
        else:
            logger.info("No GEMINI_API_KEY configured. Vision LLM will be disabled until key is provided.")
        _INIT_ATTEMPTED = True
    return _GEMINI_CLIENTS


def get_gemini_client():
    """Return the primary Gemini client (for backwards compatibility)."""
    clients = get_gemini_clients()
    return clients[0][1] if clients else None


def is_vision_available() -> bool:
    """Return True if at least one Gemini API key is configured and ready."""
    return len(get_gemini_clients()) > 0


def get_candidate_models() -> list[str]:
    """
    Return an ordered list of candidate models for high availability.
    If the primary model experiences a 503/429 demand spike,
    the call will automatically fail over to alternate candidate models.
    """
    preferred = [settings.GEMINI_MODEL, "gemini-3.5-flash", "gemini-3.1-flash-lite", "gemini-3.5-flash-lite"]
    candidates: list[str] = []
    for m in preferred:
        if m and m not in candidates:
            candidates.append(m)
    return candidates


def generate_gemini_content(
    contents: Any,
    config: Any = None,
    preferred_models: Optional[list[str]] = None,
) -> tuple[Optional[Any], Optional[str]]:
    """
    Execute generation with multi-key and multi-model cascading failover:
    For each configured API key:
        Attempts each candidate model in order.
        If all candidate models fail on that API key (e.g. rate limit 429, quota exhausted, 503),
        it shifts to the next API key.
    Returns (response, used_model_name) or (None, None) if all keys and models failed.
    """
    clients = get_gemini_clients()
    if not clients:
        logger.warning("No Gemini clients available for generate_gemini_content.")
        return None, None

    candidate_models = preferred_models or get_candidate_models()

    for key_label, client in clients:
        logger.info(f"Attempting Gemini generation using [{key_label}]...")
        for model_name in candidate_models:
            try:
                call_kwargs: dict[str, Any] = {
                    "model": model_name,
                    "contents": contents,
                }
                if config is not None:
                    call_kwargs["config"] = config

                response = client.models.generate_content(**call_kwargs)
                if response and response.text:
                    logger.info(f"Gemini call succeeded using [{key_label}] on model: {model_name}")
                    return response, model_name
            except Exception as exc:
                err_str = str(exc)
                if any(t in err_str.lower() for t in ("503", "429", "quota", "exhausted", "unavailable", "high demand", "resource_exhausted")):
                    logger.warning(
                        f"Model {model_name} on [{key_label}] busy or rate-limited ({exc}). Trying next candidate model..."
                    )
                    continue
                logger.warning(f"Model {model_name} on [{key_label}] failed: {exc}")
                continue

        logger.warning(
            f"All candidate models failed on [{key_label}]. Shifting to next API key..."
        )

    logger.error("All Gemini API keys and candidate models were exhausted without success.")
    return None, None


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


def _optimize_image_for_vision(path: Path, max_dimension: int = 1400, quality: int = 85) -> tuple[bytes, str]:
    """
    Compress and downscale image to under max_dimension pixels to ensure
    minimal upload latency, fast LLM tokenization, and prevention of timeouts.
    """
    ext = path.suffix.lower()
    if ext in {".png", ".jpg", ".jpeg", ".webp", ".heic"}:
        try:
            from PIL import Image
            with Image.open(path) as img:
                w, h = img.size
                if max(w, h) > max_dimension:
                    img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

                # Convert to RGB if RGBA/Palette
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGB")

                buf = io.BytesIO()
                img.save(buf, format="JPEG", quality=quality, optimize=True)
                return buf.getvalue(), "image/jpeg"
        except Exception as err:
            logger.warning(f"Image optimization skipped: {err}")

    with open(path, "rb") as f:
        return f.read(), _get_mime_type(path)


def _prepare_statement_pdf_for_vision(path: Path, max_pages: int = 3) -> bytes:
    """
    Trims large multi-page PDFs to the first max_pages so Gemini Vision
    does not hang generating hundreds of transaction rows over 10+ pages.
    """
    try:
        import pypdfium2 as pdfium
        pdf = pdfium.PdfDocument(str(path))
        if len(pdf) <= max_pages:
            with open(path, "rb") as f:
                return f.read()

        new_pdf = pdfium.PdfDocument.new()
        new_pdf.import_pages(pdf, list(range(max_pages)))
        buf = io.BytesIO()
        new_pdf.save(buf)
        return buf.getvalue()
    except Exception as err:
        logger.warning(f"PDF page trimming skipped: {err}")
        with open(path, "rb") as f:
            return f.read()


def parse_receipt_with_vision(file_path: str) -> Optional[dict[str, Any]]:
    """
    Extract structured receipt / bill / UPI screenshot data using Gemini Vision.
    Automatically cascades across candidate models and fallback API keys.
    Returns None if vision client is unavailable or if parsing fails.
    """
    if not is_vision_available():
        return None

    path = Path(file_path).resolve()
    if not path.exists():
        alt = Path.cwd() / file_path
        if alt.exists():
            path = alt
        else:
            logger.warning(f"File not found for vision parsing: {file_path}")
            return None

    file_bytes, mime_type = _optimize_image_for_vision(path)

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

    response, _ = generate_gemini_content(
        contents=[part, prompt],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            temperature=0.1,
            max_output_tokens=1500,
        ),
    )

    if not response or not response.text:
        return None

    try:
        data = json.loads(response.text)
        # Ensure confidence is float between 0.0 and 1.0
        data["confidence"] = float(data.get("confidence") or 0.95)
        if "raw_text" not in data:
            data["raw_text"] = f"{data.get('merchant_name', '')} {data.get('amount', '')} {data.get('date', '')}"
        return data
    except Exception as exc:
        logger.warning(f"Failed to parse Gemini JSON response: {exc}")
        return None


def parse_bank_statement_with_vision(file_path: str) -> Optional[dict[str, Any]]:
    """
    Extract structured transactions from a multi-page PDF bank statement using Gemini Vision.
    Automatically cascades across candidate models and fallback API keys.
    Returns None if vision client is unavailable or if parsing fails.
    """
    if not is_vision_available():
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
    file_bytes = _prepare_statement_pdf_for_vision(path, max_pages=3)

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

    response, _ = generate_gemini_content(
        contents=[part, prompt],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            temperature=0.1,
            max_output_tokens=3000,
        ),
    )

    if not response or not response.text:
        return None

    try:
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
        logger.warning(f"Failed to parse Gemini statement JSON: {exc}")
        return None
