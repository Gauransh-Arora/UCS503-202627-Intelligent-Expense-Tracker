"""
Analytics Service — category, monthly, merchant, item-level breakdowns,
spending trends, monthly comparisons, spending summaries, and dashboard stats.
"""
import calendar
from datetime import date, datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.transaction import Transaction, TransactionItem
from app.schemas.analytics import (
    AnalyticsSummary,
    CategoryBreakdown,
    CategoryComparisonItem,
    ItemSpendingSummary,
    MerchantSummary,
    MonthlyComparison,
    MonthlySummary,
    SpendingSummaryResponse,
    SpendingTrend,
)
from app.services.intelligence_service import detect_unusual_spending


def _base_query(user_id: UUID, db: Session):
    """Base query for non-deleted transactions belonging to the user."""
    return db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )


def get_category_wise_spending(
    user_id: UUID,
    db: Session,
    month: Optional[int] = None,
    year: Optional[int] = None,
) -> list[CategoryBreakdown]:
    """Category-level breakdown of spending, optionally filtered by month/year."""
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


# Alias for backward compatibility
get_category_breakdown = get_category_wise_spending


def get_merchant_wise_spending(
    user_id: UUID,
    db: Session,
    limit: int = 10,
) -> list[MerchantSummary]:
    """Merchant-level analysis: top merchants by total spending."""
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


# Alias
get_merchant_summary = get_merchant_wise_spending


def get_item_wise_spending(
    user_id: UUID,
    db: Session,
    limit: int = 20,
) -> list[ItemSpendingSummary]:
    """Individual item analysis across all user transactions."""
    rows = (
        db.query(
            TransactionItem.name,
            func.sum(TransactionItem.total_price).label("total"),
            func.sum(TransactionItem.quantity).label("total_qty"),
            func.count(TransactionItem.id).label("count"),
        )
        .join(Transaction, TransactionItem.transaction_id == Transaction.id)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .group_by(TransactionItem.name)
        .order_by(func.sum(TransactionItem.total_price).desc())
        .limit(limit)
        .all()
    )

    result = []
    for r in rows:
        total = float(r.total or 0)
        qty = int(r.total_qty or 1)
        avg_price = round(total / max(1, qty), 2)
        result.append(
            ItemSpendingSummary(
                item_name=r.name,
                total_amount=round(total, 2),
                total_quantity=qty,
                avg_unit_price=avg_price,
                transaction_count=r.count,
            )
        )
    return result


def get_spending_trends(
    user_id: UUID,
    db: Session,
    months: int = 6,
) -> list[SpendingTrend]:
    """Historical monthly spending totals and transaction counts."""
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

    trend = [
        SpendingTrend(
            month=f"{int(r.year):04d}-{int(r.month):02d}",
            total_amount=round(r.total, 2),
            transaction_count=r.count,
        )
        for r in rows
    ]
    return trend[-months:]


# Alias
get_spending_trend = get_spending_trends


def get_monthly_spending(
    user_id: UUID,
    month: int,
    year: int,
    db: Session,
) -> MonthlySummary:
    """Monthly expense totals, daily average, and top dimensions."""
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

    total = float(row.total or 0) if row else 0.0
    count = int(row.count or 0) if row else 0

    days_in_month = calendar.monthrange(year, month)[1]
    avg_daily = round(total / days_in_month, 2)

    categories = get_category_wise_spending(user_id, db, month=month, year=year)
    merchants = get_merchant_wise_spending(user_id, db, limit=5)

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


# Alias
get_monthly_summary = get_monthly_spending


