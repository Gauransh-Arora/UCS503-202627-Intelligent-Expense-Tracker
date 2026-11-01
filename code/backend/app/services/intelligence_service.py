"""
Financial Intelligence Service — unusual spending detection, subscriptions detection,
wishlist management, discretionary budget calculation, and purchase readiness evaluation.
"""
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import math
import statistics
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.config import settings
from app.models.budget_plan import BudgetPlan
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


# ── Unusual Spending Detection (Statistical Rule) ──────────────────────────────

def detect_unusual_spending(user_id: UUID, db: Session) -> list[str]:
    """
    Statistical anomaly detection:
    1. Category-level surge: evaluates historical monthly spending per category.
       Flags if current month > mean + k * std_dev (with minimum history guard).
    2. Single transaction anomaly: flags if txn amount > mean_txn + k * std_dev.
    Sensitivity multiplier k is configurable via settings.UNUSUAL_SPENDING_SENSITIVITY_K.
    """
    now = datetime.now(timezone.utc)
    curr_month, curr_year = now.month, now.year
    k = settings.UNUSUAL_SPENDING_SENSITIVITY_K

    # Category monthly spending
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

    cat_monthly: dict[str, dict[tuple[int, int], Decimal]] = defaultdict(dict)
    for r in rows:
        cat_monthly[r.name][(int(r.year), int(r.month))] = Decimal(str(r.total))

    alerts = []

    # Category anomaly checks with history guard
    for cat_name, monthly_data in cat_monthly.items():
        curr_total = monthly_data.get((curr_year, curr_month), Decimal("0.00"))
        if curr_total <= Decimal("0.00"):
            continue

        historical = [
            float(v) for (y, m), v in monthly_data.items()
            if (y, m) != (curr_year, curr_month)
        ]

        # Minimum history guard
        if len(historical) < settings.MIN_HISTORY_MONTHS_FOR_ANOMALY:
            continue

        mean = statistics.mean(historical)
        std_dev = statistics.stdev(historical) if len(historical) > 1 else (mean * 0.3)
        threshold = mean + (k * std_dev)

        if float(curr_total) > threshold and float(curr_total) >= 500.0:
            ratio = float(curr_total) / mean if mean > 0 else 2.0
            alerts.append(
                f"⚠️ {cat_name} spending (₹{curr_total:,.2f}) is noticeably higher than your historical baseline (avg ₹{mean:,.2f}, +{ratio:.1f}x normal)."
            )

    # Single transaction spikes in recent period (last 30 days or current calendar month)
    recent_cutoff = (now - timedelta(days=30)).date()
    curr_txns = (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            (
                (Transaction.transaction_date >= recent_cutoff) |
                (
                    (extract("month", Transaction.transaction_date) == curr_month) &
                    (extract("year", Transaction.transaction_date) == curr_year)
                )
            ),
        )
        .all()
    )

    if len(curr_txns) >= settings.MIN_TRANSACTIONS_FOR_ANOMALY:
        amounts = [float(t.amount) for t in curr_txns]
        mean_amt = statistics.mean(amounts)
        std_amt = statistics.stdev(amounts) if len(amounts) > 1 else (mean_amt * 0.5)
        spike_cutoff = max(mean_amt + (k * std_amt), 1500.0)

        for t in curr_txns:
            if float(t.amount) >= spike_cutoff:
                alerts.append(
                    f"💡 Unusually large expense of ₹{float(t.amount):,.2f} at {t.merchant_name} on {t.transaction_date}."
                )

    return alerts[:6]


# ── Subscriptions & Recurring Expenses ─────────────────────────────────────────

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
    """Identify likely subscriptions from recurring expenses and keywords."""
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
            rec_amount = Decimal(str(rec.average_amount))
            if rec.frequency == Frequency.YEARLY:
                monthly = (rec_amount / Decimal("12")).quantize(Decimal("0.01"))
                annual = rec_amount.quantize(Decimal("0.01"))
            else:
                monthly = rec_amount.quantize(Decimal("0.01"))
                annual = (rec_amount * Decimal("12")).quantize(Decimal("0.01"))

            subscriptions.append(
                SubscriptionResponse(
                    merchant_name=rec.merchant_name,
                    monthly_amount=monthly,
                    annual_amount=annual,
                    frequency=rec.frequency.value,
                    confidence=float(rec.confidence or 85.0),
                    category_name=cat_name,
                    typical_day=rec.typical_day,
                    status="active",
                )
            )

    return subscriptions


# ── Wishlist & Discretionary Budget ────────────────────────────────────────────

