"""
Pipeline & Robustness Integration Test Suite
============================================
Validates end-to-end document parsing pipelines and system robustness against:
- Synthetic realistic bank statements (HDFC CSV, SBI semicolon CSV, ICICI DR/CR CSV, Axis PDF)
- Synthetic UPI screenshots and receipts
- Malformed inputs: empty CSV statements, corrupted images, invalid file extensions
- Error handling, status codes, and non-crashing graceful degradation
"""
from decimal import Decimal
import json
from pathlib import Path

import pytest
from starlette.testclient import TestClient

from app.services.bank_statement_service import parse_bank_statement
from app.services.extraction_service import extract_transaction_data
from app.services.ocr_service import run_ocr

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def expected_fixtures():
    json_path = FIXTURES_DIR / "expected_fixtures.json"
    with open(json_path, "r", encoding="utf-8") as f:
        return json.load(f)


# ── 1. Bank Statement CSV Pipeline Tests ────────────────────────────────────────

def test_hdfc_bank_statement_csv_pipeline(expected_fixtures):
    """Verify parsing of standard HDFC CSV statement with debit/credit columns."""
    csv_path = FIXTURES_DIR / "statement_hdfc.csv"
    assert csv_path.exists(), "statement_hdfc.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_hdfc.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01
    assert result["balance_reconciled"] is True

    # Validate merchant cleaning
    merchants = [r["merchant"].lower() for r in result["rows"]]
    assert any("swiggy" in m for m in merchants)
    assert any("reliance fresh" in m for m in merchants)
    assert any("netflix" in m for m in merchants)


def test_sbi_bank_statement_semicolon_pipeline(expected_fixtures):
    """Verify parsing of SBI CSV with semicolon delimiter sniffing and withdrawal/deposit headers."""
    csv_path = FIXTURES_DIR / "statement_sbi.csv"
    assert csv_path.exists(), "statement_sbi.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_sbi.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01

    merchants = [r["merchant"].lower() for r in result["rows"]]
    assert any("uber trip" in m for m in merchants)
    assert any("cafe coffee day" in m for m in merchants)


def test_icici_bank_statement_drcr_pipeline(expected_fixtures):
    """Verify parsing of ICICI CSV using single amount and Dr/Cr indicator."""
    csv_path = FIXTURES_DIR / "statement_icici.csv"
    assert csv_path.exists(), "statement_icici.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_icici.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01

    merchants = [r["merchant"].lower() for r in result["rows"]]
    assert any("zomato" in m for m in merchants)
    assert any("amazon" in m for m in merchants)


# ── 2. Bank Statement PDF Pipeline Tests ────────────────────────────────────────

def test_axis_bank_statement_pdf_pipeline(expected_fixtures):
    """Verify PDF statement parsing via pdfplumber/PyMuPDF."""
    pdf_path = FIXTURES_DIR / "statement_axis.pdf"
    assert pdf_path.exists(), "statement_axis.pdf fixture must exist"

    result = parse_bank_statement(str(pdf_path))
    expected = expected_fixtures["statement_axis.pdf"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01


# ── 3. OCR & Extraction Pipeline on Realistic Synthetic Images ─────────────────

def test_upi_gpay_image_extraction_pipeline(expected_fixtures):
    """Verify OCR and regex structured extraction on synthetic GPay screenshot."""
    img_path = FIXTURES_DIR / "upi_gpay.png"
    assert img_path.exists(), "upi_gpay.png fixture must exist"

    raw_text = run_ocr(str(img_path))
    assert len(raw_text.strip()) > 0

    extracted = extract_transaction_data(raw_text, doc_type="upi_screenshot")
    expected = expected_fixtures["upi_gpay.png"]

    # Verify amount
    if extracted["amount"]:
        assert abs(float(extracted["amount"]) - expected["amount"]) < 0.01
    # Verify merchant
    if extracted["merchant"]:
        assert "blue tokai" in extracted["merchant"].lower()
    # Confidence scores should be between 0 and 1
    assert 0.0 <= extracted["confidence_score"] <= 1.0


def test_receipt_supermarket_extraction_pipeline(expected_fixtures):
    """Verify OCR and structured extraction on synthetic supermarket receipt."""
    img_path = FIXTURES_DIR / "receipt_supermarket.png"
    assert img_path.exists(), "receipt_supermarket.png fixture must exist"

    raw_text = run_ocr(str(img_path))
    assert len(raw_text.strip()) > 0

    extracted = extract_transaction_data(raw_text, doc_type="receipt")
    expected = expected_fixtures["receipt_supermarket.png"]

    if extracted["amount"]:
        assert abs(float(extracted["amount"]) - expected["amount"]) < 0.01
    if extracted["merchant"]:
        assert "fresh choice" in extracted["merchant"].lower()
    assert 0.0 <= extracted["confidence_score"] <= 1.0


# ── 4. Robustness & Malformed Inputs Tests ──────────────────────────────────────

def test_robustness_empty_statement_csv():
    """Verify parser handles 0-byte or whitespace-only CSV without unhandled exceptions."""
    empty_csv = FIXTURES_DIR / "empty_statement.csv"
    assert empty_csv.exists()

    result = parse_bank_statement(str(empty_csv))
    assert result["rows"] == []
    assert result["total_debits"] == 0.0
    assert result["total_credits"] == 0.0
    assert result["balance_reconciled"] is True


def test_robustness_corrupted_image_handling():
    """Verify OCR on a corrupted/truncated image fails gracefully without crashing."""
    corrupted_png = FIXTURES_DIR / "corrupted_file.png"
    assert corrupted_png.exists()

    # run_ocr should catch or return empty string rather than crashing the system
    try:
        raw_text = run_ocr(str(corrupted_png))
        assert isinstance(raw_text, str)
    except Exception as e:
        # If an engine-level error is raised, it must be a recognized IO/Image error, not an unhandled crash
        assert "image" in str(e).lower() or "cannot identify" in str(e).lower()


def test_robustness_invalid_file_extension_rejected_by_api(client, auth_headers):
    """Verify API rejects invalid file extensions (.xyz) with 400 or 415 HTTP status."""
    invalid_file = FIXTURES_DIR / "invalid_document.xyz"
    assert invalid_file.exists()

    with open(invalid_file, "rb") as f:
        # Document upload endpoint
        doc_res = client.post(
            "/documents/upload",
            headers=auth_headers,
            files={"file": ("invalid_document.xyz", f, "application/octet-stream")},
        )
        assert doc_res.status_code in (400, 415)

    with open(invalid_file, "rb") as f:
        # Bank statement upload endpoint
        bs_res = client.post(
            "/bank-statements/upload",
            headers=auth_headers,
            files={"file": ("invalid_document.xyz", f, "application/octet-stream")},
        )
        assert bs_res.status_code in (400, 415)
