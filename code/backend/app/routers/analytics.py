"""Analytics router — category, monthly, merchant, item breakdowns, comparisons, and summaries."""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.analytics import (
    AnalyticsSummary,
    CategoryBreakdown,
    ItemSpendingSummary,
    MerchantSummary,
    MonthlyComparison,
    MonthlySummary,
    SpendingSummaryResponse,
    SpendingTrend,
)
from app.services.analytics_service import (
    compare_monthly_spending as service_compare_monthly_spending,
    generate_spending_summary as service_generate_spending_summary,
    get_category_wise_spending as service_get_category_wise_spending,
    get_dashboard_statistics as service_get_dashboard_statistics,
    get_item_wise_spending as service_get_item_wise_spending,
    get_merchant_wise_spending as service_get_merchant_wise_spending,
    get_monthly_spending as service_get_monthly_spending,
    get_spending_trends as service_get_spending_trends,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/summary", response_model=AnalyticsSummary)
@router.get("/dashboard", response_model=AnalyticsSummary)
def get_dashboard_statistics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """High-level aggregated dashboard statistics."""
    return service_get_dashboard_statistics(current_user.id, db)


# Alias
analytics_summary = get_dashboard_statistics


@router.get("/monthly", response_model=MonthlySummary)
def get_monthly_spending(
    month: int = Query(..., ge=1, le=12),
    year: int = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detailed monthly expense totals and breakdowns."""
    return service_get_monthly_spending(current_user.id, month, year, db)


# Alias
monthly_analytics = get_monthly_spending


@router.get("/categories", response_model=list[CategoryBreakdown])
def get_category_wise_spending(
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Category-level spending breakdown."""
    return service_get_category_wise_spending(current_user.id, db, month=month, year=year)


# Alias
category_analytics = get_category_wise_spending


@router.get("/merchants", response_model=list[MerchantSummary])
def get_merchant_wise_spending(
    limit: int = Query(10, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Merchant-level spending analysis."""
    return service_get_merchant_wise_spending(current_user.id, db, limit=limit)


# Alias
merchant_analytics = get_merchant_wise_spending


@router.get("/items", response_model=list[ItemSpendingSummary])
def get_item_wise_spending(
    limit: int = Query(20, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Individual item analysis across all transactions."""
    return service_get_item_wise_spending(current_user.id, db, limit=limit)


@router.get("/trends", response_model=list[SpendingTrend])
def get_spending_trends(
    months: int = Query(6, ge=1, le=24),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Monthly historical spending trends."""
    return service_get_spending_trends(current_user.id, db, months=months)


# Alias
spending_trends = get_spending_trends


@router.get("/compare", response_model=MonthlyComparison)
def compare_monthly_spending(
    current_month: Optional[int] = Query(None, ge=1, le=12),
    current_year: Optional[int] = Query(None),
    prev_month: Optional[int] = Query(None, ge=1, le=12),
    prev_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Compare current month spending versus previous month."""
    return service_compare_monthly_spending(
        user_id=current_user.id,
        db=db,
        current_month=current_month,
        current_year=current_year,
        prev_month=prev_month,
        prev_year=prev_year,
    )


@router.get("/spending-summary", response_model=SpendingSummaryResponse)
@router.get("/summary-text", response_model=SpendingSummaryResponse)
def generate_spending_summary(
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate “Where did my money go?” comprehensive financial summary."""
    return service_generate_spending_summary(
        user_id=current_user.id,
        db=db,
        month=month,
        year=year,
    )