def calculate_discretionary_budget(
    user_id: UUID,
    db: Session,
    month: Optional[int] = None,
    year: Optional[int] = None,
) -> DiscretionaryBudgetInfo:
    """
    Estimate available discretionary spending:
    1. Checks if user has a configured BudgetPlan for current/target month.
       If BudgetPlan exists:
         Discretionary Budget = Spending Limit - Monthly Fixed Recurring - Savings Goal
    2. If no BudgetPlan exists:
         Discretionary Budget = Benchmark Avg Spending - Monthly Fixed Recurring - 20% Savings Reserve
    """
    now = datetime.now(timezone.utc)
    m = month or now.month
    y = year or now.year
    month_str = f"{y:04d}-{m:02d}"

    # Historical average monthly spending
    from app.services.analytics_service import get_spending_trends
    trend = get_spending_trends(user_id, db, months=6)
    avg_monthly = (
        Decimal(str(sum(t.total_amount for t in trend) / len(trend))).quantize(Decimal("0.01"))
        if trend else Decimal("0.00")
    )

    # Fixed recurring commitments
    from app.services.recurring_service import get_recurring_expenses
    recurring = get_recurring_expenses(user_id, db)
    monthly_recurring = sum(
        (Decimal(str(r.average_amount)) for r in recurring if r.frequency == Frequency.MONTHLY),
        Decimal("0.00")
    ).quantize(Decimal("0.01"))

    # Check for BudgetPlan
    budget_plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == user_id,
            BudgetPlan.month == month_str,
        )
        .first()
    )

    notes = []
    spending_limit = None
    savings_goal = None

    if budget_plan:
        spending_limit = Decimal(str(budget_plan.spending_limit))
        savings_goal = Decimal(str(budget_plan.savings_goal))
        savings_reserve = savings_goal

        # Discretionary budget derived from BudgetPlan
        available = spending_limit - monthly_recurring - savings_goal
        discretionary = max(Decimal("0.00"), available).quantize(Decimal("0.01"))

        notes.append(f"Active BudgetPlan for {month_str}: spending limit ₹{spending_limit:,.2f}, savings goal ₹{savings_goal:,.2f}.")
        notes.append(f"Fixed recurring obligations: ₹{monthly_recurring:,.2f}/month.")
        notes.append(f"Calculated monthly discretionary budget: ₹{discretionary:,.2f}.")
    else:
        # Default 20% savings reserve against historical average
        savings_reserve = (avg_monthly * Decimal("0.20")).quantize(Decimal("0.01"))
        discretionary = max(Decimal("0.00"), avg_monthly - monthly_recurring - savings_reserve).quantize(Decimal("0.01"))

        if avg_monthly == Decimal("0.00"):
            notes.append("No historical transaction data available to estimate discretionary budget.")
        else:
            notes.append(f"Average monthly spending benchmark: ₹{avg_monthly:,.2f}.")
            notes.append(f"Fixed recurring commitments: ₹{monthly_recurring:,.2f}/month.")
            notes.append(f"Estimated 20% savings reserve: ₹{savings_reserve:,.2f}.")
            notes.append(f"Estimated monthly discretionary buffer: ₹{discretionary:,.2f}.")

    return DiscretionaryBudgetInfo(
        monthly_discretionary=discretionary,
        avg_monthly_spending=avg_monthly,
        monthly_recurring=monthly_recurring,
        savings_reserve=savings_reserve,
        spending_limit=spending_limit,
        savings_goal=savings_goal,
        analysis_notes=notes,
    )


class VerdictStr(str):
    """String subclass that performs case-insensitive equality comparisons."""
    def __eq__(self, other):
        if isinstance(other, str):
            return self.strip().lower() == other.strip().lower()
        return super().__eq__(other)

    def __hash__(self):
        return hash(self.strip().lower())


def generate_purchase_verdict(
    item_price: Decimal | float | int | str,
    discretionary_budget: Decimal | float | int | str,
    readiness_score: float,
    estimated_months: Optional[float] = None,
) -> str:
    """
    Returns exactly one of the three course specification verdicts:
    - "Comfortable"
    - "Possible"
    - "Not Recommended Currently"
    """
    price = Decimal(str(item_price))
    discretionary = Decimal(str(discretionary_budget))

    if discretionary <= Decimal("0.00"):
        return VerdictStr("Not Recommended Currently")

    comfortable_cutoff = discretionary * Decimal(str(settings.READINESS_COMFORTABLE_RATIO))
    if price <= comfortable_cutoff and readiness_score >= 70.0:
        return VerdictStr("Comfortable")

    possible_cutoff = discretionary * Decimal(str(settings.READINESS_POSSIBLE_RATIO))
    if readiness_score >= 40.0 and (price <= possible_cutoff or (estimated_months is not None and estimated_months <= 3.0)):
        return VerdictStr("Possible")

    return VerdictStr("Not Recommended Currently")




