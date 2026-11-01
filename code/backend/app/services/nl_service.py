"""
Natural Language Query Service — "Ask Your Expenses".

Converts natural language questions into safe, structured database queries
and returns direct, human-readable answers.

NO raw SQL is ever generated from user input.
All queries go through strict parameterised SQLAlchemy handlers scoped to the user.
Unsupported questions are refused honestly rather than hallucinated or guessed.
"""
from decimal import Decimal
from typing import Optional
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
    Identify time period from a natural language question.
    Returns (period_label, month, year).
    month = 0 means full year or all time.
    year = 0 means all time.
    """
    now = datetime.now(timezone.utc)
    q = question.lower()

    # Explicit 4-digit year like 2024, 2025, 2026
    year_match = re.search(r"\b(20\d\d)\b", q)
    explicit_year = int(year_match.group(1)) if year_match else None

    # Check for specific month names
    month_names = {
        "january": 1, "february": 2, "march": 3, "april": 4,
        "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    }
    for name, num in month_names.items():
        if re.search(rf"\b{name}\b", q):
            target_year = explicit_year if explicit_year else now.year
            return name.title(), num, target_year

    if "last month" in q or "previous month" in q or "prior month" in q:
        month = now.month - 1 if now.month > 1 else 12
        year = now.year if now.month > 1 else now.year - 1
        return "last month", month, year

    if "this month" in q or "current month" in q:
        return "this month", now.month, now.year

    if "last year" in q or "previous year" in q or "prior year" in q:
        return "last year", 0, now.year - 1

    if "this year" in q or "current year" in q:
        return "this year", 0, now.year

    if explicit_year:
        return str(explicit_year), 0, explicit_year

    if any(k in q for k in ["all time", "overall", "ever", "so far", "entire", "history"]):
        return "overall", 0, 0

    # Default to overall for open-ended queries (e.g. "where did most of my money go", "how much did I spend")
    return "overall", 0, 0


# ── Intent Classification ─────────────────────────────────────────────────────

_INTENTS = [
    ("spending_comparison", [
        r"compare.*(month|spending|expense)",
        r"how.*(differ|compare|change).*(last month|previous month)",
        r"(increase|decrease|more|less).*(than last month)",
    ]),
    ("spending_by_category", [
        r"how much.*(food|groceries|grocery|transport|shopping|entertainment|bills|healthcare|education|travel|rent|subscriptions|other)",
        r"(food|groceries|grocery|transport|shopping|entertainment|bills|healthcare|education|travel|rent|subscriptions).*(spend|spent|cost|expense)",
    ]),
    ("top_merchants", [
        r"(top|most|biggest|largest).*(merchant|shop|store|spend|expense)",
        r"where.*(most|all).*money",
        r"where.*spend.*most",
        r"where.*did.*money",
        r"where.*money.*go",
        r"who.*(did i pay|paid).*most",
    ]),
    ("recurring_expenses", [
        r"recurring",
        r"subscription",
        r"regular.*(bill|expense|payment)",
        r"monthly.*bill",
    ]),
    ("merchant_specific", [
        r"(?:how much|what).*(?:at|from|on|with)\s+([a-zA-Z0-9\s&'.]+)",
        r"(amazon|flipkart|swiggy|zomato|netflix|uber|ola|starbucks|domino|blinkit|zepto).*(spend|spent|expense)",
    ]),
    ("unusual_spending", [
        r"unusual|abnormal|spike|anomaly|strange.*(spend|expense)",
        r"why.*(more|higher).*(this month)",
    ]),
    ("transaction_count", [
        r"how many.*(transaction|expense|purchase|payment)",
        r"number of.*(transaction|expense)",
    ]),
    ("balances", [
        r"who owes|owe me|who do i owe|balance|split|debt|settle|lent|borrowed",
    ]),
    ("spending_total", [
        r"how much.*(spend|spent|total|overall)",
        r"total.*(spend|spending|expense)",
        r"what.*my.*(total|overall).*(spending|expense)",
    ]),
]


def _classify_with_llm(question: str) -> Optional[dict]:
    """Use Gemini to dynamically classify intent, merchant, category, and date parameters."""
    from app.config import settings
    if not settings.GEMINI_API_KEY:
        return None
    try:
        from google import genai
        import json
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        now = datetime.now(timezone.utc)
        prompt = f"""You are a financial query intent classifier for a personal expense tracking app.
