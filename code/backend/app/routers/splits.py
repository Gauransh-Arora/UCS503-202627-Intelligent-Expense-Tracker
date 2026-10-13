"""Expense splitting router."""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.split import ExpenseSplit
from app.models.user import User
from app.schemas.split import (
    SettlementCreate,
    SettlementResponse,
    SplitCreate,
    SplitResponse,
    UserBalanceResponse,
)
from app.services.split_service import (
    calculate_user_balance as service_calculate_user_balance,
    create_expense_split as service_create_expense_split,
    get_settlement_history as service_get_settlement_history,
    record_settlement as service_record_settlement,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/splits", tags=["Expense Splitting"])


@router.post("/", response_model=SplitResponse, status_code=status.HTTP_201_CREATED)
def create_expense_split(
    split_in: SplitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new expense split with computed participant amounts."""
    return service_create_expense_split(current_user.id, split_in, db)


# Alias
create_split = create_expense_split


@router.get("/", response_model=list[SplitResponse])
def list_splits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all expense splits created by the current user."""
    return (
        db.query(ExpenseSplit)
        .filter(ExpenseSplit.created_by == current_user.id)
        .order_by(ExpenseSplit.created_at.desc())
        .all()
    )


@router.get("/balances", response_model=UserBalanceResponse)
def calculate_user_balance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Track who owes whom and compute net balance across all splits and contacts."""
    return service_calculate_user_balance(current_user.id, db)


@router.get("/settlements", response_model=list[SettlementResponse])
def get_settlement_history(
    friend_name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve debt settlement history, optionally filtered by friend name."""
    return service_get_settlement_history(current_user.id, db, friend_name=friend_name)


@router.post("/settlements", response_model=SettlementResponse, status_code=status.HTTP_201_CREATED)
def record_settlement(
    settlement_in: SettlementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Record that a participant has settled their debt."""
    return service_record_settlement(
        user_id=current_user.id,
        settlement_in=settlement_in,
        db=db,
    )


@router.get("/{split_id}", response_model=SplitResponse)
def get_split(
    split_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get single split details."""
    split = db.query(ExpenseSplit).filter(
        ExpenseSplit.id == split_id,
        ExpenseSplit.created_by == current_user.id,
    ).first()
    if not split:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split not found")
    return split
