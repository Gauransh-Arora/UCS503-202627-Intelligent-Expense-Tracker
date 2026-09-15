"""Transactions router — full CRUD with filtering."""
from datetime import date
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.transaction import Transaction, TransactionItem, VerificationStatus
from app.models.user import User
from app.schemas.transaction import (
    TransactionCreate,
    TransactionResponse,
    TransactionUpdate,
)
from app.services.categorization_service import categorize_merchant
from app.utils.auth import get_current_user

router = APIRouter(prefix="/transactions", tags=["Transactions"])


def _get_transaction_or_404(tx_id: UUID, user_id: UUID, db: Session) -> Transaction:
    """Fetch a transaction belonging to the current user or raise 404."""
    tx = (
        db.query(Transaction)
        .filter(
            Transaction.id == tx_id,
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .first()
    )
    if not tx:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")
    return tx


@router.post("/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    tx_in: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new expense transaction."""
    # Auto-categorize if no category provided
    category_id = tx_in.category_id
    auto_categorized = False
    if category_id is None:
        suggested = categorize_merchant(tx_in.merchant_name, current_user.id, db)
        if suggested:
            category_id = suggested
            auto_categorized = True

    tx = Transaction(
        user_id=current_user.id,
        merchant_name=tx_in.merchant_name,
        amount=tx_in.amount,
        currency=tx_in.currency,
        transaction_date=tx_in.transaction_date,
        payment_method=tx_in.payment_method,
        description=tx_in.description,
        category_id=category_id,
        document_id=tx_in.document_id,
        auto_categorized=auto_categorized,
        verification_status=VerificationStatus.AUTO,
    )
    db.add(tx)
    db.flush()  # get tx.id before inserting items

    for item_in in tx_in.items:
        db.add(
            TransactionItem(
                transaction_id=tx.id,
                item_name=item_in.item_name,
                quantity=item_in.quantity,
                unit_price=item_in.unit_price,
                total_price=item_in.total_price,
            )
        )

    db.commit()
    db.refresh(tx)
    return tx


@router.get("/", response_model=list[TransactionResponse])
def list_transactions(
    category_id: Optional[UUID] = Query(None),
    payment_method: Optional[str] = Query(None),
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    merchant: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List transactions for the current user with optional filtering."""
    q = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.is_deleted == False,
    )

    if category_id:
        q = q.filter(Transaction.category_id == category_id)
    if payment_method:
        q = q.filter(Transaction.payment_method == payment_method)
    if month:
        q = q.filter(Transaction.transaction_date.month == month)  # type: ignore[attr-defined]
        from sqlalchemy import extract
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        from sqlalchemy import extract
        q = q.filter(extract("year", Transaction.transaction_date) == year)
    if start_date:
        q = q.filter(Transaction.transaction_date >= start_date)
    if end_date:
        q = q.filter(Transaction.transaction_date <= end_date)
    if merchant:
        q = q.filter(Transaction.merchant_name.ilike(f"%{merchant}%"))

    return q.order_by(Transaction.transaction_date.desc()).offset(offset).limit(limit).all()


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single transaction by ID."""
    return _get_transaction_or_404(transaction_id, current_user.id, db)


@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(
    transaction_id: UUID,
    tx_update: TransactionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update an existing transaction. Partial updates supported."""
    tx = _get_transaction_or_404(transaction_id, current_user.id, db)

    update_data = tx_update.model_dump(exclude_unset=True)

    # If user is correcting the category, learn the preference
    if "category_id" in update_data and update_data["category_id"] != tx.category_id:
        from app.services.categorization_service import save_user_preference
        save_user_preference(tx.merchant_name, update_data["category_id"], current_user.id, db)

    for field, value in update_data.items():
        setattr(tx, field, value)

    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(
    transaction_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft-delete a transaction."""
    tx = _get_transaction_or_404(transaction_id, current_user.id, db)
    tx.is_deleted = True
    db.commit()
