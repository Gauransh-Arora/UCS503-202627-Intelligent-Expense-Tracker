"""Expense splitting router."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.split import ExpenseSplit, Settlement, SettlementStatus, SplitParticipant
from app.models.user import User
from app.schemas.split import SettlementCreate, SettlementResponse, SplitCreate, SplitResponse
from app.services.split_service import compute_split_amounts
from app.utils.auth import get_current_user
from datetime import datetime, timezone

router = APIRouter(prefix="/splits", tags=["Expense Splitting"])


@router.post("/", response_model=SplitResponse, status_code=status.HTTP_201_CREATED)
def create_split(
    split_in: SplitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new expense split with computed participant amounts."""
    # Compute final amounts based on split type
    participants_data = compute_split_amounts(
        split_in.split_type,
        split_in.total_amount,
        split_in.participants,
    )

    split = ExpenseSplit(
        created_by=current_user.id,
        title=split_in.title,
        total_amount=split_in.total_amount,
        currency=split_in.currency,
        split_type=split_in.split_type,
        description=split_in.description,
    )
    db.add(split)
    db.flush()

    for p in participants_data:
        db.add(
            SplitParticipant(
                split_id=split.id,
                participant_name=p["participant_name"],
                participant_user_id=p.get("participant_user_id"),
                amount_owed=p["amount_owed"],
                percentage=p.get("percentage"),
                is_payer=p.get("is_payer", False),
            )
        )

    db.commit()
    db.refresh(split)
    return split


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


@router.get("/{split_id}", response_model=SplitResponse)
def get_split(
    split_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    split = db.query(ExpenseSplit).filter(
        ExpenseSplit.id == split_id,
        ExpenseSplit.created_by == current_user.id,
    ).first()
    if not split:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split not found")
    return split


@router.post("/settlements", response_model=SettlementResponse, status_code=status.HTTP_201_CREATED)
def record_settlement(
    settlement_in: SettlementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Record that a participant has settled their debt."""
    # Verify split belongs to current user
    split = db.query(ExpenseSplit).filter(
        ExpenseSplit.id == settlement_in.split_id,
        ExpenseSplit.created_by == current_user.id,
    ).first()
    if not split:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split not found")

    settlement = Settlement(
        split_id=settlement_in.split_id,
        payer_name=settlement_in.payer_name,
        payee_name=settlement_in.payee_name,
        amount=settlement_in.amount,
        status=SettlementStatus.SETTLED,
        settled_at=datetime.now(timezone.utc),
    )
    db.add(settlement)
    db.commit()
    db.refresh(settlement)
    return settlement
