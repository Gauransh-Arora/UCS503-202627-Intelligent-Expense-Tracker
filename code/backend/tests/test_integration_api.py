"""
Integration and API Tests for Intelligent Expense Tracker.
Validates end-to-end API flows, verification feedback, bank statement merge,
and strict multi-user data isolation.
"""
import uuid
from decimal import Decimal
from datetime import date
from pathlib import Path
import pytest

from app.models.category import Category
from app.models.document import Document
from app.models.transaction import Transaction, TransactionStatus
from app.models.user import User
from app.utils.security import create_access_token, hash_password

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


@pytest.fixture
def second_user(db_session):
    """Creates a second independent user for data isolation testing."""
    user = User(
        name="Second User",
        email=f"user2_{uuid.uuid4().hex[:6]}@example.com",
        password_hash=hash_password("password456"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def second_auth_headers(second_user):
    token = create_access_token(second_user.id)
    return {"Authorization": f"Bearer {token}"}


# ── 1. Document Upload, Draft Review, Edit & Confirm ─────────────────────────

def test_document_draft_confirm_lifecycle(client, auth_headers, db_session, test_user):
    """UC-01 & UC-02: Upload bill/screenshot -> Draft created -> User verifies/edits -> Confirmed stored."""
    img_path = FIXTURES_DIR / "upi_gpay.png"
    assert img_path.exists()

    with open(img_path, "rb") as f:
        upload_res = client.post(
            "/documents/upload",
            headers=auth_headers,
            files={"file": ("upi_gpay.png", f, "image/png")},
            data={"document_type": "receipt"},
        )
    assert upload_res.status_code == 201
    doc_data = upload_res.json()
    doc_id = doc_data["id"]

    # Process OCR to draft
    process_res = client.post(f"/documents/{doc_id}/process", headers=auth_headers)
    assert process_res.status_code == 200
    draft = process_res.json()
    assert draft["merchant_name"] is not None
    assert draft["amount"] is not None
    assert "field_confidences" in draft

    # Verify no permanent transaction is stored yet!
    txns_before = client.get("/transactions/", headers=auth_headers).json()
    assert len(txns_before) == 0

    # User reviews and edits fields, then confirms
    cat = db_session.query(Category).first()
    confirm_payload = {
        "merchant_name": "Blue Tokai Special",
        "amount": 450.00,
        "currency": "INR",
        "transaction_date": "2026-10-15",
        "category_id": str(cat.id),
        "document_id": doc_id,
        "notes": "Verified Blue Tokai draft",
    }
    confirm_res = client.post("/transactions/", headers=auth_headers, json=confirm_payload)
    assert confirm_res.status_code == 201
    created_tx = confirm_res.json()
    assert created_tx["merchant_name"] == "Blue Tokai Special"

    # Transaction is now permanently stored
    txns_after = client.get("/transactions/", headers=auth_headers).json()
    assert len(txns_after) == 1
    assert txns_after[0]["id"] == created_tx["id"]

    # Confirming draft again is idempotent (does not duplicate)
    dup_res = client.post("/transactions/", headers=auth_headers, json=confirm_payload)
    assert dup_res.status_code in (200, 201)
    txns_idempotent = client.get("/transactions/", headers=auth_headers).json()
    assert len(txns_idempotent) == 1


# ── 2. Discard Draft Leaves No Permanent Records ──────────────────────────────

def test_document_discard_draft_leaves_no_trace(client, auth_headers, db_session, test_user):
    """UC-02: Canceling or discarding draft removes draft document and creates no permanent records."""
    img_path = FIXTURES_DIR / "upi_phonepe.png"
    with open(img_path, "rb") as f:
        upload_res = client.post(
            "/documents/upload",
            headers=auth_headers,
            files={"file": ("upi_phonepe.png", f, "image/png")},
            data={"document_type": "receipt"},
        )
    doc_id = upload_res.json()["id"]

    # Discard draft endpoint
    del_res = client.delete(f"/documents/{doc_id}", headers=auth_headers)
    assert del_res.status_code in (200, 204)

    # Ensure document is gone
    doc_check = client.get(f"/documents/{doc_id}", headers=auth_headers)
    assert doc_check.status_code == 404

    # Ensure no transaction was ever stored
    txns = client.get("/transactions/", headers=auth_headers).json()
    assert len(txns) == 0


# ── 3. Budget & Available Discretionary Budget ─────────────────────────────────

def test_budget_management_and_available_budget(client, auth_headers):
    """UC-06: BudgetPlan CRUD and calculation of available discretionary budget."""
    today = date.today()
    budget_payload = {
        "month": today.month,
        "year": today.year,
        "spending_limit": 25000.0,
        "savings_goal": 5000.0,
        "notes": "Monthly target budget",
    }
    set_res = client.post("/budgets/", headers=auth_headers, json=budget_payload)
    assert set_res.status_code == 201
    budget_data = set_res.json()
    assert float(budget_data["spending_limit"]) == 25000.0
    assert float(budget_data["savings_goal"]) == 5000.0

    # Get available budget
    avail_res = client.get(f"/budgets/available?month={today.month}&year={today.year}", headers=auth_headers)
    assert avail_res.status_code == 200
    avail_data = avail_res.json()
    assert "available_budget" in avail_data
    assert "spending_limit" in avail_data
    assert "spent_so_far" in avail_data


# ── 4. Wishlist & Readiness Analysis ──────────────────────────────────────────

def test_wishlist_readiness_verdict(client, auth_headers):
    """UC-06: Create wishlist item and perform data-driven purchase readiness check."""
    # 1. Create item
    item_res = client.post(
        "/wishlist/",
        headers=auth_headers,
        json={"name": "Noise Cancelling Headphones", "price": 4500.0},
    )
    assert item_res.status_code == 201
    item_id = item_res.json()["id"]

    # 2. Check purchase readiness
    readiness_res = client.post(f"/wishlist/{item_id}/readiness", headers=auth_headers)
    assert readiness_res.status_code == 200
    readiness = readiness_res.json()
    assert readiness["verdict"] in ("Comfortable", "Possible", "Not Recommended Currently")
    assert "purchase_readiness" in readiness


# ── 5. Bank Statement Upload, Parse & Merge ───────────────────────────────────

def test_bank_statement_merge_flow(client, auth_headers, db_session, test_user):
    """UC-08: Upload statement -> Parse -> Review entries -> Merge verified debits."""
    csv_path = FIXTURES_DIR / "statement_hdfc.csv"
    assert csv_path.exists()

    with open(csv_path, "rb") as f:
        upload_res = client.post(
            "/bank-statements/upload",
            headers=auth_headers,
            files={"file": ("statement_hdfc.csv", f, "text/csv")},
        )
    assert upload_res.status_code == 201
    stmt_id = upload_res.json()["id"]

    # Parse statement
    parse_res = client.post(f"/bank-statements/{stmt_id}/parse", headers=auth_headers)
    assert parse_res.status_code == 200
    parsed = parse_res.json()
    assert parsed["total_transactions"] == 4
    assert len(parsed["parsed_rows"]) == 4

    # Merge entries into history
    merge_res = client.post(
        f"/bank-statements/{stmt_id}/merge",
        headers=auth_headers,
        json={},
    )
    assert merge_res.status_code == 200
    merge_data = merge_res.json()
    # HDFC has 3 debits (Swiggy, Reliance Fresh, Netflix) and 1 credit (Salary)
    assert merge_data["merged_count"] == 3
    assert merge_data["skipped_count"] == 1  # 1 credit skipped

    # Verify transactions created in database
    txns = client.get("/transactions/", headers=auth_headers).json()
    assert len(txns) == 3


# ── 6. Strict Multi-User Data Isolation ───────────────────────────────────────

def test_strict_user_data_isolation(
    client, auth_headers, second_auth_headers, db_session, test_user, second_user
):
    """Verify User B can never read or modify User A's data across all endpoints."""
    # Create private transaction under User A
    cat = db_session.query(Category).first()
    txn_a = Transaction(
        user_id=test_user.id,
        category_id=cat.id,
        merchant_name="Secret Merchant A",
        amount=Decimal("999.00"),
        transaction_date=date.today(),
        status=TransactionStatus.CONFIRMED.value,
        is_verified=True,
    )
    db_session.add(txn_a)
    db_session.commit()

    # User B lists transactions -> should NOT see User A's transaction
    txns_b = client.get("/transactions/", headers=second_auth_headers).json()
    assert not any(t["id"] == str(txn_a.id) for t in txns_b)

    # User B attempts to fetch User A's transaction directly -> 404
    fetch_res = client.get(f"/transactions/{txn_a.id}", headers=second_auth_headers)
    assert fetch_res.status_code == 404

    # User B attempts to delete User A's transaction -> 404
    del_res = client.delete(f"/transactions/{txn_a.id}", headers=second_auth_headers)
    assert del_res.status_code == 404

    # User B queries NLQ about Secret Merchant A -> cannot access User A's spending
    nlq_res = client.post(
        "/ai/query",
        headers=second_auth_headers,
        json={"question": "How much did I spend at Secret Merchant A?"},
    )
    assert nlq_res.status_code == 200
    assert "₹0" in nlq_res.json()["answer"] or "no transactions" in nlq_res.json()["answer"].lower()
