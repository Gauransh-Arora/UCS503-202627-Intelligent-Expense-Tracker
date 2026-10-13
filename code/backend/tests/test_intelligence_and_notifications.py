"""Tests for Module 6: Financial Intelligence & Auto Notifications."""
from datetime import date, datetime, timezone
import pytest

from app.models.category import Category
from app.models.recurring import Frequency, RecurringExpense
from app.models.transaction import Transaction
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import WishlistCreate
from app.services.intelligence_service import (
    add_wishlist_item,
    calculate_discretionary_budget,
    calculate_purchase_readiness,
    detect_recurring_expenses,
    detect_subscriptions,
    detect_unusual_spending,
    generate_purchase_verdict,
    get_wishlist_items,
)
from app.services.notification_service import (
    create_notification,
    generate_auto_notifications,
    get_notifications,
    get_unread_count,
    mark_all_as_read,
    mark_as_read,
)


def test_verdict_generation_logic():
    # 1. generate_purchase_verdict()
    v1 = generate_purchase_verdict(item_price=500.0, discretionary_budget=2000.0, readiness_score=85.0)
    assert v1 == "Comfortable"

    v2 = generate_purchase_verdict(item_price=3000.0, discretionary_budget=2000.0, readiness_score=55.0, estimated_months=1.5)
    assert v2 == "Possible"

    v3 = generate_purchase_verdict(item_price=50000.0, discretionary_budget=2000.0, readiness_score=10.0, estimated_months=25.0)
    assert v3 == "Not recommended currently"

    v4 = generate_purchase_verdict(item_price=100.0, discretionary_budget=0.0, readiness_score=0.0)
    assert v4 == "Not recommended currently"


def test_subscriptions_and_recurring(db_session, test_user):
    ent_cat = db_session.query(Category).filter(Category.name == "Entertainment").first()
    sub_cat = db_session.query(Category).filter(Category.name == "Subscriptions").first()

    # Pre-populate recurring expenses
    rec1 = RecurringExpense(
        user_id=test_user.id,
        merchant_name="Netflix",
        average_amount=649.0,
        frequency=Frequency.MONTHLY,
        confidence=95.0,
        typical_day=15,
        category_id=sub_cat.id if sub_cat else ent_cat.id,
        is_active=True,
    )
    rec2 = RecurringExpense(
        user_id=test_user.id,
        merchant_name="Spotify",
        average_amount=119.0,
        frequency=Frequency.MONTHLY,
        confidence=90.0,
        typical_day=20,
        category_id=sub_cat.id if sub_cat else ent_cat.id,
        is_active=True,
    )
    db_session.add_all([rec1, rec2])
    db_session.commit()

    # 2. detect_subscriptions()
    subs = detect_subscriptions(test_user.id, db_session)
    assert len(subs) >= 2
    sub_merchants = [s.merchant_name for s in subs]
    assert "Netflix" in sub_merchants
    assert "Spotify" in sub_merchants
    netflix = next(s for s in subs if s.merchant_name == "Netflix")
    assert netflix.monthly_amount == 649.0
    assert netflix.annual_amount == round(649.0 * 12, 2)


def test_wishlist_and_purchase_readiness(db_session, test_user):
    # Seed transactions for historical baseline
    food_cat = db_session.query(Category).filter(Category.name == "Food").first()
    for m in range(1, 4):
        db_session.add(
            Transaction(
                user_id=test_user.id,
                category_id=food_cat.id,
                merchant_name="Supermarket",
                amount=10000.0,
                transaction_date=date(2026, m, 1),
                payment_method="upi",
                is_verified=True,
            )
        )
    db_session.commit()

    # 3. calculate_discretionary_budget()
    budget = calculate_discretionary_budget(test_user.id, db_session)
    assert budget.avg_monthly_spending > 0
    assert budget.monthly_discretionary > 0

    # 4. add_wishlist_item() & get_wishlist_items()
    item_in = WishlistCreate(
        name="Noise Cancelling Headphones",
        expected_price=2500.0,
        priority="high",
        description="Sony WH-1000XM4",
    )
    item = add_wishlist_item(test_user.id, item_in, db_session)
    assert item.id is not None
    assert item.verdict in ("Comfortable", "Possible", "Not recommended currently")

    items_list = get_wishlist_items(test_user.id, db_session)
    assert len(items_list) == 1
    assert items_list[0].id == item.id

    # 5. calculate_purchase_readiness()
    readiness = calculate_purchase_readiness(item, test_user.id, db_session)
    assert readiness.wishlist_item_id == item.id
    assert readiness.verdict in ("Comfortable", "Possible", "Not recommended currently")
    assert len(readiness.analysis_notes) >= 1


def test_notifications_and_auto_generation(db_session, test_user, client, auth_headers):
    # 1. Manual notification CRUD
    n1 = create_notification(
        user_id=test_user.id,
        title="Welcome!",
        message="Your account is set up.",
        notification_type="system",
        db=db_session,
    )
    assert n1.id is not None
    assert get_unread_count(test_user.id, db_session) == 1

    notifs = get_notifications(test_user.id, db_session)
    assert len(notifs) == 1

    # Mark as read
    mark_as_read(n1.id, test_user.id, db_session)
    assert get_unread_count(test_user.id, db_session) == 0

    # 2. generate_auto_notifications()
    # Add an upcoming bill reminder condition
    sub_cat = db_session.query(Category).first()
    db_session.add(
        RecurringExpense(
            user_id=test_user.id,
            merchant_name="Electricity Board",
            average_amount=1200.0,
            frequency=Frequency.MONTHLY,
            typical_day=datetime.now(timezone.utc).day,  # due today!
            confidence=95.0,
            category_id=sub_cat.id,
            is_active=True,
        )
    )
    db_session.commit()

    auto_notifs = generate_auto_notifications(test_user.id, db_session)
    assert len(auto_notifs) >= 1
    assert any("Electricity Board" in a.message for a in auto_notifs)

    # API endpoints
    unread_res = client.get("/notifications/unread-count", headers=auth_headers)
    assert unread_res.status_code == 200
    assert unread_res.json()["unread_count"] >= 1

    trigger_res = client.post("/notifications/trigger-auto", headers=auth_headers)
    assert trigger_res.status_code == 200

    read_all_res = client.post("/notifications/read-all", headers=auth_headers)
    assert read_all_res.status_code == 200
    assert get_unread_count(test_user.id, db_session) == 0
