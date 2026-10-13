"""Tests for Module 5: Spending analytics."""
from datetime import date
import pytest

from app.models.category import Category
from app.models.transaction import Transaction, TransactionItem
from app.services.analytics_service import (
    compare_monthly_spending,
    generate_spending_summary,
    get_category_wise_spending,
    get_dashboard_statistics,
    get_item_wise_spending,
    get_merchant_wise_spending,
    get_monthly_spending,
    get_spending_trends,
)


@pytest.fixture
def populated_transactions(db_session, test_user):
    """Seed transactions across two months with items and categories."""
    food_cat = db_session.query(Category).filter(Category.name == "Food").first()
    groceries_cat = db_session.query(Category).filter(Category.name == "Groceries").first()
    transport_cat = db_session.query(Category).filter(Category.name == "Transport").first()

    txns = [
        # August 2026 (Previous month)
        Transaction(
            user_id=test_user.id,
            category_id=food_cat.id,
            merchant_name="McDonald's",
            amount=600.0,
            transaction_date=date(2026, 8, 10),
            payment_method="upi",
            is_verified=True,
        ),
        Transaction(
            user_id=test_user.id,
            category_id=groceries_cat.id,
            merchant_name="BigBasket",
            amount=1400.0,
            transaction_date=date(2026, 8, 20),
            payment_method="card",
            is_verified=True,
        ),
        # September 2026 (Current month)
        Transaction(
            user_id=test_user.id,
            category_id=food_cat.id,
            merchant_name="Domino's Pizza",
            amount=800.0,
            transaction_date=date(2026, 9, 5),
            payment_method="upi",
            is_verified=True,
        ),
        Transaction(
            user_id=test_user.id,
            category_id=transport_cat.id,
            merchant_name="Uber",
            amount=500.0,
            transaction_date=date(2026, 9, 12),
            payment_method="upi",
            is_verified=True,
        ),
    ]
    db_session.add_all(txns)
    db_session.flush()

    # Add items to Domino's transaction
    dominos_tx = txns[2]
    items = [
        TransactionItem(
            transaction_id=dominos_tx.id,
            name="Farmhouse Pizza",
            quantity=2,
            unit_price=350.0,
            total_price=700.0,
        ),
        TransactionItem(
            transaction_id=dominos_tx.id,
            name="Garlic Bread",
            quantity=1,
            unit_price=100.0,
            total_price=100.0,
        ),
    ]
    db_session.add_all(items)
    db_session.commit()
    return txns


def test_category_and_merchant_wise_spending(db_session, test_user, populated_transactions):
    # 1. get_category_wise_spending()
    cat_spending = get_category_wise_spending(test_user.id, db_session, month=9, year=2026)
    assert len(cat_spending) == 2
    cat_names = [c.category_name for c in cat_spending]
    assert "Food" in cat_names
    assert "Transport" in cat_names

    # 2. get_merchant_wise_spending()
    merchants = get_merchant_wise_spending(test_user.id, db_session, limit=5)
    assert len(merchants) >= 3
    top_merchant = merchants[0]
    assert top_merchant.total_amount >= 500.0


def test_item_wise_spending(db_session, test_user, populated_transactions):
    # 3. get_item_wise_spending()
    items = get_item_wise_spending(test_user.id, db_session)
    assert len(items) == 2
    item_names = [i.item_name for i in items]
    assert "Farmhouse Pizza" in item_names
    pizza = next(i for i in items if i.item_name == "Farmhouse Pizza")
    assert pizza.total_amount == 700.0
    assert pizza.total_quantity == 2
    assert pizza.avg_unit_price == 350.0


def test_monthly_spending_and_trends(db_session, test_user, populated_transactions):
    # 4. get_monthly_spending()
    monthly = get_monthly_spending(test_user.id, 9, 2026, db_session)
    assert monthly.total_spending == 1300.0  # 800 + 500
    assert monthly.transaction_count == 2
    assert monthly.avg_daily_spending > 0

    # 5. get_spending_trends()
    trends = get_spending_trends(test_user.id, db_session, months=6)
    assert len(trends) >= 2
    months = [t.month for t in trends]
    assert "2026-08" in months
    assert "2026-09" in months


def test_compare_monthly_spending(db_session, test_user, populated_transactions):
    # 6. compare_monthly_spending()
    comp = compare_monthly_spending(
        test_user.id,
        db_session,
        current_month=9,
        current_year=2026,
        prev_month=8,
        prev_year=2026,
    )
    assert comp.current_total == 1300.0
    assert comp.previous_total == 2000.0  # 600 + 1400
    assert comp.difference_amount == -700.0
    assert comp.percentage_change == -35.0
    assert "decreased" in comp.verdict.lower()


def test_generate_spending_summary(db_session, test_user, populated_transactions):
    # 7. generate_spending_summary()
    summary = generate_spending_summary(test_user.id, db_session, month=9, year=2026)
    assert summary.total_spent == 1300.0
    assert summary.period == "September 2026"
    assert "September 2026" in summary.summary_text
    assert len(summary.key_insights) >= 2


def test_dashboard_statistics(db_session, test_user, populated_transactions, client, auth_headers):
    # 8. get_dashboard_statistics()
    stats = get_dashboard_statistics(test_user.id, db_session)
    assert stats.total_transactions == 4
    assert len(stats.spending_trend) >= 2

    # API test
    res = client.get("/analytics/dashboard", headers=auth_headers)
    assert res.status_code == 200
    assert "current_month_spending" in res.json()
