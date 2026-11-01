"""
Pipeline & Robustness Integration Test Suite
============================================
Validates end-to-end document parsing pipelines and system robustness against:
- Synthetic realistic bank statements (HDFC CSV, SBI semicolon CSV, ICICI DR/CR CSV, Axis PDF)
- Malformed inputs: empty CSV statements, invalid file extensions
- Error handling, status codes, and non-crashing graceful degradation
"""
from decimal import Decimal
import json
from pathlib import Path

import pytest
from starlette.testclient import TestClient

from app.services.bank_statement_service import parse_bank_statement

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def expected_fixtures():
    json_path = FIXTURES_DIR / "expected_fixtures.json"
    with open(json_path, "r", encoding="utf-8") as f:
        return json.load(f)


# ── 1. Realistic Synthetic Bank Statements Pipelines ────────────────────────────

def test_hdfc_bank_statement_csv_pipeline(expected_fixtures):
    """Verify parsing and balance reconciliation on HDFC standard comma CSV."""
    csv_path = FIXTURES_DIR / "statement_hdfc.csv"
    assert csv_path.exists(), "statement_hdfc.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_hdfc.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01
    assert result["balance_reconciled"] is True


def test_sbi_bank_statement_semicolon_pipeline(expected_fixtures):
    """Verify delimiter auto-detection and column matching on SBI semicolon CSV."""
    csv_path = FIXTURES_DIR / "statement_sbi.csv"
    assert csv_path.exists(), "statement_sbi.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_sbi.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01
    assert result["balance_reconciled"] is True


def test_icici_bank_statement_drcr_pipeline(expected_fixtures):
    """Verify Type column DR/CR signed debit/credit mapping on ICICI CSV."""
    csv_path = FIXTURES_DIR / "statement_icici.csv"
    assert csv_path.exists(), "statement_icici.csv fixture must exist"

    result = parse_bank_statement(str(csv_path))
    expected = expected_fixtures["statement_icici.csv"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01
    assert result["balance_reconciled"] is True


def test_axis_bank_statement_pdf_pipeline(expected_fixtures):
    """Verify PDF statement parsing via pdfplumber/PyMuPDF."""
    pdf_path = FIXTURES_DIR / "statement_axis.pdf"
    assert pdf_path.exists(), "statement_axis.pdf fixture must exist"

    result = parse_bank_statement(str(pdf_path))
    expected = expected_fixtures["statement_axis.pdf"]

    assert len(result["rows"]) == expected["transaction_count"]
    assert abs(result["total_debits"] - expected["total_debits"]) < 0.01
    assert abs(result["total_credits"] - expected["total_credits"]) < 0.01


# ── 2. Robustness & Malformed Inputs Tests ──────────────────────────────────────

def test_robustness_empty_statement_csv():
    """Verify parser handles 0-byte or whitespace-only CSV without unhandled exceptions."""
    empty_csv = FIXTURES_DIR / "empty_statement.csv"
    assert empty_csv.exists()

    result = parse_bank_statement(str(empty_csv))
    assert result["rows"] == []
    assert result["total_debits"] == 0.0
    assert result["total_credits"] == 0.0
    assert result["balance_reconciled"] is True


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