def compare_monthly_spending(
    user_id: UUID,
    db: Session,
    current_month: Optional[int] = None,
    current_year: Optional[int] = None,
    prev_month: Optional[int] = None,
    prev_year: Optional[int] = None,
) -> MonthlyComparison:
    """Compare current month's spending versus previous month."""
    now = datetime.now(timezone.utc)
    c_m = current_month or now.month
    c_y = current_year or now.year

    if prev_month and prev_year:
        p_m, p_y = prev_month, prev_year
    else:
        p_m = c_m - 1 if c_m > 1 else 12
        p_y = c_y if c_m > 1 else c_y - 1

    curr_summary = get_monthly_spending(user_id, c_m, c_y, db)
    prev_summary = get_monthly_spending(user_id, p_m, p_y, db)

    diff = round(curr_summary.total_spending - prev_summary.total_spending, 2)
    pct = 0.0
    if prev_summary.total_spending > 0:
        pct = round((diff / prev_summary.total_spending) * 100, 1)

    # Category comparisons
    curr_cats = {c.category_name: c.total_amount for c in curr_summary.categories}
    prev_cats = {c.category_name: c.total_amount for c in prev_summary.categories}
    all_cats = set(curr_cats.keys()) | set(prev_cats.keys())

    cat_items = []
    for cat in sorted(all_cats):
        c_amt = curr_cats.get(cat, 0.0)
        p_amt = prev_cats.get(cat, 0.0)
        c_diff = round(c_amt - p_amt, 2)
        c_pct = round((c_diff / p_amt * 100), 1) if p_amt > 0 else (100.0 if c_amt > 0 else 0.0)
        cat_items.append(
            CategoryComparisonItem(
                category_name=cat,
                current_amount=c_amt,
                previous_amount=p_amt,
                difference_amount=c_diff,
                percentage_change=c_pct,
            )
        )

    if diff > 0:
        verdict = f"Spending increased by ₹{abs(diff):,.2f} (+{pct}%) compared to last month."
    elif diff < 0:
        verdict = f"Great job! Spending decreased by ₹{abs(diff):,.2f} ({pct}%) compared to last month."
    else:
        verdict = "Spending remained exactly the same as last month."

    return MonthlyComparison(
        current_month=f"{c_y:04d}-{c_m:02d}",
        current_total=curr_summary.total_spending,
        current_count=curr_summary.transaction_count,
        previous_month=f"{p_y:04d}-{p_m:02d}",
        previous_total=prev_summary.total_spending,
        previous_count=prev_summary.transaction_count,
        difference_amount=diff,
        percentage_change=pct,
        verdict=verdict,
        category_comparison=cat_items,
    )


def generate_spending_summary(
    user_id: UUID,
    db: Session,
    month: Optional[int] = None,
    year: Optional[int] = None,
) -> SpendingSummaryResponse:
    """
    Generate “Where did my money go?” comprehensive financial summary.
    """
    now = datetime.now(timezone.utc)
    m = month or now.month
    y = year or now.year

    monthly = get_monthly_spending(user_id, m, y, db)
    merchants = get_merchant_wise_spending(user_id, db, limit=3)
    items = get_item_wise_spending(user_id, db, limit=3)
    comparison = compare_monthly_spending(user_id, db, current_month=m, current_year=y)

    month_name = calendar.month_name[m]
    insights = []

    if monthly.categories:
        top_cat = monthly.categories[0]
        insights.append(
            f"Your largest expense category was {top_cat.category_name} at ₹{top_cat.total_amount:,.2f} ({top_cat.percentage}% of total spending)."
        )

    if merchants:
        insights.append(
            f"You spent the most at {merchants[0].merchant_name} (₹{merchants[0].total_amount:,.2f} across {merchants[0].transaction_count} visits)."
        )

    if items:
        insights.append(
            f"Your most frequently purchased item was '{items[0].item_name}' (₹{items[0].total_amount:,.2f} total)."
        )

    insights.append(comparison.verdict)

    if monthly.total_spending == 0:
        summary_text = f"You haven't recorded any expenses for {month_name} {y}."
    else:
        summary_text = (
            f"In {month_name} {y}, you spent ₹{monthly.total_spending:,.2f} across "
            f"{monthly.transaction_count} transactions, averaging ₹{monthly.avg_daily_spending:,.2f} per day. "
            f"Your primary spending was in {monthly.top_category or 'various categories'}. "
            f"{comparison.verdict}"
        )

    return SpendingSummaryResponse(
        summary_text=summary_text,
        period=f"{month_name} {y}",
        total_spent=monthly.total_spending,
        transaction_count=monthly.transaction_count,
        top_category=monthly.top_category,
        top_merchant=monthly.top_merchant,
        key_insights=insights,
    )


def get_dashboard_statistics(user_id: UUID, db: Session) -> AnalyticsSummary:
    """Aggregated dashboard metrics."""
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

    trend = get_spending_trends(user_id, db, months=12)
    avg_monthly = round(sum(t.total_amount for t in trend) / len(trend), 2) if trend else 0.0

    total_txn = _base_query(user_id, db).count()
    alerts = detect_unusual_spending(user_id, db)

    return AnalyticsSummary(
        current_month_spending=round(curr_total, 2),
        previous_month_spending=round(prev_total, 2),
        month_over_month_change_pct=change_pct,
        avg_monthly_spending=avg_monthly,
        total_transactions=total_txn,
        top_categories=get_category_wise_spending(user_id, db, month=curr_month, year=curr_year)[:5],
        top_merchants=get_merchant_wise_spending(user_id, db, limit=5),
        spending_trend=trend,
        unusual_spending_alerts=alerts,
    )


# Alias
get_analytics_summary = get_dashboard_statistics
