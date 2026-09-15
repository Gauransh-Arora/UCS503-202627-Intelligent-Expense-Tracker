"""
Intelligence Service — unusual spending detection and wishlist purchase readiness.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.transaction import Transaction
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import ReadinessResponse


# ── Unusual Spending Detection ────────────────────────────────────────────────

def detect_unusual_spending(user_id: UUID, db: Session) -> list[str]:
    """
    Compare current month's per-category spending against the user's historical average.

    Returns a list of human-readable alert strings.
    Example: "⚠️ Shopping spending (₹8,500) is 4.2x your normal average (₹2,000)"
    """
    now = datetime.now(timezone.utc)
    curr_month, curr_year = now.month, now.year

    # Get category spending for each month in the last 6 months
    from app.models.category import Category

    rows = (
        db.query(
            Category.name,
            extract("year", Transaction.transaction_date).label("year"),
            extract("month", Transaction.transaction_date).label("month"),
            func.sum(Transaction.amount).label("total"),
        )
        .join(Category, Transaction.category_id == Category.id)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .group_by(Category.name, "year", "month")
        .all()
    )

    # Build {category: {(year,month): total}} map
    from collections import defaultdict
    cat_monthly: dict[str, dict[tuple, float]] = defaultdict(dict)
    for r in rows:
        cat_monthly[r.name][(int(r.year), int(r.month))] = float(r.total)

    alerts = []
    for cat_name, monthly_data in cat_monthly.items():
        curr_total = monthly_data.get((curr_year, curr_month), 0)
        if curr_total == 0:
            continue

        # Historical average (exclude current month)
        historical = [v for (y, m), v in monthly_data.items()
                      if (y, m) != (curr_year, curr_month)]

        if len(historical) < 2:
            continue

        avg = sum(historical) / len(historical)
        if avg == 0:
            continue

        ratio = curr_total / avg
        if ratio >= 2.0:
            alerts.append(
                f"⚠️ {cat_name} spending (₹{curr_total:,.0f}) is "
                f"{ratio:.1f}x your usual average (₹{avg:,.0f})"
            )

    return alerts


# ── Wishlist Purchase Readiness ───────────────────────────────────────────────

def compute_purchase_readiness(
    item: WishlistItem,
    user_id: UUID,
    db: Session,
) -> ReadinessResponse:
    """
    Analyse the user's financial situation to compute purchase readiness (0–100).

    Factors:
    - Average monthly spending (last 6 months)
    - Recurring expense burden
    - Discretionary budget estimate
    - Target item price
    """
    # Average monthly spending (last 6 months)
    from app.services.analytics_service import get_spending_trend
    trend = get_spending_trend(user_id, db, months=6)
    avg_monthly = sum(t.total_amount for t in trend) / len(trend) if trend else 0.0

    # Estimate recurring burden
    from app.services.recurring_service import get_recurring_expenses
    recurring = get_recurring_expenses(user_id, db)
    monthly_recurring = sum(
        r.average_amount for r in recurring
        if r.frequency.value == "monthly"
    )

    # Discretionary budget = 30% of spending above recurring costs
    discretionary = max(0, (avg_monthly - monthly_recurring) * 0.30)

    notes = []
    estimated_months: Optional[float] = None

    if avg_monthly == 0:
        readiness = 0.0
        notes.append("Not enough transaction history to compute readiness.")
    elif item.expected_price <= discretionary:
        readiness = 100.0
        notes.append("You can comfortably afford this right now!")
    else:
        if discretionary > 0:
            months_needed = item.expected_price / discretionary
            estimated_months = round(months_needed, 1)
            # Readiness decays the more months it takes (cap at 0)
            readiness = max(0, min(100, 100 / (1 + months_needed / 3)))
            notes.append(f"At your current savings rate, you could save for this in ~{estimated_months} months.")
        else:
            readiness = 0.0
            notes.append("Your current discretionary budget appears very limited.")

    if monthly_recurring > avg_monthly * 0.5:
        notes.append("⚠️ Recurring expenses are consuming over 50% of your budget.")

    # Persist readiness to DB
    item.purchase_readiness = round(readiness, 1)
    item.estimated_months = estimated_months
    db.commit()

    return ReadinessResponse(
        wishlist_item_id=item.id,
        name=item.name,
        expected_price=item.expected_price,
        purchase_readiness=round(readiness, 1),
        estimated_months=estimated_months,
        monthly_discretionary=round(discretionary, 2),
        avg_monthly_spending=round(avg_monthly, 2),
        analysis_notes=notes,
    )