Current date: {now.strftime('%Y-%m-%d')} (Current Year: {now.year}, Current Month: {now.month}).

Classify the question into exactly one allowed intent:
- spending_total: Total overall expenditure.
- spending_by_category: Spending on food, groceries, transport, shopping, entertainment, utilities/bills, health, education, travel, rent, subscriptions, etc.
- top_merchants: Where most money was spent, highest spend locations, or top merchants.
- recurring_expenses: Recurring bills or subscriptions.
- merchant_specific: Spending at a specific merchant/store/app (e.g. Starbucks, Zomato, Uber, cafe, etc.).
- unusual_spending: Abnormal spending, spikes, or anomalies.
- transaction_count: Number of transactions or payments made.
- balances: Debts, split balances, who owes whom.
- spending_comparison: Comparing spending against previous month or periods.
- unsupported: Stock picks/advice (e.g. Tesla, crypto, Bitcoin), investing predictions, general chat, or non-expense tracking queries.

Date parameter rules:
- If the question does NOT specify a month or year (e.g. "where did most of my money go", "how much did I spend", "where did all my money go"), leave both "month" and "year" as null.
- If the question refers to "this year" or "current year", set "year" to {now.year} and "month" to null.
- If the question refers to "last year", set "year" to {now.year - 1} and "month" to null.
- If the question refers to "this month", set "month" to {now.month} and "year" to {now.year}.
- If the question refers to "last month", set "month" to {now.month - 1 if now.month > 1 else 12} and "year" to {now.year if now.month > 1 else now.year - 1}.
- If a specific calendar year is mentioned (e.g. 2025), set "year" to that year.

Return ONLY a JSON object:
{{
  "intent": "<intent_name>",
  "category": "<category_name_or_null>",
  "merchant": "<merchant_name_or_null>",
  "month": <integer_month_1_to_12_or_null>,
  "year": <integer_year_or_null>
}}

