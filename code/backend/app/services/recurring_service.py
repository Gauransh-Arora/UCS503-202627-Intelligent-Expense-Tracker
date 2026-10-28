"""
Recurring Expense Detection Service.

Scans the user's transaction history and detects recurring spending patterns
(subscriptions, utilities, rent, daily/weekly/monthly payments).
Uses configurable interval and amount tolerances from application settings.
"""
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal
import statistics
from uuid import UUID

from sqlalchemy.orm import Session

from app.config import settings
from app.models.recurring import Frequency, RecurringExpense
from app.models.transaction import Transaction


def detect_recurring_expenses(user_id: UUID, db: Session) -> list[dict]:
    """
    Analyse transaction history and detect recurring spending patterns.
    Uses configurable interval tolerance and amount tolerance from Settings.
    """
    transactions = (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .order_by(Transaction.transaction_date)
        .all()
    )

    by_merchant: dict[str, list[Transaction]] = defaultdict(list)
    for tx in transactions:
        by_merchant[tx.merchant_name.lower().strip()].append(tx)

    detected = []

    for merchant_key, txns in by_merchant.items():
        if len(txns) < 3:
            continue

        dates = [t.transaction_date for t in txns]
        amounts = [float(t.amount) for t in txns]

        gaps_days = [
            (dates[i + 1] - dates[i]).days
            for i in range(len(dates) - 1)
        ]

        avg_gap = sum(gaps_days) / len(gaps_days)
        avg_amount = sum(amounts) / len(amounts)

        # Check amount drift against tolerance
        amount_drift = max(abs(a - avg_amount) / avg_amount for a in amounts) if avg_amount > 0 else 0
        if amount_drift > (settings.RECURRING_AMOUNT_TOLERANCE_PCT * 2.0):
            # Amount varies too wildly to be regular recurring payment
            continue

        frequency, confidence = _classify_frequency(avg_gap, gaps_days, amount_drift)
        if frequency is None or confidence < 50:
            continue

        existing = db.query(RecurringExpense).filter(
            RecurringExpense.user_id == user_id,
            RecurringExpense.merchant_name.ilike(f"%{txns[0].merchant_name}%"),
        ).first()

        if not existing:
            rec = RecurringExpense(
                user_id=user_id,
                category_id=txns[-1].category_id,
                merchant_name=txns[0].merchant_name,
                average_amount=round(avg_amount, 2),
                frequency=frequency,
                typical_day=dates[-1].day if frequency == Frequency.MONTHLY else None,
                confidence=confidence,
                is_user_confirmed=False,
                is_active=True,
            )
            db.add(rec)
            db.commit()
            db.refresh(rec)

        detected.append({
            "merchant_name": txns[0].merchant_name,
            "average_amount": round(avg_amount, 2),
            "frequency": frequency.value if hasattr(frequency, "value") else str(frequency),
            "confidence": confidence,
            "transaction_count": len(txns),
        })

    return detected


def _classify_frequency(avg_gap: float, gaps: list[int], amount_drift: float = 0.0) -> tuple[Frequency | None, float]:
    """
    Classify frequency with configurable interval tolerance.
    Returns (Frequency, confidence_0_to_100).
    """
    if len(gaps) < 2:
        return None, 0.0

    std = statistics.stdev(gaps) if len(gaps) > 1 else 0
    tol = settings.RECURRING_INTERVAL_TOLERANCE_DAYS

    # Base penalty from amount drift
    drift_penalty = min(25.0, amount_drift * 100.0)

    # Monthly (~30 days ± tol)
    if (30 - tol * 2) <= avg_gap <= (30 + tol * 2):
        confidence = max(50.0, 100.0 - (std * 3) - drift_penalty)
        return Frequency.MONTHLY, round(confidence, 1)

    # Weekly (~7 days ± tol)
    if (7 - tol) <= avg_gap <= (7 + tol):
        confidence = max(50.0, 100.0 - (std * 6) - drift_penalty)
        return Frequency.WEEKLY, round(confidence, 1)

    # Daily (~1-2 days)
    if 1 <= avg_gap <= 2:
        confidence = max(50.0, 100.0 - (std * 15) - drift_penalty)
        return Frequency.DAILY, round(confidence, 1)

    # Quarterly (~90 days ± tol*3)
    if (90 - tol * 3) <= avg_gap <= (90 + tol * 3):
        confidence = max(50.0, 100.0 - (std * 2) - drift_penalty)
        return Frequency.QUARTERLY, round(confidence, 1)

    # Yearly (~365 days ± tol*5)
    if (365 - tol * 5) <= avg_gap <= (365 + tol * 5):
        confidence = max(50.0, 100.0 - std - drift_penalty)
        return Frequency.YEARLY, round(confidence, 1)

    return None, 0.0


def get_recurring_expenses(user_id: UUID, db: Session) -> list[RecurringExpense]:
    """Return all active recurring expenses for the user."""
    return (
        db.query(RecurringExpense)
        .filter(
            RecurringExpense.user_id == user_id,
            RecurringExpense.is_active == True,
        )
        .order_by(RecurringExpense.average_amount.desc())
        .all()
    )
