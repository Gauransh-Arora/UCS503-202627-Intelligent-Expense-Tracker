"""Tests for Module 4: Collaborative expense splitting & friends."""
import pytest
from app.models.split import SplitType
from app.schemas.split import (
    FriendCreate,
    ParticipantCreate,
    SettlementCreate,
    SplitCreate,
)
from app.services.friend_service import add_friend, delete_friend, get_friend_ledger, get_friends
from app.services.split_service import (
    calculate_custom_split,
    calculate_equal_split,
    calculate_percentage_split,
    calculate_user_balance,
    create_expense_split,
    get_settlement_history,
    record_settlement,
)


def test_split_calculation_algorithms():
    # 1. calculate_equal_split()
    parts = [
        {"participant_name": "Alice", "is_payer": True},
        {"participant_name": "Bob", "is_payer": False},
        {"participant_name": "Charlie", "is_payer": False},
    ]
    equal_res = calculate_equal_split(100.0, parts)
    assert len(equal_res) == 3
    # 33.33 + 33.33 + 33.34 = 100.0
    assert sum(p["amount_owed"] for p in equal_res) == 100.0
    assert equal_res[0]["amount_owed"] == 33.33
    assert equal_res[2]["amount_owed"] == 33.34

    # 2. calculate_percentage_split()
    pct_parts = [
        {"participant_name": "Alice", "percentage": 50.0, "is_payer": True},
        {"participant_name": "Bob", "percentage": 30.0, "is_payer": False},
        {"participant_name": "Charlie", "percentage": 20.0, "is_payer": False},
    ]
    pct_res = calculate_percentage_split(500.0, pct_parts)
    assert pct_res[0]["amount_owed"] == 250.0
    assert pct_res[1]["amount_owed"] == 150.0
    assert pct_res[2]["amount_owed"] == 100.0

    # 3. calculate_custom_split()
    custom_parts = [
        {"participant_name": "Alice", "amount_owed": 120.0, "is_payer": True},
        {"participant_name": "Bob", "amount_owed": 180.0, "is_payer": False},
    ]
    cust_res = calculate_custom_split(300.0, custom_parts)
    assert cust_res[0]["amount_owed"] == 120.0
    assert cust_res[1]["amount_owed"] == 180.0


def test_create_split_and_balance_tracking(db_session, test_user, client, auth_headers):
    # 1. create_expense_split()
    split_in = SplitCreate(
        title="Dinner at Olive Garden",
        total_amount=1500.0,
        currency="INR",
        split_type=SplitType.EQUAL,
        participants=[
            ParticipantCreate(participant_name="Test User", amount_owed=500.0, is_payer=True),
            ParticipantCreate(participant_name="Rahul", amount_owed=500.0, is_payer=False),
            ParticipantCreate(participant_name="Priya", amount_owed=500.0, is_payer=False),
        ],
    )
    split = create_expense_split(test_user.id, split_in, db_session)
    assert split.id is not None
    assert len(split.participants) == 3

    # 2. calculate_user_balance() — track who owes whom
    balance = calculate_user_balance(test_user.id, db_session)
    assert balance.total_owed_to_user == 1000.0  # Rahul (500) + Priya (500)
    assert balance.total_user_owes == 0.0
    assert balance.net_balance == 1000.0
    assert len(balance.friend_balances) == 2

    # 3. record_settlement() — debt settlement
    settle_in = SettlementCreate(
        split_id=split.id,
        payer_name="Rahul",
        payee_name="Test User",
        amount=500.0,
    )
    settlement = record_settlement(test_user.id, settle_in, db_session)
    assert settlement.id is not None
    assert settlement.amount == 500.0

    # 4. get_settlement_history()
    history = get_settlement_history(test_user.id, db_session)
    assert len(history) == 1
    assert history[0].payer_name == "Rahul"

    # Verify updated balance after settlement
    updated_balance = calculate_user_balance(test_user.id, db_session)
    assert updated_balance.total_owed_to_user == 500.0  # Only Priya owes now!
    rahul_bal = next(b for b in updated_balance.friend_balances if b.friend_name == "Rahul")
    assert rahul_bal.net_balance == 0.0
    assert rahul_bal.status == "settled"

    # API endpoints
    bal_res = client.get("/splits/balances", headers=auth_headers)
    assert bal_res.status_code == 200
    assert bal_res.json()["net_balance"] == 500.0

    settle_res = client.get("/splits/settlements", headers=auth_headers)
    assert settle_res.status_code == 200
    assert len(settle_res.json()) == 1


def test_friends_management_and_ledger(db_session, test_user, client, auth_headers):
    # 1. add_friend()
    friend_in = FriendCreate(name="Ankit Sharma", email="ankit@example.com", phone="9876543210")
    friend = add_friend(test_user.id, friend_in, db_session)
    assert friend.id is not None
    assert friend.name == "Ankit Sharma"

    # 2. get_friends()
    friends_list = get_friends(test_user.id, db_session)
    assert len(friends_list) == 1

    # 3. Create a split involving friend
    split_in = SplitCreate(
        title="Movie tickets",
        total_amount=600.0,
        split_type=SplitType.EQUAL,
        participants=[
            ParticipantCreate(participant_name="Test User", amount_owed=300.0, is_payer=True),
            ParticipantCreate(participant_name="Ankit Sharma", amount_owed=300.0, is_payer=False),
        ],
    )
    create_expense_split(test_user.id, split_in, db_session)

    # 4. get_friend_ledger()
    ledger = get_friend_ledger(test_user.id, friend.id, db_session)
    assert ledger.current_balance == 300.0
    assert ledger.status == "owes_you"
    assert len(ledger.ledger_entries) == 1

    # Record settlement from friend
    record_settlement(
        test_user.id,
        SettlementCreate(payer_name="Ankit Sharma", payee_name="Test User", amount=300.0),
        db_session,
    )

    ledger_after = get_friend_ledger(test_user.id, friend.id, db_session)
    assert ledger_after.current_balance == 0.0
    assert ledger_after.status == "settled"
    assert len(ledger_after.ledger_entries) == 2

    # 5. delete_friend()
    deleted = delete_friend(friend.id, test_user.id, db_session)
    assert deleted is True
    assert len(get_friends(test_user.id, db_session)) == 0
