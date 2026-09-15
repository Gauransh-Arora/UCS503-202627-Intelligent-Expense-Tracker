"""Analytics router."""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.analytics import AnalyticsSummary, CategoryBreakdown, MerchantSummary, MonthlySummary, SpendingTrend
from app.services.analytics_service import (
    get_analytics_summary,
    get_category_breakdown,
    get_merchant_summary,
    get_monthly_summary,
    get_spending_trend,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/summary", response_model=AnalyticsSummary)
def analytics_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """High-level dashboard summary with current vs previous month comparison."""
    return get_analytics_summary(current_user.id, db)


@router.get("/monthly", response_model=MonthlySummary)
def monthly_analytics(
    month: int = Query(..., ge=1, le=12),
    year: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detailed breakdown for a specific month."""
    return get_monthly_summary(current_user.id, month, year, db)


@router.get("/categories", response_model=list[CategoryBreakdown])
def category_analytics(
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Spending breakdown by category."""
    return get_category_breakdown(current_user.id, db, month=month, year=year)


@router.get("/merchants", response_model=list[MerchantSummary])
def merchant_analytics(
    limit: int = Query(10, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Top merchants by total spending."""
    return get_merchant_summary(current_user.id, db, limit=limit)


@router.get("/trends", response_model=list[SpendingTrend])
def spending_trends(
    months: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Monthly spending trend over the last N months."""
    return get_spending_trend(current_user.id, db, months=months)
