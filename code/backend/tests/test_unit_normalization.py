"""
Unit Tests for Normalization, Categorization Feedback, Splits, Intelligence & Duplicate Detection.
"""
from datetime import date, datetime, timedelta
from decimal import Decimal
import pytest

from app.models.category import Category
from app.models.split import SplitType
from app.models.transaction import Transaction, TransactionStatus
from app.models.user import User
from app.services.analytics_service import get_spending_drilldown
from app.services.bank_statement_service import mark_duplicates
from app.services.categorization_service import (
    categorize_transaction,
    learn_user_category_preference,
)
from app.services.extraction_service import (
    normalize_amount_str,
    normalize_date,
)
from app.services.intelligence_service import (
    FinancialIntelligenceService,
    detect_unusual_spending,
    generate_purchase_verdict,
)
from app.services.nl_service import process_natural_language_query
from app.services.split_service import (
    calculate_custom_split,
    calculate_equal_split,
    calculate_percentage_split,
)


# ── 1. Amount & Date Normalization ──────────────────────────────────────────

def test_amount_normalization_variants():
    """Test diverse currency symbols, comma grouping, and European notation."""
    assert normalize_amount_str("₹1,234.50") == Decimal("1234.50")
    assert normalize_amount_str("Rs. 1234") == Decimal("1234.00")
    assert normalize_amount_str("Rs 1234.75") == Decimal("1234.75")
    assert normalize_amount_str("INR 1,23,456.00") == Decimal("123456.00")
    assert normalize_amount_str("1.234,50") == Decimal("1234.50")
    assert normalize_amount_str("450") == Decimal("450.00")
    assert normalize_amount_str("   $ 99.99  ") == Decimal("99.99")
    assert normalize_amount_str("invalid") is None
    assert normalize_amount_str("") is None


def test_date_normalization_variants():
    """Test ISO, UK/Indian day-first, abbreviated month, and concatenated dates."""
    assert normalize_date("Transaction on 2026-03-05 at 14:00") == "2026-03-05"
    assert normalize_date("Dated 05/03/2026") == "2026-03-05"
    assert normalize_date("Paid 5 Mar 2026") == "2026-03-05"
    assert normalize_date("Bill date 05-Mar-26") == "2026-03-05"
    assert normalize_date("14Oct2026,1:18pm") == "2026-10-14"
    assert normalize_date("10 September 2026, 12:28pm") == "2026-09-10"
    assert normalize_date("No date here") is None


# ── 2. Categorization & User Override Feedback ──────────────────────────────

def test_categorization_and_user_learning(db_session, test_user):
    """Test keyword rules and user feedback override precedence."""
    # Default rule: Starbucks -> Food
    cat1, conf1 = categorize_transaction("Starbucks Coffee", db=db_session)
    assert cat1 == "Food"
    assert conf1 > 0.7

    # User correction: User re-categorizes Starbucks as "Work & Business"
    work_cat = Category(name="Work & Business", icon="work", is_default=False)
    db_session.add(work_cat)
    db_session.commit()

    learn_user_category_preference(
        user_id=test_user.id,
        merchant_name="Starbucks",
        category_name="Work & Business",
        db=db_session,
    )

    # For this user, override must take precedence!
    user_cat, user_conf = categorize_transaction(
        merchant_name="Starbucks Coffee",
        user_id=test_user.id,
        db=db_session,
    )
    assert user_cat == "Work & Business"
    assert user_conf == 1.0

    # For another user, global rule remains intact
    other_cat, _ = categorize_transaction(
        merchant_name="Starbucks Coffee",
        user_id=None,
        db=db_session,
    )
    assert other_cat == "Food"


# ── 3. Split Calculators & Exact Sum-to-Total ─────────────────────────────────

