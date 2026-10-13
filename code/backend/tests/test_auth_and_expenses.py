"""Tests for Module 1: Authentication and expense management."""
from datetime import date
import uuid
import pytest

from app.models.category import Category
from app.models.document import Document, DocumentType, ProcessingStatus
from app.schemas.transaction import TransactionCreate, TransactionItemCreate, TransactionUpdate
from app.services.auth_service import login_user, register_user
from app.services.transaction_service import (
    create_transaction,
    delete_transaction,
    get_categories,
    get_transaction_details,
    get_transactions,
    update_transaction,
)


def test_register_and_login_service(db_session):
    # 1. register_user()
    user, token = register_user(
        name="Alice Smith",
        email="alice@example.com",
        password="secretpassword",
        db=db_session,
    )
    assert user.name == "Alice Smith"
    assert user.email == "alice@example.com"
    assert token is not None

    # 2. login_user()
    logged_user, login_token = login_user("alice@example.com", "secretpassword", db_session)
    assert logged_user.id == user.id
    assert login_token is not None


def test_auth_endpoints(client):
    # Test register endpoint
    reg_res = client.post(
        "/auth/register",
        json={"name": "Bob Jones", "email": "bob@example.com", "password": "securepassword123"},
    )
    assert reg_res.status_code == 201
    data = reg_res.json()
    assert "access_token" in data
    assert data["user"]["email"] == "bob@example.com"

    # Test login endpoint
    login_res = client.post(
        "/auth/login",
        json={"email": "bob@example.com", "password": "securepassword123"},
    )
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()

    # Test get_current_user endpoint
    token = login_res.json()["access_token"]
    me_res = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    assert me_res.json()["name"] == "Bob Jones"


def test_get_categories(db_session, client, auth_headers):
    # Service function
    cats = get_categories(db_session)
    assert len(cats) >= 5
    cat_names = [c.name for c in cats]
    assert "Food" in cat_names

    # API endpoint
    res = client.get("/categories/", headers=auth_headers)
    assert res.status_code == 200
    assert any(c["name"] == "Food" for c in res.json())


def test_transaction_crud_and_details(db_session, test_user, client, auth_headers):
    food_cat = db_session.query(Category).filter(Category.name == "Food").first()

    # Source document mock
    doc = Document(
        user_id=test_user.id,
        original_filename="receipt.jpg",
        file_url="/uploads/receipt.jpg",
        document_type=DocumentType.RECEIPT.value,
        processing_status=ProcessingStatus.PROCESSED.value,
        ocr_confidence=0.95,
        ocr_text="Total: 450",
    )
    db_session.add(doc)
    db_session.commit()
    db_session.refresh(doc)

    # 1. create_transaction()
    tx_in = TransactionCreate(
        merchant_name="Starbucks",
        amount=450.0,
        currency="INR",
        transaction_date=date(2026, 9, 15),
        payment_method="upi",
        description="Coffee and muffin",
        category_id=food_cat.id,
        document_id=doc.id,
        items=[
            TransactionItemCreate(name="Cappuccino", quantity=1, unit_price=250.0, total_price=250.0),
            TransactionItemCreate(name="Blueberry Muffin", quantity=1, unit_price=200.0, total_price=200.0),
        ],
    )
    tx = create_transaction(test_user.id, tx_in, db_session)
    assert tx.id is not None
    assert tx.merchant_name == "Starbucks"
    assert len(tx.items) == 2

    # 2. get_transactions()
    tx_list = get_transactions(test_user.id, db_session)
    assert len(tx_list) == 1
    assert tx_list[0].id == tx.id

    # 3. get_transaction_details() - merchant, items, category, source document
    details = get_transaction_details(tx.id, test_user.id, db_session)
    assert details.merchant_name == "Starbucks"
    assert details.category is not None
    assert details.category.name == "Food"
    assert details.source_document is not None
    assert details.source_document.original_filename == "receipt.jpg"
    assert len(details.items) == 2
    assert details.items[0].name == "Cappuccino"

    # API test for get_transaction_details
    det_res = client.get(f"/transactions/{tx.id}/details", headers=auth_headers)
    assert det_res.status_code == 200
    det_json = det_res.json()
    assert det_json["merchant_name"] == "Starbucks"
    assert det_json["category"]["name"] == "Food"
    assert det_json["source_document"]["original_filename"] == "receipt.jpg"

    # 4. update_transaction()
    update_data = TransactionUpdate(merchant_name="Starbucks Coffee", amount=500.0)
    updated = update_transaction(tx.id, test_user.id, update_data, db_session)
    assert updated.merchant_name == "Starbucks Coffee"
    assert updated.amount == 500.0

    # 5. delete_transaction()
    deleted = delete_transaction(tx.id, test_user.id, db_session)
    assert deleted is True
    # Verify soft delete
    remaining = get_transactions(test_user.id, db_session)
    assert len(remaining) == 0
