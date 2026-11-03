"""
Recurring Expense Detection Service.

Scans the user's transaction history and detects recurring spending patterns
(subscriptions, utilities, rent, daily/weekly/monthly payments).
Uses configurable interval and amount tolerances from application settings.
"""
import calendar
from collections import defaultdict
from datetime import date as dt_date, datetime, timedelta, timezone
from decimal import Decimal
import statistics
from uuid import UUID

from sqlalchemy.orm import Session

from app.config import settings
from app.models.recurring import Frequency, RecurringExpense
from app.models.transaction import Transaction


def _compute_next_expected_date(
    frequency: Frequency,
    last_date: dt_date | None = None,
    typical_day: int | None = None,
) -> dt_date:
    """Project the next upcoming due date based on frequency and cadence."""
    today = datetime.now(timezone.utc).date()
    if frequency == Frequency.MONTHLY:
        day = typical_day or (last_date.day if last_date else today.day)
        _, last_day_this_month = calendar.monthrange(today.year, today.month)
        cand_day = min(day, last_day_this_month)
        candidate = dt_date(today.year, today.month, cand_day)
        if candidate >= today:
            return candidate
        year = today.year if today.month < 12 else today.year + 1
        month = today.month + 1 if today.month < 12 else 1
        _, last_day_next_month = calendar.monthrange(year, month)
        return dt_date(year, month, min(day, last_day_next_month))
    elif frequency == Frequency.WEEKLY:
        if last_date:
            cur = last_date
            while cur < today:
                cur += timedelta(days=7)
            return cur
        return today + timedelta(days=7)
    elif frequency == Frequency.DAILY:
        return today + timedelta(days=1)
    elif frequency == Frequency.YEARLY:
        if last_date:
            year = today.year if (today.month, today.day) <= (last_date.month, last_date.day) else today.year + 1
            _, last_day = calendar.monthrange(year, last_date.month)
            return dt_date(year, last_date.month, min(last_date.day, last_day))
        return today + timedelta(days=365)
    elif frequency == Frequency.QUARTERLY:
        return today + timedelta(days=90)
    return today


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

    detected: list[dict] = []

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
        else:
            rec = existing

        cat_name = (
            txns[-1].category.name
            if (txns[-1].category and hasattr(txns[-1].category, "name"))
            else (rec.category.name if (rec.category and hasattr(rec.category, "name")) else None)
        )
        next_exp = _compute_next_expected_date(frequency, dates[-1], getattr(rec, "typical_day", None))
        freq_str = frequency.value if hasattr(frequency, "value") else str(frequency)
        amt = round(avg_amount, 2)

        monthly_amt = amt
        if freq_str == "yearly":
            monthly_amt = round(amt / 12, 2)
        elif freq_str == "weekly":
            monthly_amt = round(amt * 4.33, 2)
        elif freq_str == "daily":
            monthly_amt = round(amt * 30, 2)
        elif freq_str == "quarterly":
            monthly_amt = round(amt / 3, 2)

        detected.append({
            "merchant_name": txns[0].merchant_name,
            "amount": amt,
            "average_amount": amt,
            "typical_amount": amt,
            "monthly_amount": monthly_amt,
            "frequency": freq_str,
            "confidence": confidence,
            "transaction_count": len(txns),
            "occurrences": len(txns),
            "count": len(txns),
            "category": cat_name,
            "category_name": cat_name,
            "next_expected_date": next_exp.isoformat() if next_exp else None,
            "next_expected": next_exp.isoformat() if next_exp else None,
            "typical_day": getattr(rec, "typical_day", None),
        })

    # Include existing active RecurringExpense records that are already in the DB
    detected_merchants = {d["merchant_name"].lower().strip() for d in detected}
    all_recurring = get_recurring_expenses(user_id, db)
    for rec in all_recurring:
        m_lower = rec.merchant_name.lower().strip()
        if m_lower not in detected_merchants:
            detected_merchants.add(m_lower)
            cat_name = rec.category.name if rec.category else None
            next_exp = _compute_next_expected_date(rec.frequency, None, rec.typical_day)
            avg_amt = float(rec.average_amount)
            freq_str = rec.frequency.value if hasattr(rec.frequency, "value") else str(rec.frequency)
            monthly_amt = avg_amt
            if freq_str == "yearly":
                monthly_amt = round(avg_amt / 12, 2)
            elif freq_str == "weekly":
                monthly_amt = round(avg_amt * 4.33, 2)
            elif freq_str == "daily":
                monthly_amt = round(avg_amt * 30, 2)
            elif freq_str == "quarterly":
                monthly_amt = round(avg_amt / 3, 2)

            detected.append({
                "merchant_name": rec.merchant_name,
                "amount": avg_amt,
                "average_amount": avg_amt,
                "typical_amount": avg_amt,
                "monthly_amount": monthly_amt,
                "frequency": freq_str,
                "confidence": float(rec.confidence or 80.0),
                "transaction_count": 1,
                "occurrences": 1,
                "count": 1,
                "category": cat_name,
                "category_name": cat_name,
                "next_expected_date": next_exp.isoformat() if next_exp else None,
                "next_expected": next_exp.isoformat() if next_exp else None,
                "typical_day": rec.typical_day,
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
