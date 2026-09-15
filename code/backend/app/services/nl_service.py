"""
Natural Language Query Service — "Ask Your Expenses".

Converts natural language questions into safe, structured database queries
and returns human-readable answers.

NO raw SQL is ever generated from user input.
All queries go through a strict intent → handler mapping.
"""
import re
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.transaction import Transaction
from app.schemas.ai import NLQueryResponse


# ── Period extraction ─────────────────────────────────────────────────────────

def _extract_period(question: str) -> tuple[str, int, int]:
    """
    Identify the time period from a natural language question.

    Returns (period_label, month, year) for month-based queries.
    Falls back to current month.
    """
    now = datetime.now(timezone.utc)
    q = question.lower()

    if "last month" in q or "previous month" in q:
        month = now.month - 1 if now.month > 1 else 12
        year = now.year if now.month > 1 else now.year - 1
        return "last_month", month, year

    if "this month" in q or "current month" in q:
        return "this_month", now.month, now.year

    if "this year" in q or "current year" in q:
        return "this_year", 0, now.year  # month=0 means full year

    # Try to detect month names: "in September", "last September"
    month_names = {
        "january": 1, "february": 2, "march": 3, "april": 4,
        "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
    }
    for name, num in month_names.items():
        if name in q:
            return name, num, now.year

    # Default: current month
    return "this_month", now.month, now.year


# ── Intent classification ─────────────────────────────────────────────────────

_INTENTS = [
    ("spending_by_category", [
        r"how much.*(food|groceries|transport|shopping|entertainment|bills|healthcare|education|travel|rent|subscriptions)",
        r"(food|grocery|transport|shopping|entertainment|bill|health|education|travel|rent|subscription).*(spend|spent|cost)",
    ]),
    ("spending_total", [
        r"how much.*(spend|spent|total|overall)",
        r"total.*(spend|spending|expense)",
        r"what.*my.*(total|overall)",
    ]),
    ("top_merchants", [
        r"(top|most|biggest|largest).*(merchant|shop|store|spend|expense)",
        r"where.*most.*money",
        r"where.*spend.*most",
    ]),
    ("recurring_expenses", [
        r"recurring",
        r"subscription",
        r"monthly.*bill",
        r"regular.*expense",
    ]),
    ("merchant_specific", [
        r"how much.*(at|from|on)\s+(\w+)",
        r"(amazon|flipkart|swiggy|zomato|netflix|uber|ola)\s+spend",
    ]),
    ("unusual_spending", [
        r"unusual|abnormal|spike|increase|why.*more",
    ]),
    ("transaction_count", [
        r"how many.*(transaction|expense|purchase|time)",
        r"number of.*(transaction|expense)",
    ]),
]


def _classify_intent(question: str) -> str:
    q = question.lower()
    for intent, patterns in _INTENTS:
        for pattern in patterns:
            if re.search(pattern, q):
                return intent
    return "spending_total"  # safe default


# ── Query handlers ────────────────────────────────────────────────────────────

def _handle_spending_total(user_id: UUID, month: int, year: int, period: str, db: Session) -> NLQueryResponse:
    q = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    total, count = q.first()
    total = float(total or 0)
    count = int(count or 0)

    period_label = period.replace("_", " ")
    return NLQueryResponse(
        question="How much did I spend?",
        answer=f"You spent ₹{total:,.2f} across {count} transactions {period_label}.",
        data={"total": total, "transaction_count": count},
        query_type="spending_total",
        period=period,
    )


def _handle_spending_by_category(question: str, user_id: UUID, month: int, year: int, period: str, db: Session) -> NLQueryResponse:
    # Extract category name from question
    q_lower = question.lower()
    cat_name = None
    for name in ["food", "groceries", "transport", "shopping", "entertainment",
                 "bills", "healthcare", "education", "travel", "rent", "subscriptions", "other"]:
        if name in q_lower:
            cat_name = name.title()
            break

    if not cat_name:
        return _handle_spending_total(user_id, month, year, period, db)

    cat = db.query(Category).filter(Category.name.ilike(cat_name)).first()
    if not cat:
        return NLQueryResponse(
            question=question,
            answer=f"I couldn't find a category matching '{cat_name}'.",
            query_type="spending_by_category",
            period=period,
        )

    q = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
        Transaction.user_id == user_id,
        Transaction.category_id == cat.id,
        Transaction.is_deleted == False,
    )
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    total, count = q.first()
    total = float(total or 0)
    count = int(count or 0)
    period_label = period.replace("_", " ")

    return NLQueryResponse(
        question=question,
        answer=f"You spent ₹{total:,.2f} on {cat_name} ({count} transactions) {period_label}.",
        data={"category": cat_name, "total": total, "transaction_count": count},
        query_type="spending_by_category",
        period=period,
    )


