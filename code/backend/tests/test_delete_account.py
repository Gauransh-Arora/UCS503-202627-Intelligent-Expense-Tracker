"""Tests for Delete Account backend endpoint and cascading data/file cleanup."""
from datetime import date
from decimal import Decimal
from pathlib import Path
import uuid
import pytest

from app.config import settings
from app.models.bank_statement import BankStatement, StatementStatus
from app.models.budget_plan import BudgetPlan
from app.models.category import Category
from app.models.document import Document, ProcessingStatus
from app.models.friend import Friend
from app.models.notification import Notification, NotificationType
from app.models.preference import UserCategoryPreference
from app.models.recurring import Frequency, RecurringExpense
from app.models.split import ExpenseSplit, Settlement, SettlementStatus, SplitParticipant, SplitType
from app.models.transaction import Transaction, TransactionItem
from app.models.user import User
from app.models.wishlist import WishlistItem
from app.services.auth_service import register_user


def test_delete_account_removes_all_supabase_data_and_local_uploads(client, db_session):
    # 1. Create primary user and secondary user
    user1, token1 = register_user("User One", "user1@example.com", "password123", db_session)
    user2, token2 = register_user("User Two", "user2@example.com", "password123", db_session)

    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    food_cat = db_session.query(Category).filter(Category.name == "Food").first()
    assert food_cat is not None

    # 2. Create local upload files and folders for user1
    user1_upload_dir = Path(settings.UPLOAD_DIR) / str(user1.id)
    user1_upload_dir.mkdir(parents=True, exist_ok=True)
    doc_file = user1_upload_dir / "receipt.jpg"
    doc_file.write_text("dummy receipt image content")

    user1_stmt_dir = Path(settings.UPLOAD_DIR) / "statements" / str(user1.id)
    user1_stmt_dir.mkdir(parents=True, exist_ok=True)
    stmt_file = user1_stmt_dir / "statement.csv"
    stmt_file.write_text("dummy statement csv content")

    assert doc_file.exists()
    assert stmt_file.exists()

    # 3. Create Document and BankStatement records
    doc = Document(
        user_id=user1.id,
        original_filename="receipt.jpg",
        file_url=str(doc_file),
        document_type="receipt",
        processing_status=ProcessingStatus.PROCESSED.value,
    )
    stmt = BankStatement(
        user_id=user1.id,
        original_filename="statement.csv",
        file_url=str(stmt_file),
        status=StatementStatus.PARSED.value,
    )
    db_session.add_all([doc, stmt])
    db_session.commit()

    # 4. Create Transaction with TransactionItems
    tx = Transaction(
        user_id=user1.id,
        category_id=food_cat.id,
        document_id=doc.id,
        merchant_name="Supermarket",
        amount=Decimal("1500.00"),
        transaction_date=date.today(),
        payment_method="upi",
    )
    db_session.add(tx)
    db_session.commit()

    item = TransactionItem(
        transaction_id=tx.id,
        name="Groceries box",
        quantity=1,
        total_price=Decimal("1500.00"),
    )
    db_session.add(item)
    db_session.commit()
    item_id = item.id

    # 5. Create WishlistItem, RecurringExpense, BudgetPlan, Notification, Friend, Preference
    wishlist = WishlistItem(
        user_id=user1.id,
        name="Noise Cancelling Headphones",
        expected_price=Decimal("12000.00"),
    )
    recurring = RecurringExpense(
        user_id=user1.id,
        merchant_name="Netflix",
        average_amount=649.0,
        frequency=Frequency.MONTHLY,
    )
    budget = BudgetPlan(
        user_id=user1.id,
        month="2026-11",
        spending_limit=Decimal("50000.00"),
    )
    notif = Notification(
        user_id=user1.id,
        title="Welcome!",
        message="Your account is ready",
        notification_type=NotificationType.SYSTEM.value,
    )
    friend = Friend(
        user_id=user1.id,
        name="Alex",
        email="alex@example.com",
    )
    pref = UserCategoryPreference(
        user_id=user1.id,
        category_id=food_cat.id,
        merchant_name="Supermarket",
    )
    db_session.add_all([wishlist, recurring, budget, notif, friend, pref])
    db_session.commit()

    # 6. Create ExpenseSplit created by user1
    split1 = ExpenseSplit(
        created_by=user1.id,
        title="Team Lunch",
        total_amount=Decimal("1000.00"),
    )
    db_session.add(split1)
    db_session.commit()
    split1_id = split1.id

    p1 = SplitParticipant(
        split_id=split1.id,
        participant_name="User One",
        participant_user_id=user1.id,
        amount_owed=Decimal("500.00"),
    )
    p2 = SplitParticipant(
        split_id=split1.id,
        participant_name="User Two",
        participant_user_id=user2.id,
        amount_owed=Decimal("500.00"),
    )
    settlement1 = Settlement(
        user_id=user1.id,
        split_id=split1.id,
        payer_name="User Two",
        payee_name="User One",
        amount=Decimal("500.00"),
    )
    db_session.add_all([p1, p2, settlement1])

    # 7. Create ExpenseSplit created by user2 where user1 is a participant
    split2 = ExpenseSplit(
        created_by=user2.id,
        title="Movie Night",
        total_amount=Decimal("600.00"),
    )
    db_session.add(split2)
    db_session.commit()

    p_other = SplitParticipant(
        split_id=split2.id,
        participant_name="User One",
        participant_user_id=user1.id,
        amount_owed=Decimal("300.00"),
    )
    db_session.add(p_other)
    db_session.commit()
    p_other_id = p_other.id

    user1_id = user1.id

    # 8. Delete user1 account via DELETE /auth/me
    del_res = client.delete("/auth/me", headers=headers1)
    assert del_res.status_code == 200
    assert "deleted successfully" in del_res.json()["message"]

    # 9. Verify user1 cannot authenticate anymore
    me_res = client.get("/auth/me", headers=headers1)
    assert me_res.status_code == 401

    # 10. Verify user1 is gone from DB
    deleted_user = db_session.query(User).filter(User.id == user1_id).first()
    assert deleted_user is None

    # 11. Verify all associated records for user1 in DB are deleted
    assert db_session.query(Transaction).filter(Transaction.user_id == user1_id).count() == 0
    assert db_session.query(TransactionItem).filter(TransactionItem.id == item_id).count() == 0
    assert db_session.query(Document).filter(Document.user_id == user1_id).count() == 0
    assert db_session.query(BankStatement).filter(BankStatement.user_id == user1_id).count() == 0
    assert db_session.query(WishlistItem).filter(WishlistItem.user_id == user1_id).count() == 0
    assert db_session.query(RecurringExpense).filter(RecurringExpense.user_id == user1_id).count() == 0
    assert db_session.query(BudgetPlan).filter(BudgetPlan.user_id == user1_id).count() == 0
    assert db_session.query(Notification).filter(Notification.user_id == user1_id).count() == 0
    assert db_session.query(Friend).filter(Friend.user_id == user1_id).count() == 0
    assert db_session.query(UserCategoryPreference).filter(UserCategoryPreference.user_id == user1_id).count() == 0
    assert db_session.query(ExpenseSplit).filter(ExpenseSplit.created_by == user1_id).count() == 0
    assert db_session.query(Settlement).filter(Settlement.split_id == split1_id).count() == 0

    # 12. Verify user2's split still exists and user1's participant record was disassociated safely
    p_check = db_session.query(SplitParticipant).filter(SplitParticipant.id == p_other_id).first()
    assert p_check is not None
    assert p_check.participant_user_id is None
    assert p_check.participant_name == "User One"

    # 13. Verify local uploads files and directories were removed from disk
    assert not doc_file.exists()
    assert not stmt_file.exists()
    assert not user1_upload_dir.exists()
    assert not user1_stmt_dir.exists()


def test_delete_account_alias_endpoint(client, db_session):
    user, token = register_user("Alias Test", "alias@example.com", "password123", db_session)
    res = client.delete("/auth/account", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert "deleted successfully" in res.json()["message"]

    # Verify user is deleted
    assert db_session.query(User).filter(User.id == user.id).first() is None


def test_delete_account_unauthorized(client):
    res = client.delete("/auth/me")
    assert res.status_code == 401
