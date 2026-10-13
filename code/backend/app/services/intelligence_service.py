"""
Financial Intelligence Service — unusual spending detection, subscriptions detection,
wishlist management, discretionary budget calculation, and purchase readiness evaluation.
"""
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.notification import Notification, NotificationType
from app.models.recurring import Frequency, RecurringExpense
from app.models.transaction import Transaction
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import (
    DiscretionaryBudgetInfo,
    ReadinessResponse,
    SubscriptionResponse,
    WishlistCreate,
    WishlistUpdate,
)


# ── Unusual Spending Detection ────────────────────────────────────────────────

def detect_unusual_spending(user_id: UUID, db: Session) -> list[str]:
    """
    Flag spending that deviates noticeably from historical patterns:
    1. Category-level surge: spending is ≥ 2x historical average.
    2. Single transaction anomaly: transaction amount is > 3x average transaction.
    """
    now = datetime.now(timezone.utc)
    curr_month, curr_year = now.month, now.year

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

    cat_monthly: dict[str, dict[tuple, float]] = defaultdict(dict)
    for r in rows:
        cat_monthly[r.name][(int(r.year), int(r.month))] = float(r.total)

    alerts = []
    for cat_name, monthly_data in cat_monthly.items():
        curr_total = monthly_data.get((curr_year, curr_month), 0.0)
        if curr_total == 0:
            continue

        historical = [v for (y, m), v in monthly_data.items() if (y, m) != (curr_year, curr_month)]
        if len(historical) < 1:
            continue

        avg = sum(historical) / len(historical)
        if avg > 0:
            ratio = curr_total / avg
            if ratio >= 1.8:
                alerts.append(
                    f"⚠️ {cat_name} spending (₹{curr_total:,.0f}) is {ratio:.1f}x your usual average (₹{avg:,.0f})"
                )

    # Check for single spike transactions this month
    curr_txns = (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            extract("month", Transaction.transaction_date) == curr_month,
            extract("year", Transaction.transaction_date) == curr_year,
        )
        .all()
    )

    if curr_txns:
        avg_amt = sum(t.amount for t in curr_txns) / len(curr_txns)
        for t in curr_txns:
            if t.amount >= 3.0 * avg_amt and t.amount >= 1500:
                alerts.append(
                    f"💡 Unusually large expense of ₹{t.amount:,.0f} at {t.merchant_name} on {t.transaction_date}."
                )

    return alerts[:6]


# ── Subscriptions & Recurring Expenses ───────────────────────────────────────

SUBSCRIPTION_KEYWORDS = {
    "netflix", "spotify", "prime", "amazon prime", "disney", "hotstar",
    "apple", "icloud", "chatgpt", "openai", "youtube", "google one",
    "gym", "cult.fit", "fitness", "broadband", "wifi", "jio fiber", "airtel xtream",
    "dropbox", "notion", "github", "coursera", "udemy", "linkedin"
}


def detect_recurring_expenses(user_id: UUID, db: Session) -> list[dict]:
    """Identify recurring payments across historical transactions."""
    from app.services.recurring_service import detect_recurring_expenses as _detect_rec
    return _detect_rec(user_id, db)


