"""Transactions router — full CRUD, chronological history, and detailed breakdown."""
from datetime import date
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.transaction import (
    TransactionCreate,
    TransactionDetailResponse,
    TransactionResponse,
    TransactionUpdate,
)
from app.services.transaction_service import (
    create_transaction as service_create_transaction,
    delete_transaction as service_delete_transaction,
    get_transaction_details as service_get_transaction_details,
    get_transactions as service_get_transactions,
    update_transaction as service_update_transaction,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/transactions", tags=["Transactions"])


@router.post("/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    tx_in: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new expense transaction."""
    return service_create_transaction(current_user.id, tx_in, db)


@router.get("/", response_model=list[TransactionResponse])
def get_transactions(
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
    """Retrieve chronological expense history with optional filters."""
    return service_get_transactions(
        user_id=current_user.id,
        db=db,
        category_id=category_id,
        payment_method=payment_method,
        month=month,
        year=year,
        start_date=start_date,
        end_date=end_date,
        merchant=merchant,
        limit=limit,
        offset=offset,
    )


# Alias
list_transactions = get_transactions


@router.get("/{transaction_id}", response_model=TransactionDetailResponse)
def get_transaction(
    transaction_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get single transaction with full merchant, items, category, and source document details."""
    return service_get_transaction_details(transaction_id, current_user.id, db)


@router.get("/{transaction_id}/details", response_model=TransactionDetailResponse)
def get_transaction_details(
    transaction_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Explicit endpoint for merchant, items, category, and source document."""
    return service_get_transaction_details(transaction_id, current_user.id, db)


@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(
    transaction_id: UUID,
    tx_update: TransactionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update transaction details. Partial updates supported."""
    return service_update_transaction(transaction_id, current_user.id, tx_update, db)


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(
    transaction_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft-delete an expense transaction."""
    service_delete_transaction(transaction_id, current_user.id, db)