def _handle_top_merchants(user_id: UUID, month: int, year: int, period: str, db: Session) -> NLQueryResponse:
    q = db.query(
        Transaction.merchant_name,
        func.sum(Transaction.amount).label("total"),
        func.count(Transaction.id).label("count"),
    ).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    rows = q.group_by(Transaction.merchant_name).order_by(func.sum(Transaction.amount).desc()).limit(5).all()
    if not rows:
        return NLQueryResponse(
            question="Where did most of my money go?",
            answer="No transactions found for the selected period.",
            query_type="top_merchants",
            period=period,
        )

    merchants_list = [{"merchant": r.merchant_name, "total": float(r.total), "count": r.count} for r in rows]
    lines = "\n".join(f"  {i+1}. {r['merchant']} — ₹{r['total']:,.2f}" for i, r in enumerate(merchants_list))
    period_label = period.replace("_", " ")

    return NLQueryResponse(
        question="Where did most of my money go?",
        answer=f"Your top merchants {period_label}:\n{lines}",
        data={"merchants": merchants_list},
        query_type="top_merchants",
        period=period,
    )


def _handle_recurring(user_id: UUID, db: Session) -> NLQueryResponse:
    from app.services.recurring_service import get_recurring_expenses
    recurring = get_recurring_expenses(user_id, db)

    if not recurring:
        return NLQueryResponse(
            question="What are my recurring expenses?",
            answer="No recurring expenses detected yet. Add more transactions so I can learn your patterns.",
            query_type="recurring_expenses",
        )

    lines = "\n".join(
        f"  • {r.merchant_name} — ₹{r.average_amount:,.0f}/{r.frequency.value}"
        for r in recurring[:10]
    )
    total = sum(r.average_amount for r in recurring if r.frequency.value == "monthly")

    return NLQueryResponse(
        question="What are my recurring expenses?",
        answer=f"Your recurring expenses:\n{lines}\n\nEstimated monthly burden: ₹{total:,.0f}",
        data={"recurring": [{"merchant": r.merchant_name, "amount": r.average_amount, "frequency": r.frequency.value} for r in recurring]},
        query_type="recurring_expenses",
    )


def _handle_merchant_specific(question: str, user_id: UUID, month: int, year: int, period: str, db: Session) -> NLQueryResponse:
    # Extract merchant name from question (after "at", "from", "on")
    match = re.search(r"(?:at|from|on)\s+([a-zA-Z0-9\s]+?)(?:\?|$|\s+last|\s+this|\s+in)", question, re.IGNORECASE)
    merchant_name = match.group(1).strip() if match else None

    if not merchant_name:
        return _handle_spending_total(user_id, month, year, period, db)

    q = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
        Transaction.merchant_name.ilike(f"%{merchant_name}%"),
    )
    total, count = q.first()
    total = float(total or 0)
    count = int(count or 0)

    return NLQueryResponse(
        question=question,
        answer=f"You've spent ₹{total:,.2f} at {merchant_name.title()} across {count} transactions (all time).",
        data={"merchant": merchant_name, "total": total, "count": count},
        query_type="merchant_specific",
        period="all_time",
    )


def _handle_unusual(user_id: UUID, db: Session) -> NLQueryResponse:
    from app.services.intelligence_service import detect_unusual_spending
    alerts = detect_unusual_spending(user_id, db)

    if not alerts:
        return NLQueryResponse(
            question="Any unusual spending?",
            answer="Your spending looks normal this month — no significant spikes detected.",
            query_type="unusual_spending",
        )

    return NLQueryResponse(
        question="Any unusual spending?",
        answer="\n".join(alerts),
        data={"alerts": alerts},
        query_type="unusual_spending",
    )


def _handle_transaction_count(user_id: UUID, month: int, year: int, period: str, db: Session) -> NLQueryResponse:
    q = db.query(func.count(Transaction.id)).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    count = q.scalar() or 0
    period_label = period.replace("_", " ")

    return NLQueryResponse(
        question="How many transactions?",
        answer=f"You made {count} transactions {period_label}.",
        data={"count": count},
        query_type="transaction_count",
        period=period,
    )


# ── Main entry point ──────────────────────────────────────────────────────────

def answer_nl_query(question: str, user_id: UUID, db: Session) -> NLQueryResponse:
    """
    Parse a natural-language question about expenses and return a structured answer.

    All database access is through pre-validated, parameterised SQLAlchemy queries.
    No arbitrary SQL is ever constructed from user input.
    """
    intent = _classify_intent(question)
    period, month, year = _extract_period(question)

    handlers = {
        "spending_total": lambda: _handle_spending_total(user_id, month, year, period, db),
        "spending_by_category": lambda: _handle_spending_by_category(question, user_id, month, year, period, db),
        "top_merchants": lambda: _handle_top_merchants(user_id, month, year, period, db),
        "recurring_expenses": lambda: _handle_recurring(user_id, db),
        "merchant_specific": lambda: _handle_merchant_specific(question, user_id, month, year, period, db),
        "unusual_spending": lambda: _handle_unusual(user_id, db),
        "transaction_count": lambda: _handle_transaction_count(user_id, month, year, period, db),
    }

    handler = handlers.get(intent, handlers["spending_total"])
    return handler()