def test_split_calculators_rounding_and_validation():
    """Test exact penny reconciliation and rejection of invalid shares."""
    # 1. Equal Split: 100 split 3 ways -> 33.33 + 33.33 + 33.34 = 100.00
    parts = [
        {"participant_name": "A", "is_payer": True},
        {"participant_name": "B", "is_payer": False},
        {"participant_name": "C", "is_payer": False},
    ]
    eq = calculate_equal_split(100.00, parts)
    assert sum(p["amount_owed"] for p in eq) == Decimal("100.00")
    assert eq[0]["amount_owed"] == 33.33
    assert eq[2]["amount_owed"] == 33.34

    # 2. Percentage Split
    pct_parts = [
        {"participant_name": "A", "percentage": 33.33, "is_payer": True},
        {"participant_name": "B", "percentage": 33.33, "is_payer": False},
        {"participant_name": "C", "percentage": 33.34, "is_payer": False},
    ]
    pct = calculate_percentage_split(100.00, pct_parts)
    assert sum(p["amount_owed"] for p in pct) == Decimal("100.00")

    # Invalid percentage sum must raise ValueError
    with pytest.raises(ValueError):
        calculate_percentage_split(100.00, [
            {"participant_name": "A", "percentage": 50.0},
            {"participant_name": "B", "percentage": 40.0},
        ])

    # 3. Custom Split
    custom_parts = [
        {"participant_name": "A", "amount_owed": 40.50},
        {"participant_name": "B", "amount_owed": 59.50},
    ]
    cust = calculate_custom_split(100.00, custom_parts)
    assert sum(p["amount_owed"] for p in cust) == Decimal("100.00")

    # Mismatched custom sum must raise ValueError
    with pytest.raises(ValueError):
        calculate_custom_split(100.00, [
            {"participant_name": "A", "amount_owed": 40.00},
            {"participant_name": "B", "amount_owed": 50.00},
        ])


# ── 4. Statistical Unusual Spending & Minimum History Guard ───────────────────

def test_statistical_unusual_spending_guard(db_session, test_user):
    """Test that unusual spending requires sufficient history and flags statistically large outliers."""
    # With only 2 transactions, minimum history guard suppresses false positive alerts
    cat = db_session.query(Category).first()
    t1 = Transaction(
        user_id=test_user.id,
        category_id=cat.id,
        merchant_name="Shop",
        amount=Decimal("100.00"),
        transaction_date=date.today() - timedelta(days=5),
        status=TransactionStatus.CONFIRMED.value,
        is_verified=True,
    )
    t2 = Transaction(
        user_id=test_user.id,
        category_id=cat.id,
        merchant_name="Shop",
        amount=Decimal("120.00"),
        transaction_date=date.today() - timedelta(days=4),
        status=TransactionStatus.CONFIRMED.value,
        is_verified=True,
    )
    db_session.add_all([t1, t2])
    db_session.commit()

    # Guard suppresses alerts when history < minimum required sample
    alerts_low_sample = detect_unusual_spending(test_user.id, db_session)
    assert len(alerts_low_sample) == 0

    # Add more normal history (around 100-120)
    for i in range(5):
        db_session.add(
            Transaction(
                user_id=test_user.id,
                category_id=cat.id,
                merchant_name="Shop",
                amount=Decimal("110.00"),
                transaction_date=date.today() - timedelta(days=10 + i),
                status=TransactionStatus.CONFIRMED.value,
                is_verified=True,
            )
        )
    # Add an extreme statistical outlier (3000 vs mean 110)
    outlier = Transaction(
        user_id=test_user.id,
        category_id=cat.id,
        merchant_name="Luxury Boutique",
        amount=Decimal("3500.00"),
        transaction_date=date.today() - timedelta(days=1),
        status=TransactionStatus.CONFIRMED.value,
        is_verified=True,
    )
    db_session.add(outlier)
    db_session.commit()

    alerts = detect_unusual_spending(test_user.id, db_session)
    assert len(alerts) >= 1
    assert any("Luxury Boutique" in a or "3,500" in a for a in alerts)


# ── 5. Purchase Readiness Boundary Verdicts ───────────────────────────────────