def detect_subscriptions(user_id: UUID, db: Session) -> list[SubscriptionResponse]:
    """
    Identify likely subscriptions:
    1. Recurring expenses matching subscription services or categories
    2. Repeated identical charges under entertainment, bills, or subscription keywords
    """
    # First, run recurring detection so DB is fresh
    from app.services.recurring_service import detect_recurring_expenses as _detect_rec, get_recurring_expenses
    _detect_rec(user_id, db)
    recurring = get_recurring_expenses(user_id, db)

    subscriptions: list[SubscriptionResponse] = []
    seen_merchants = set()

    for rec in recurring:
        m_lower = rec.merchant_name.lower().strip()
        cat_name = rec.category.name if rec.category else "Subscriptions"

        is_sub = (
            any(kw in m_lower for kw in SUBSCRIPTION_KEYWORDS) or
            cat_name.lower() in ("subscriptions", "entertainment", "bills") or
            rec.frequency in (Frequency.MONTHLY, Frequency.YEARLY)
        )

        if is_sub and m_lower not in seen_merchants:
            seen_merchants.add(m_lower)
            if rec.frequency == Frequency.YEARLY:
                monthly = round(rec.average_amount / 12, 2)
                annual = round(rec.average_amount, 2)
            else:
                monthly = round(rec.average_amount, 2)
                annual = round(rec.average_amount * 12, 2)

            subscriptions.append(
                SubscriptionResponse(
                    merchant_name=rec.merchant_name,
                    monthly_amount=monthly,
                    annual_amount=annual,
                    frequency=rec.frequency.value,
                    confidence=rec.confidence or 85.0,
                    category_name=cat_name,
                    typical_day=rec.typical_day,
                    status="active",
                )
            )

    return subscriptions


# ── Wishlist & Discretionary Budget ──────────────────────────────────────────

def calculate_discretionary_budget(
    user_id: UUID,
    db: Session,
    month: Optional[int] = None,
    year: Optional[int] = None,
) -> DiscretionaryBudgetInfo:
    """
    Estimate available discretionary spending:
    Discretionary Budget = Monthly Spending Benchmark - Fixed Recurring Obligations - Savings Reserve (20%)
    """
    from app.services.analytics_service import get_spending_trends
    trend = get_spending_trends(user_id, db, months=6)
    avg_monthly = sum(t.total_amount for t in trend) / len(trend) if trend else 0.0

    # Fixed recurring commitments
    from app.services.recurring_service import get_recurring_expenses
    recurring = get_recurring_expenses(user_id, db)
    monthly_recurring = sum(
        r.average_amount for r in recurring
        if r.frequency == Frequency.MONTHLY
    )

    # 20% savings reserve
    savings_reserve = round(avg_monthly * 0.20, 2)

    # Available discretionary room
    discretionary = max(0.0, avg_monthly - monthly_recurring - savings_reserve)

    notes = []
    if avg_monthly == 0:
        notes.append("No historical transaction data available to estimate discretionary budget.")
    else:
        notes.append(f"Average monthly spending benchmark: ₹{avg_monthly:,.2f}.")
        notes.append(f"Fixed recurring commitments: ₹{monthly_recurring:,.2f}/month.")
        notes.append(f"Recommended 20% savings reserve: ₹{savings_reserve:,.2f}.")
        notes.append(f"Estimated available discretionary buffer: ₹{discretionary:,.2f}/month.")

    return DiscretionaryBudgetInfo(
        monthly_discretionary=round(discretionary, 2),
        avg_monthly_spending=round(avg_monthly, 2),
        monthly_recurring=round(monthly_recurring, 2),
        savings_reserve=savings_reserve,
        analysis_notes=notes,
    )


def generate_purchase_verdict(
    item_price: float,
    discretionary_budget: float,
    readiness_score: float,
    estimated_months: Optional[float] = None,
) -> str:
    """
    Return strictly:
    - "Comfortable"
    - "Possible"
    - "Not recommended currently"
    """
    if discretionary_budget <= 0:
        return "Not recommended currently"

    if item_price <= discretionary_budget and readiness_score >= 70:
        return "Comfortable"

    if item_price <= discretionary_budget * 2.5 or (estimated_months is not None and estimated_months <= 3.0):
        return "Possible"

    return "Not recommended currently"