User question: "{question}"
"""
        res = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=prompt,
        )
        raw = res.text.strip()
        match = re.search(r'\{.*\}', raw, re.DOTALL)
        if match:
            return json.loads(match.group(0))
    except Exception:
        pass
    return None

def _classify_intent(question: str) -> str:
    q = question.lower()
    for intent, patterns in _INTENTS:
        for pattern in patterns:
            if re.search(pattern, q):
                return intent
    return "unsupported"


# ── Structured Handlers ───────────────────────────────────────────────────────

def _handle_unsupported(question: str) -> NLQueryResponse:
    return NLQueryResponse(
        question=question,
        answer=(
            "I can't answer that yet. I can answer questions about your total spending, "
            "spending by category, merchant expenses, month-over-month comparisons, "
            "recurring subscriptions, unusual spending, and who owes you money."
        ),
        data={"supported": False},
        query_type="unsupported",
    )


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
    total = Decimal(str(total or "0.00"))
    count = int(count or 0)

    if count == 0 and (month or year):
        all_total, all_count = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        ).first()
        all_total = Decimal(str(all_total or "0.00"))
        all_count = int(all_count or 0)
        if all_count > 0:
            return NLQueryResponse(
                question="How much did I spend?",
                answer=f"No transactions found for {period}. Across all recorded expenses, you spent ₹{all_total:,.2f} across {all_count} transactions.",
                data={"total": 0.0, "transaction_count": 0, "all_time_total": float(all_total), "all_time_count": all_count},
                query_type="spending_total",
                period=period,
            )

    prefix = "overall" if period in ("overall", "all time") else f"in {period}"
    return NLQueryResponse(
        question="How much did I spend?",
        answer=f"You spent ₹{total:,.2f} across {count} transactions {prefix}.",
        data={"total": float(total), "transaction_count": count},
        query_type="spending_total",
        period=period,
    )


def _handle_spending_by_category(question: str, user_id: UUID, month: int, year: int, period: str, db: Session, category_hint: Optional[str] = None) -> NLQueryResponse:
    q_lower = question.lower()
    cat_name = category_hint.title() if category_hint else None
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
            answer=f"I couldn't find an expense category matching '{cat_name}'.",
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
    total = Decimal(str(total or "0.00"))
    count = int(count or 0)

    if count == 0 and (month or year):
        all_total, all_count = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
            Transaction.user_id == user_id,
            Transaction.category_id == cat.id,
            Transaction.is_deleted == False,
        ).first()
        all_total = Decimal(str(all_total or "0.00"))
        all_count = int(all_count or 0)
        if all_count > 0:
            return NLQueryResponse(
                question=question,
                answer=f"No {cat.name} spending recorded in {period}. Across all recorded expenses, you spent ₹{all_total:,.2f} on {cat.name} ({all_count} transactions).",
                data={"category": cat.name, "total": 0.0, "transaction_count": 0, "all_time_total": float(all_total), "all_time_count": all_count},
                query_type="spending_by_category",
                period=period,
            )

    prefix = "overall" if period in ("overall", "all time") else f"in {period}"
    return NLQueryResponse(
        question=question,
        answer=f"You spent ₹{total:,.2f} on {cat.name} ({count} transactions) {prefix}.",
        data={"category": cat.name, "total": float(total), "transaction_count": count},
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
        all_time_rows = db.query(
            Transaction.merchant_name,
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
        ).filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        ).group_by(Transaction.merchant_name).order_by(func.sum(Transaction.amount).desc()).limit(5).all()

        if not all_time_rows:
            return NLQueryResponse(
                question="Where did most of my money go?",
                answer="No transactions recorded yet. Once you record or import transactions, your top merchants will appear here.",
                query_type="top_merchants",
                period=period,
            )

        merchants_list = [{"merchant": r.merchant_name, "total": float(r.total), "count": r.count} for r in all_time_rows]
        lines = "\n".join(f"  {i+1}. {r['merchant']} — ₹{r['total']:,.2f}" for i, r in enumerate(merchants_list))
        period_str = f" in {period}" if period not in ("overall", "all time") else ""
        return NLQueryResponse(
            question="Where did most of my money go?",
            answer=f"No transactions found{period_str}. Here are your top merchants across all recorded expenses:\n{lines}",
            data={"merchants": merchants_list},
            query_type="top_merchants",
            period="overall",
        )

    merchants_list = [{"merchant": r.merchant_name, "total": float(r.total), "count": r.count} for r in rows]
    lines = "\n".join(f"  {i+1}. {r['merchant']} — ₹{r['total']:,.2f}" for i, r in enumerate(merchants_list))
    prefix = "overall" if period in ("overall", "all time") else f"in {period}"

    return NLQueryResponse(
        question="Where did most of my money go?",
        answer=f"Your top merchants {prefix}:\n{lines}",
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
            answer="No recurring expenses detected yet. As you record regular expenses, I will identify them.",
            query_type="recurring_expenses",
        )

    lines = "\n".join(
        f"  • {r.merchant_name} — ₹{float(r.average_amount):,.2f}/{r.frequency.value}"
        for r in recurring[:10]
    )
    total_monthly = sum(
        Decimal(str(r.average_amount)) for r in recurring if r.frequency.value == "monthly"
    )

    return NLQueryResponse(
        question="What are my recurring expenses?",
        answer=f"Your detected recurring expenses:\n{lines}\n\nEstimated monthly recurring total: ₹{total_monthly:,.2f}",
        data={"recurring": [{"merchant": r.merchant_name, "amount": float(r.average_amount), "frequency": r.frequency.value} for r in recurring]},
        query_type="recurring_expenses",
    )


def _handle_merchant_specific(question: str, user_id: UUID, month: int, year: int, period: str, db: Session, merchant_hint: Optional[str] = None) -> NLQueryResponse:
    merchant_name = merchant_hint.strip() if merchant_hint else None
    if not merchant_name:
        match = re.search(r"(?:at|from|on|with)\s+([a-zA-Z0-9\s&'.]+?)(?:\?|$|\s+last|\s+this|\s+in)", question, re.IGNORECASE)
        merchant_name = match.group(1).strip() if match else None

    if not merchant_name:
        for known in ["amazon", "flipkart", "swiggy", "zomato", "netflix", "uber", "ola", "starbucks", "domino", "blinkit", "zepto"]:
            if known in question.lower():
                merchant_name = known
                break

    if not merchant_name:
        return _handle_unsupported(question)

    q = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
        Transaction.merchant_name.ilike(f"%{merchant_name}%"),
    )
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)

    total, count = q.first()
    total = Decimal(str(total or "0.00"))
    count = int(count or 0)

    if count == 0 and (month or year):
        all_total, all_count = db.query(func.sum(Transaction.amount), func.count(Transaction.id)).filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            Transaction.merchant_name.ilike(f"%{merchant_name}%"),
        ).first()
        all_total = Decimal(str(all_total or "0.00"))
        all_count = int(all_count or 0)
        if all_count > 0:
            return NLQueryResponse(
                question=question,
                answer=f"No spending found at {merchant_name.title()} in {period}. Across all recorded expenses, you spent ₹{all_total:,.2f} across {all_count} transactions.",
                data={"merchant": merchant_name, "total": 0.0, "count": 0, "all_time_total": float(all_total), "all_time_count": all_count},
                query_type="merchant_specific",
                period=period,
            )

    prefix = "overall" if period in ("overall", "all time") else f"in {period}"
    return NLQueryResponse(
        question=question,
        answer=f"You spent ₹{total:,.2f} at {merchant_name.title()} across {count} transactions {prefix}.",
        data={"merchant": merchant_name, "total": float(total), "count": count},
        query_type="merchant_specific",
        period=period,
    )


def _handle_unusual(user_id: UUID, db: Session) -> NLQueryResponse:
    from app.services.intelligence_service import detect_unusual_spending
    alerts = detect_unusual_spending(user_id, db)

    if not alerts:
        return NLQueryResponse(
            question="Any unusual spending?",
            answer="Your spending is within your normal baseline range this month — no statistical anomalies detected.",
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

    if count == 0 and (month or year):
        all_count = db.query(func.count(Transaction.id)).filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        ).scalar() or 0
        if all_count > 0:
            return NLQueryResponse(
                question="How many transactions?",
                answer=f"No transactions found for {period}. You have {all_count} transactions recorded overall.",
                data={"count": 0, "all_time_count": all_count},
                query_type="transaction_count",
                period=period,
            )

    prefix = "overall" if period in ("overall", "all time") else f"in {period}"
    return NLQueryResponse(
        question="How many transactions?",
        answer=f"You recorded {count} transactions {prefix}.",
        data={"count": count},
        query_type="transaction_count",
        period=period,
    )


def _handle_balances(user_id: UUID, db: Session) -> NLQueryResponse:
    from app.services.split_service import calculate_user_balance
    bal = calculate_user_balance(user_id, db)

    if not bal.friend_balances:
        return NLQueryResponse(
            question="Who owes me money?",
            answer="All settled up! You have no outstanding split balances or debts.",
            data={"net_balance": 0.0, "friends": []},
            query_type="balances",
        )

    owed_lines = []
    owe_lines = []
    for f in bal.friend_balances:
        if f.total_owed_by_friend > f.total_settled_by_friend:
            remaining = f.total_owed_by_friend - f.total_settled_by_friend
            owed_lines.append(f"  • {f.friend_name} owes you ₹{remaining:,.2f}")
        if f.total_owed_by_user > f.total_settled_by_user:
            remaining = f.total_owed_by_user - f.total_settled_by_user
            owe_lines.append(f"  • You owe {f.friend_name} ₹{remaining:,.2f}")

    parts = []
    if owed_lines:
        parts.append("People who owe you:\n" + "\n".join(owed_lines))
    if owe_lines:
        parts.append("People you owe:\n" + "\n".join(owe_lines))
    if not parts:
        parts.append("All settled up! No outstanding balances.")

    parts.append(f"Net split balance: ₹{bal.net_balance:,.2f}")

    return NLQueryResponse(
        question="Who owes me money?",
        answer="\n\n".join(parts),
        data={
            "net_balance": float(bal.net_balance),
            "total_owed_to_user": float(bal.total_owed_to_user),
            "total_user_owes": float(bal.total_user_owes),
        },
        query_type="balances",
    )


def _handle_comparison(user_id: UUID, db: Session) -> NLQueryResponse:
    from app.services.analytics_service import compare_monthly_spending
    comp = compare_monthly_spending(user_id, db)

    return NLQueryResponse(
        question="Compare my spending to last month",
        answer=f"{comp.verdict} (Current: ₹{comp.current_total:,.2f} vs Previous: ₹{comp.previous_total:,.2f}).",
        data={
            "current_total": comp.current_total,
            "previous_total": comp.previous_total,
            "difference": comp.difference_amount,
            "percentage_change": comp.percentage_change,
        },
        query_type="spending_comparison",
    )


# ── Main Entry Point ──────────────────────────────────────────────────────────

def answer_nl_query(question: str, user_id: UUID, db: Session) -> NLQueryResponse:
    """
    Parse a natural-language question about expenses and return a structured answer.
    Unsupported questions are refused honestly.
    All data queries are parameterised and isolated strictly to user_id.
    """
    period, month, year = _extract_period(question)
    intent = _classify_intent(question)
    category_hint = None
    merchant_hint = None

    q_lower = question.lower()
    explicit_period_mentioned = any(k in q_lower for k in [
        "this month", "last month", "current month", "previous month", "prior month",
        "this year", "last year", "current year", "previous year", "prior year",
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
        "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
        "202"
    ])

    llm_info = _classify_with_llm(question)
    if llm_info and isinstance(llm_info, dict):
        llm_intent = llm_info.get("intent")
        if llm_intent and llm_intent != "unsupported":
            intent = llm_intent
        elif llm_intent == "unsupported":
            intent = "unsupported"

        # Only let LLM specify month/year if regex didn't find an explicit time period
        if not explicit_period_mentioned:
            if llm_info.get("month"):
                month = int(llm_info["month"])
            if llm_info.get("year"):
                year = int(llm_info["year"])
            if month and year:
                period = f"{month}/{year}"
            elif year:
                period = str(year)
            elif month:
                period = f"month {month}"
            else:
                period = "overall"
                month = 0
                year = 0

        category_hint = llm_info.get("category")
        merchant_hint = llm_info.get("merchant")

    if intent == "unsupported":
        return _handle_unsupported(question)

    handlers = {
        "spending_total": lambda: _handle_spending_total(user_id, month, year, period, db),
        "spending_by_category": lambda: _handle_spending_by_category(question, user_id, month, year, period, db, category_hint=category_hint),
        "top_merchants": lambda: _handle_top_merchants(user_id, month, year, period, db),
        "recurring_expenses": lambda: _handle_recurring(user_id, db),
        "merchant_specific": lambda: _handle_merchant_specific(question, user_id, month, year, period, db, merchant_hint=merchant_hint),
        "unusual_spending": lambda: _handle_unusual(user_id, db),
        "transaction_count": lambda: _handle_transaction_count(user_id, month, year, period, db),
        "balances": lambda: _handle_balances(user_id, db),
        "spending_comparison": lambda: _handle_comparison(user_id, db),
    }

    handler = handlers.get(intent)
    if handler:
        return handler()
    return _handle_unsupported(question)


def process_natural_language_query(user_id: UUID, question: str, db: Session) -> NLQueryResponse:
    """Alternative signature helper matching FinancialIntelligenceService.answerQuestion."""
    return answer_nl_query(question=question, user_id=user_id, db=db)
