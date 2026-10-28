"""
Tests for OCR Service and Transaction Data Extraction using test images.
"""
from pathlib import Path
import pytest
from app.services.ocr_service import run_ocr
from app.services.extraction_service import extract_transaction_data

TESTS_DIR = Path(__file__).parent


def test_ocr_tes1_image():
    """Test OCR extraction on tests/tes1.jpeg (Google Pay / UPI payment of Rs. 35)."""
    img_path = TESTS_DIR / "tes1.jpeg"
    assert img_path.exists(), f"Test image not found: {img_path}"

    raw_text = run_ocr(str(img_path))
    assert raw_text, "OCR extracted empty text for tes1.jpeg"
    assert "SANTOSH" in raw_text.upper()

    data = extract_transaction_data(raw_text)
    assert data["merchant_name"] == "SANTOSH KUMARI"
    assert data["amount"] == 35.0
    assert data["date"] == "2026-09-10"
    assert data["confidence"] == 1.0


def test_ocr_test2_image():
    """Test OCR extraction on tests/test2.jpeg (Google Pay / UPI payment of Rs. 10 to Travel Eco)."""
    img_path = TESTS_DIR / "test2.jpeg"
    assert img_path.exists(), f"Test image not found: {img_path}"

    raw_text = run_ocr(str(img_path))
    assert raw_text, "OCR extracted empty text for test2.jpeg"
    assert "TRAVEL ECO" in raw_text.upper()

    data = extract_transaction_data(raw_text)
    assert data["merchant_name"] is not None
    assert "TRAVEL ECO" in data["merchant_name"].upper()
    assert data["amount"] == 10.0
    assert data["date"] == "2026-10-14"
    assert data["confidence"] == 1.0