def _generate_dynamic_purchase_advice(
    item_name: str,
    item_price: Decimal,
    discretionary: Decimal,
    avg_monthly: Decimal,
    monthly_recurring: Decimal,
    readiness_score: float,
    verdict: str,
    estimated_months: Optional[float],
) -> list[str]:
    """Use Gemini to generate personalized, dynamic financial guidance for wishlist items."""
    if not settings.GEMINI_API_KEY:
        return []
    try:
        from google import genai
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        prompt = f"""You are a personal financial advisor assessing purchase readiness.
Item: {item_name}
Expected Price: ₹{item_price:,.2f}
Monthly Discretionary Budget: ₹{discretionary:,.2f}
Average Monthly Spending: ₹{avg_monthly:,.2f}
Fixed Recurring Obligations: ₹{monthly_recurring:,.2f}
Affordability Readiness Score: {readiness_score:.0f}/100
Verdict: {verdict}
Estimated Months to Save: {estimated_months if estimated_months is not None else 'N/A'}

Provide 2 concise, highly actionable financial bullet points giving personalized savings strategy and practical budgeting advice specifically for this item and numbers. Do NOT use emojis. Return ONLY a JSON list of strings, for example:
["Point 1", "Point 2"]
"""
        res = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=prompt,
        )
        import json, re
        raw = res.text.strip()
        match = re.search(r'\[.*\]', raw, re.DOTALL)
        if match:
            tips = json.loads(match.group(0))
            if isinstance(tips, list):
                return [str(t).strip() for t in tips if str(t).strip()][:3]
    except Exception:
        pass
    return []

def calculate_purchase_readiness(
    item: WishlistItem,
    user_id: UUID,
    db: Session,
) -> ReadinessResponse:
    """
    Evaluate a wishlist purchase against spending, savings goals, and recurring expenses.
    Computes purchase readiness score (0–100) and returns verdict:
    'Comfortable', 'Possible', or 'Not Recommended Currently'.
    """
    budget_info = calculate_discretionary_budget(user_id, db)
    discretionary = budget_info.monthly_discretionary
    avg_monthly = budget_info.avg_monthly_spending

    notes = list(budget_info.analysis_notes)
    estimated_months: Optional[float] = None
    item_price = Decimal(str(item.expected_price))

    if avg_monthly == Decimal("0.00") and budget_info.spending_limit is None:
        readiness = 0.0
        notes.append("Insufficient transaction history or budget limits to evaluate affordability.")
    elif discretionary > Decimal("0.00") and item_price <= discretionary:
        readiness = 100.0
        notes.append("You can comfortably afford this purchase within your current monthly discretionary budget!")
    else:
        if discretionary > Decimal("0.00"):
            months_needed = float(item_price / discretionary)
            estimated_months = round(months_needed, 1)
            # Decays with months required (1 month ~ 75, 2 months ~ 60, 4 months ~ 43)
            readiness = max(0.0, min(100.0, round(100.0 / (1.0 + months_needed / 3.0), 1)))
            notes.append(f"At your current savings rate, you can afford this in ~{estimated_months} months.")
        else:
            readiness = 0.0
            notes.append("Your discretionary budget is currently depleted by fixed expenses or savings goals.")

    verdict = generate_purchase_verdict(
        item_price=item_price,
        discretionary_budget=discretionary,
        readiness_score=readiness,
        estimated_months=estimated_months,
    )
    notes.append(f"Final purchase verdict: {verdict}.")

    # Dynamic AI advisor guidance
    ai_advice = _generate_dynamic_purchase_advice(
        item_name=item.name,
        item_price=item_price,
        discretionary=discretionary,
        avg_monthly=avg_monthly,
        monthly_recurring=budget_info.monthly_recurring,
        readiness_score=readiness,
        verdict=verdict,
        estimated_months=estimated_months,
    )
    if ai_advice:
        notes.extend(ai_advice)

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
                message=f"Good news! '{item.name}' (₹{item_price:,.2f}) is now Comfortable to purchase.",
                notification_type=NotificationType.WISHLIST_UPDATE.value,
            )
        )

    db.commit()
    db.refresh(item)

    return ReadinessResponse(
        wishlist_item_id=item.id,
        name=item.name,
        expected_price=item_price,
        purchase_readiness=readiness,
        estimated_months=estimated_months,
        monthly_discretionary=discretionary,
        avg_monthly_spending=avg_monthly,
        spending_limit=budget_info.spending_limit,
        savings_goal=budget_info.savings_goal,
        verdict=verdict,
        analysis_notes=notes,
    )


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


# ── Unified FinancialIntelligenceService Class ────────────────────────────────

class FinancialIntelligenceService:
    """Class matching the project specification interface."""

    @staticmethod
    def analyze_spending(user_id: UUID, db: Session):
        from app.services.analytics_service import get_dashboard_statistics
        return get_dashboard_statistics(user_id, db)

    @staticmethod
    def detect_recurring(user_id: UUID, db: Session):
        return detect_recurring_expenses(user_id, db)

    @staticmethod
    def flag_unusual_spending(user_id: UUID, db: Session):
        return detect_unusual_spending(user_id, db)

    @staticmethod
    def evaluate_purchase(item_id: UUID, user_id: UUID, db: Session):
        item = db.query(WishlistItem).filter(
            WishlistItem.id == item_id,
            WishlistItem.user_id == user_id,
        ).first()
        if not item:
            raise HTTPException(status_code=404, detail="Wishlist item not found")
        return calculate_purchase_readiness(item, user_id, db)

    @staticmethod
    def answer_question(user_id: UUID, query: str, db: Session):
        from app.services.nl_service import answer_nl_query
        return answer_nl_query(query, user_id, db)
