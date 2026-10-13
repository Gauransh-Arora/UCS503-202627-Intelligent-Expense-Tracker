"""Financial Intelligence router — unusual spending, recurring expenses, and subscriptions."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.wishlist import SubscriptionResponse
from app.services.intelligence_service import (
    detect_recurring_expenses as service_detect_recurring,
    detect_subscriptions as service_detect_subscriptions,
    detect_unusual_spending as service_detect_unusual,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/intelligence", tags=["Financial Intelligence"])


@router.get("/unusual-spending", response_model=list[str])
def detect_unusual_spending(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Flag spending that deviates from historical patterns."""
    return service_detect_unusual(current_user.id, db)


@router.get("/recurring", response_model=list[dict])
def detect_recurring_expenses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Identify recurring payments across historical transactions."""
    return service_detect_recurring(current_user.id, db)


@router.get("/subscriptions", response_model=list[SubscriptionResponse])
def detect_subscriptions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Identify likely subscriptions (streaming, SaaS, gym, utilities)."""
    return service_detect_subscriptions(current_user.id, db)
