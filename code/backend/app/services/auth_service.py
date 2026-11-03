"""
Authentication Service — user registration, login, token generation, and account deletion.
"""
from pathlib import Path
import shutil
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.models.bank_statement import BankStatement
from app.models.budget_plan import BudgetPlan
from app.models.document import Document
from app.models.friend import Friend
from app.models.notification import Notification
from app.models.preference import UserCategoryPreference
from app.models.recurring import RecurringExpense
from app.models.split import ExpenseSplit, Settlement, SplitParticipant
from app.models.transaction import Transaction, TransactionItem
from app.models.user import User
from app.models.wishlist import WishlistItem
from app.utils.security import create_access_token, hash_password, verify_password


def register_user(name: str, email: str, password: str, db: Session) -> tuple[User, str]:
    """
    Register a new user account.
    Returns (user, jwt_token).

    Raises:
        HTTPException: If an account with this email already exists.
    """
    existing = db.query(User).filter(User.email == email.strip().lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        name=name.strip(),
        email=email.strip().lower(),
        password_hash=hash_password(password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return user, token


def login_user(email: str, password: str, db: Session) -> tuple[User, str]:
    """
    Authenticate an existing user.
    Returns (user, jwt_token).

    Raises:
        HTTPException: If credentials are invalid or account is disabled.
    """
    user = db.query(User).filter(User.email == email.strip().lower()).first()

    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )

    token = create_access_token(user.id)
    return user, token


def delete_user_account(user: User, db: Session) -> None:
    """
    Permanently delete a user account and all associated data:
    1. Removes all uploaded files (receipts, statements) and user upload directories.
    2. Deletes or disassociates all database entities (Supabase PostgreSQL / SQLite).
    """
    user_id = user.id
    user_id_str = str(user_id)

    # 1. Local file uploads cleanup
    try:
        docs = db.query(Document).filter(Document.user_id == user_id).all()
        for doc in docs:
            if doc.file_url:
                try:
                    p = Path(doc.file_url)
                    if p.is_file():
                        p.unlink()
                except Exception:
                    pass

        statements = db.query(BankStatement).filter(BankStatement.user_id == user_id).all()
        for stmt in statements:
            if stmt.file_url:
                try:
                    p = Path(stmt.file_url)
                    if p.is_file():
                        p.unlink()
                except Exception:
                    pass
    except Exception:
        pass

    # Clean up user directories across possible upload root paths
    base_upload_dirs = [
        Path(settings.UPLOAD_DIR),
        Path("uploads"),
        Path(__file__).resolve().parent.parent.parent / "uploads",
        Path(__file__).resolve().parent.parent.parent.parent / "uploads",
    ]
    for base in base_upload_dirs:
        try:
            user_dir = base / user_id_str
            if user_dir.is_dir():
                shutil.rmtree(user_dir, ignore_errors=True)
            user_stmt_dir = base / "statements" / user_id_str
            if user_stmt_dir.is_dir():
                shutil.rmtree(user_stmt_dir, ignore_errors=True)
        except Exception:
            pass

    # 2. Database cleanup (Supabase / SQLAlchemy)
    # Disassociate this user from splits created by others
    db.query(SplitParticipant).filter(SplitParticipant.participant_user_id == user_id).update(
        {SplitParticipant.participant_user_id: None},
        synchronize_session=False,
    )

    # Delete settlements where user is payer/payee or linked
    db.query(Settlement).filter(Settlement.user_id == user_id).delete(synchronize_session=False)

    # Delete splits created by this user
    user_splits = db.query(ExpenseSplit).filter(ExpenseSplit.created_by == user_id).all()
    if user_splits:
        split_ids = [s.id for s in user_splits]
        db.query(Settlement).filter(Settlement.split_id.in_(split_ids)).delete(synchronize_session=False)
        db.query(SplitParticipant).filter(SplitParticipant.split_id.in_(split_ids)).delete(synchronize_session=False)
        db.query(ExpenseSplit).filter(ExpenseSplit.id.in_(split_ids)).delete(synchronize_session=False)

    # Clean up transactions and transaction items
    user_txs = db.query(Transaction).filter(Transaction.user_id == user_id).all()
    if user_txs:
        tx_ids = [t.id for t in user_txs]
        db.query(SplitParticipant).filter(SplitParticipant.transaction_id.in_(tx_ids)).update(
            {SplitParticipant.transaction_id: None},
            synchronize_session=False,
        )
        db.query(TransactionItem).filter(TransactionItem.transaction_id.in_(tx_ids)).delete(synchronize_session=False)
        db.query(Transaction).filter(Transaction.id.in_(tx_ids)).delete(synchronize_session=False)

    # Clean up friends
    user_friends = db.query(Friend).filter(Friend.user_id == user_id).all()
    if user_friends:
        friend_ids = [f.id for f in user_friends]
        db.query(SplitParticipant).filter(SplitParticipant.friend_id.in_(friend_ids)).update(
            {SplitParticipant.friend_id: None},
            synchronize_session=False,
        )
        db.query(Friend).filter(Friend.id.in_(friend_ids)).delete(synchronize_session=False)

    # Documents & Bank statements
    db.query(Document).filter(Document.user_id == user_id).delete(synchronize_session=False)
    db.query(BankStatement).filter(BankStatement.user_id == user_id).delete(synchronize_session=False)

    # Preferences, Wishlist, Recurring, Notifications, Budget Plans
    db.query(UserCategoryPreference).filter(UserCategoryPreference.user_id == user_id).delete(synchronize_session=False)
    db.query(WishlistItem).filter(WishlistItem.user_id == user_id).delete(synchronize_session=False)
    db.query(RecurringExpense).filter(RecurringExpense.user_id == user_id).delete(synchronize_session=False)
    db.query(Notification).filter(Notification.user_id == user_id).delete(synchronize_session=False)
    db.query(BudgetPlan).filter(BudgetPlan.user_id == user_id).delete(synchronize_session=False)

    # Finally delete user
    db.delete(user)
    db.commit()
