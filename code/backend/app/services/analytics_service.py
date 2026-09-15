"""
Analytics Service — aggregate queries for spending insights.
"""
from datetime import date, datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.transaction import Transaction
from app.schemas.analytics import (
    AnalyticsSummary,
    CategoryBreakdown,
    MerchantSummary,
    MonthlySummary,
    SpendingTrend,
)
from app.services.intelligence_service import detect_unusual_spending


def _base_query(user_id: UUID, db: Session):
    """Base query for non-deleted transactions belonging to the user."""
    return db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )


def get_category_breakdown(
    user_id: UUID,
    db: Session,
    month: Optional[int] = None,
    year: Optional[int] = None,
) -> list[CategoryBreakdown]:
    """Spending total per category, optionally filtered by month/year."""
    q = (
        db.query(
            Category.name,
            Category.icon,
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
    )

    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    rows = q.group_by(Category.name, Category.icon).order_by(func.sum(Transaction.amount).desc()).all()

    total_spending = sum(r.total for r in rows) or 1.0
    return [
        CategoryBreakdown(
            category_name=r.name,
            category_icon=r.icon,
            total_amount=round(r.total, 2),
            transaction_count=r.count,
            percentage=round(r.total / total_spending * 100, 1),
        )
        for r in rows
    ]


def get_merchant_summary(
    user_id: UUID,
    db: Session,
    limit: int = 10,
) -> list[MerchantSummary]:
    """Top merchants by total spending."""
    rows = (
        db.query(
            Transaction.merchant_name,
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
            func.max(Transaction.transaction_date).label("last_date"),
        )
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .group_by(Transaction.merchant_name)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(limit)
        .all()
    )

    return [
        MerchantSummary(
            merchant_name=r.merchant_name,
            total_amount=round(r.total, 2),
            transaction_count=r.count,
            last_transaction_date=str(r.last_date) if r.last_date else None,
        )
        for r in rows
    ]


def get_spending_trend(
    user_id: UUID,
    db: Session,
    months: int = 6,
) -> list[SpendingTrend]:
    """Monthly spending totals for the last N months."""
    rows = (
        db.query(
            extract("year", Transaction.transaction_date).label("year"),
            extract("month", Transaction.transaction_date).label("month"),
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .group_by("year", "month")
        .order_by("year", "month")
        .all()
    )

    # Return last N months
    trend = [
        SpendingTrend(
            month=f"{int(r.year):04d}-{int(r.month):02d}",
            total_amount=round(r.total, 2),
            transaction_count=r.count,
        )
        for r in rows
    ]
    return trend[-months:]


def get_monthly_summary(
    user_id: UUID,
    month: int,
    year: int,
    db: Session,
) -> MonthlySummary:
    """Full breakdown for a specific calendar month."""
    # Total + count
    row = (
        db.query(
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            extract("month", Transaction.transaction_date) == month,
            extract("year", Transaction.transaction_date) == year,
        )
        .first()
    )

    total = float(row.total or 0)
    count = int(row.count or 0)

    # Days in month for daily average
    import calendar
    days_in_month = calendar.monthrange(year, month)[1]
    avg_daily = round(total / days_in_month, 2)

    categories = get_category_breakdown(user_id, db, month=month, year=year)
    merchants = get_merchant_summary(user_id, db, limit=5)

    top_category = categories[0].category_name if categories else None
    top_merchant = merchants[0].merchant_name if merchants else None

    return MonthlySummary(
        month=f"{year:04d}-{month:02d}",
        total_spending=round(total, 2),
        transaction_count=count,
        avg_daily_spending=avg_daily,
        top_category=top_category,
        top_merchant=top_merchant,
        categories=categories,
    )


def get_analytics_summary(user_id: UUID, db: Session) -> AnalyticsSummary:
    """Dashboard-level summary: current vs previous month + alerts."""
    now = datetime.now(timezone.utc)
    curr_month, curr_year = now.month, now.year

    prev_month = curr_month - 1 if curr_month > 1 else 12
    prev_year = curr_year if curr_month > 1 else curr_year - 1

    def month_total(m: int, y: int) -> float:
        r = (
            db.query(func.sum(Transaction.amount))
            .filter(
                Transaction.user_id == user_id,
                Transaction.is_deleted == False,
                extract("month", Transaction.transaction_date) == m,
                extract("year", Transaction.transaction_date) == y,
            )
            .scalar()
        )
        return float(r or 0)

    curr_total = month_total(curr_month, curr_year)
    prev_total = month_total(prev_month, prev_year)

    change_pct = 0.0
    if prev_total > 0:
        change_pct = round((curr_total - prev_total) / prev_total * 100, 1)

    # All-time average monthly spending
    trend = get_spending_trend(user_id, db, months=12)
    avg_monthly = round(sum(t.total_amount for t in trend) / len(trend), 2) if trend else 0.0

    total_txn = _base_query(user_id, db).count()

    alerts = detect_unusual_spending(user_id, db)

    return AnalyticsSummary(
        current_month_spending=round(curr_total, 2),
        previous_month_spending=round(prev_total, 2),
        month_over_month_change_pct=change_pct,
        avg_monthly_spending=avg_monthly,
        total_transactions=total_txn,
        top_categories=get_category_breakdown(user_id, db, month=curr_month, year=curr_year)[:5],
        top_merchants=get_merchant_summary(user_id, db, limit=5),
        spending_trend=trend,
        unusual_spending_alerts=alerts,
    )