def test_purchase_readiness_boundaries():
    """Test boundary conditions for Comfortable, Possible, and Not Recommended verdicts."""
    # Discretionary budget: 10,000
    # Comfortable cutoff: price <= 30% of budget (3,000) with high score
    assert generate_purchase_verdict(item_price=2500, discretionary_budget=10000, readiness_score=85) == "Comfortable"

    # Possible cutoff: price between 30% and 80% (or high savings score / short horizon)
    assert generate_purchase_verdict(item_price=6000, discretionary_budget=10000, readiness_score=60) == "Possible"
    assert generate_purchase_verdict(item_price=12000, discretionary_budget=10000, readiness_score=65, estimated_months=2.0) == "Possible"

    # Not Recommended: price exceeds budget or negative discretionary
    assert generate_purchase_verdict(item_price=25000, discretionary_budget=10000, readiness_score=20, estimated_months=12.0) == "Not Recommended Currently"
    assert generate_purchase_verdict(item_price=500, discretionary_budget=0, readiness_score=0) == "Not Recommended Currently"


# ── 6. NLQ Intent Mapping & Honest Refusal ────────────────────────────────────

def test_nlq_safe_mapping_and_honest_refusal(db_session, test_user):
    """Test safe structured query execution and refusal of out-of-scope questions."""
    cat = db_session.query(Category).first()
    db_session.add(
        Transaction(
            user_id=test_user.id,
            category_id=cat.id,
            merchant_name="Subway",
            amount=Decimal("250.00"),
            transaction_date=date.today(),
            status=TransactionStatus.CONFIRMED.value,
            is_verified=True,
        )
    )
    db_session.commit()

    # Supported: total spending
    res1 = process_natural_language_query(test_user.id, "How much did I spend this month?", db_session)
    assert res1.success is True
    assert "₹" in res1.answer

    # Supported: category query
    res2 = process_natural_language_query(test_user.id, f"How much did I spend on {cat.name}?", db_session)
    assert res2.success is True
    assert cat.name in res2.answer

    # Unsupported: stock advice / random question -> honest refusal
    res3 = process_natural_language_query(test_user.id, "Should I invest in Tesla stock or Bitcoin?", db_session)
    assert res3.success is False
    assert "I can't answer that yet" in res3.answer


# ── 7. Bank Statement Duplicate Detection ─────────────────────────────────────

def test_duplicate_detection_logic(db_session, test_user):
    """Test flagging duplicates within statement file and against existing confirmed history."""
    cat = db_session.query(Category).first()
    # Add an existing confirmed transaction
    existing = Transaction(
        user_id=test_user.id,
        category_id=cat.id,
        merchant_name="Blue Tokai Coffee",
        amount=Decimal("450.00"),
        transaction_date=date(2026, 10, 15),
        status=TransactionStatus.CONFIRMED.value,
        is_verified=True,
    )
    db_session.add(existing)
    db_session.commit()

    rows = [
        # Matches existing transaction (same date, same amount, same merchant)
        {
            "date": "2026-10-15",
            "description": "UPI/628994/Blue Tokai Coffee/HDFC",
            "merchant": "Blue Tokai Coffee",
            "debit": 450.00,
            "credit": None,
            "is_duplicate": False,
        },
        # New transaction
        {
            "date": "2026-10-16",
            "description": "Swiggy Order #48192",
            "merchant": "Swiggy",
            "debit": 320.00,
            "credit": None,
            "is_duplicate": False,
        },
        # Duplicate of previous row inside the file
        {
            "date": "2026-10-16",
            "description": "Swiggy Order #48192",
            "merchant": "Swiggy",
            "debit": 320.00,
            "credit": None,
            "is_duplicate": False,
        },
    ]

    checked_rows = mark_duplicates(test_user.id, rows, db_session)
    assert checked_rows[0]["is_duplicate"] is True
    assert "existing transaction" in checked_rows[0]["duplicate_reason"].lower()

    assert checked_rows[1]["is_duplicate"] is False

    assert checked_rows[2]["is_duplicate"] is True
    assert "within statement file" in checked_rows[2]["duplicate_reason"].lower()
