"""
Recurring Expense Detection Service.

Scans the user's transaction history and detects patterns where the same
merchant appears at regular intervals (monthly, weekly, etc.).
"""
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.recurring import Frequency, RecurringExpense
from app.models.transaction import Transaction


def detect_recurring_expenses(user_id: UUID, db: Session) -> list[dict]:
    """
    Analyse transaction history and detect recurring spending patterns.

    Algorithm:
    1. Group all non-deleted transactions by merchant name
    2. For merchants with ≥3 transactions, analyse date gaps
    3. If gaps are consistent (std_dev < 5 days for monthly), mark as recurring
    4. Save detected patterns to recurring_expenses table

    Returns list of detected recurring expense dicts.
    """
    # Fetch all user transactions
    transactions = (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .order_by(Transaction.transaction_date)
        .all()
    )

    # Group by merchant name (case-insensitive)
    by_merchant: dict[str, list[Transaction]] = defaultdict(list)
    for tx in transactions:
        by_merchant[tx.merchant_name.lower().strip()].append(tx)

    detected = []

    for merchant_key, txns in by_merchant.items():
        if len(txns) < 3:
            continue

        dates = [t.transaction_date for t in txns]
        amounts = [t.amount for t in txns]

        gaps_days = [
            (dates[i + 1] - dates[i]).days
            for i in range(len(dates) - 1)
        ]

        avg_gap = sum(gaps_days) / len(gaps_days)
        avg_amount = sum(amounts) / len(amounts)

        # Determine frequency and confidence
        frequency, confidence = _classify_frequency(avg_gap, gaps_days)
        if frequency is None or confidence < 50:
            continue

        # Check if already in DB
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
            "frequency": frequency,
            "confidence": confidence,
            "transaction_count": len(txns),
        })

    return detected


def _classify_frequency(avg_gap: float, gaps: list[int]) -> tuple[Frequency | None, float]:
    """
    Classify the frequency of a recurring expense and estimate confidence.

    Returns (Frequency, confidence_0_to_100) or (None, 0) if not recurring.
    """
    import statistics

    if len(gaps) < 2:
        return None, 0

    std = statistics.stdev(gaps) if len(gaps) > 1 else 0

    if 25 <= avg_gap <= 35:  # ~monthly
        confidence = max(0, 100 - std * 5)
        return Frequency.MONTHLY, round(confidence)

    if 6 <= avg_gap <= 8:  # ~weekly
        confidence = max(0, 100 - std * 10)
        return Frequency.WEEKLY, round(confidence)

    if 1 <= avg_gap <= 2:  # ~daily
        confidence = max(0, 100 - std * 20)
        return Frequency.DAILY, round(confidence)

    if 85 <= avg_gap <= 95:  # ~quarterly
        confidence = max(0, 100 - std * 3)
        return Frequency.QUARTERLY, round(confidence)

    if 350 <= avg_gap <= 380:  # ~yearly
        confidence = max(0, 100 - std * 2)
        return Frequency.YEARLY, round(confidence)

    return None, 0


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
