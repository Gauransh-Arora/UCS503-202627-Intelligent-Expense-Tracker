"""Tests for Bank Statement Upload, Parsing, and Transaction Import."""
import io
import uuid
import pytest
from app.models.bank_statement import BankStatement, StatementStatus
from app.models.transaction import Transaction
from app.services.auth_service import register_user


SAMPLE_CSV = """Date,Description,Debit,Credit,Balance
2026-10-01,Starbucks Coffee,250.00,,4750.00
2026-10-03,Salary Credit,,50000.00,54750.00
2026-10-05,Amazon Retail India,1499.00,,53251.00
2026-10-08,Uber India,320.00,,52931.00
"""


def test_bank_statement_upload_parse_import(client, db_session):
    # 1. Register a test user
    user, token = register_user(
        name="Statement User",
        email="stmt_user@example.com",
        password="password123",
        db=db_session,
    )
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Upload CSV
    files = {
        "file": ("statement.csv", io.BytesIO(SAMPLE_CSV.encode("utf-8")), "text/csv")
    }
    upload_res = client.post("/bank-statements/upload", files=files, headers=headers)
    assert upload_res.status_code == 201
    stmt_data = upload_res.json()
    stmt_id = stmt_data["id"]
    assert stmt_data["status"] == "uploaded"

    # 3. Parse statement
    parse_res = client.post(f"/bank-statements/{stmt_id}/parse", headers=headers)
    assert parse_res.status_code == 200
    parsed_data = parse_res.json()
    assert parsed_data["status"] == "parsed"
    assert parsed_data["total_transactions"] == 4
    assert parsed_data["total_debits"] == 250.00 + 1499.00 + 320.00

    # 4. Import rows as transactions (default: debit only)
    import_res = client.post(
        f"/bank-statements/{stmt_id}/import",
        json={"import_credits": False},
        headers=headers,
    )
    assert import_res.status_code == 200
    import_data = import_res.json()
    assert import_data["imported"] == 3
    assert import_data["skipped"] == 1  # 1 salary credit row skipped

    # 5. Verify transactions exist in DB for the user
    user_txs = (
        db_session.query(Transaction)
        .filter(Transaction.user_id == user.id)
        .order_by(Transaction.amount.desc())
        .all()
    )
    assert len(user_txs) == 3
    merchants = [tx.merchant_name for tx in user_txs]
    assert any("Starbucks" in m for m in merchants)
    assert any("Amazon" in m for m in merchants)
    assert any("Uber" in m for m in merchants)