def calculate_purchase_readiness(
    item: WishlistItem,
    user_id: UUID,
    db: Session,
) -> ReadinessResponse:
    """
    Evaluate a purchase against spending, savings goals, and recurring expenses.
    Computes purchase readiness score (0–100) and returns verdict:
    Comfortable, Possible, or Not recommended currently.
    """
    budget_info = calculate_discretionary_budget(user_id, db)
    discretionary = budget_info.monthly_discretionary
    avg_monthly = budget_info.avg_monthly_spending

    notes = list(budget_info.analysis_notes)
    estimated_months: Optional[float] = None

    if avg_monthly == 0:
        readiness = 0.0
        notes.append("Insufficient transaction history to evaluate affordability.")
    elif item.expected_price <= discretionary:
        readiness = 100.0
        notes.append("You can comfortably afford this purchase within your current monthly discretionary budget!")
    else:
        if discretionary > 0:
            months_needed = item.expected_price / discretionary
            estimated_months = round(months_needed, 1)
            # Decays with months required (1 month ~ 75, 2 months ~ 60, 4 months ~ 43)
            readiness = max(0.0, min(100.0, round(100.0 / (1.0 + months_needed / 3.0), 1)))
            notes.append(f"At your current savings rate, you can afford this in ~{estimated_months} months.")
        else:
            readiness = 0.0
            notes.append("Your discretionary budget is currently depleted by fixed expenses.")

    verdict = generate_purchase_verdict(
        item_price=item.expected_price,
        discretionary_budget=discretionary,
        readiness_score=readiness,
        estimated_months=estimated_months,
    )
    notes.append(f"Final purchase verdict: {verdict}.")

    # Persist readiness & verdict to item
    item.purchase_readiness = readiness
    item.estimated_months = estimated_months
    item.verdict = verdict
    item.discretionary_budget = discretionary

    # Trigger notification if comfortable
    if verdict == "Comfortable" and not item.is_purchased:
        db.add(
            Notification(
                user_id=user_id,
                title=f"Wishlist Ready: {item.name}",
                message=f"Good news! '{item.name}' (₹{item.expected_price:,.2f}) is now Comfortable to purchase.",
                notification_type=NotificationType.WISHLIST_UPDATE.value,
            )
        )

    db.commit()
    db.refresh(item)

    return ReadinessResponse(
        wishlist_item_id=item.id,
        name=item.name,
        expected_price=item.expected_price,
        purchase_readiness=readiness,
        estimated_months=estimated_months,
        monthly_discretionary=discretionary,
        avg_monthly_spending=avg_monthly,
        verdict=verdict,
        analysis_notes=notes,
    )


# Alias
compute_purchase_readiness = calculate_purchase_readiness


def add_wishlist_item(
    user_id: UUID,
    item_in: WishlistCreate,
    db: Session,
) -> WishlistItem:
    """Save a planned purchase to wishlist and evaluate initial purchase readiness."""
    item = WishlistItem(
        user_id=user_id,
        name=item_in.name,
        expected_price=item_in.expected_price,
        currency=item_in.currency,
        description=item_in.description,
        priority=item_in.priority,
        url=item_in.url,
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    # Evaluate readiness
    calculate_purchase_readiness(item, user_id, db)
    return item


def get_wishlist_items(
    user_id: UUID,
    db: Session,
) -> list[WishlistItem]:
    """Retrieve wishlist entries for user."""
    return (
        db.query(WishlistItem)
        .filter(WishlistItem.user_id == user_id)
        .order_by(WishlistItem.created_at.desc())
        .all()
    )


def update_wishlist_item(
    item_id: UUID,
    user_id: UUID,
    item_update: WishlistUpdate,
    db: Session,
) -> WishlistItem:
    """Update wishlist item details and re-evaluate readiness."""
    item = db.query(WishlistItem).filter(
        WishlistItem.id == item_id,
        WishlistItem.user_id == user_id,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wishlist item not found")

    for field, value in item_update.model_dump(exclude_unset=True).items():
        setattr(item, field, value)

    db.commit()
    db.refresh(item)

    calculate_purchase_readiness(item, user_id, db)
    return item


def delete_wishlist_item(
    item_id: UUID,
    user_id: UUID,
    db: Session,
) -> bool:
    """Remove item from wishlist."""
    item = db.query(WishlistItem).filter(
        WishlistItem.id == item_id,
        WishlistItem.user_id == user_id,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wishlist item not found")

    db.delete(item)
    db.commit()
    return True
