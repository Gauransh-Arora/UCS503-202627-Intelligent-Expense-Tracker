"""
Split Service — equal, percentage, and custom split calculations,
split creation, running debt balance tracking, and settlements.
"""
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.notification import Notification, NotificationType
from app.models.split import ExpenseSplit, Settlement, SettlementStatus, SplitParticipant, SplitType
from app.models.user import User
from app.schemas.split import (
    FriendBalanceItem,
    ParticipantCreate,
    SettlementCreate,
    SplitCreate,
    UserBalanceResponse,
)


def calculate_equal_split(
    total_amount: float,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate equal shares for all participants.
    Adjusts last participant by cents/paise for clean total reconciliation.
    """
    n = len(participants)
    if n == 0:
        return []

    share = round(total_amount / n, 2)
    remainder = round(total_amount - share * (n - 1), 2)

    result = []
    for i, p in enumerate(participants):
        amount = remainder if i == n - 1 else share
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amount,
            "percentage": round(100.0 / n, 2),
            "is_payer": is_payer,
        })
    return result


def calculate_percentage_split(
    total_amount: float,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate shares based on percentage splits.
    Validates percentages sum to 100%.
    """
    total_pct = sum(
        (p.percentage if hasattr(p, "percentage") else p.get("percentage", 0.0)) or 0.0
        for p in participants
    )
    if abs(total_pct - 100.0) > 0.05:
        raise ValueError(f"Percentages must sum to 100, got {total_pct:.2f}%")

    result = []
    for p in participants:
        pct = (p.percentage if hasattr(p, "percentage") else p.get("percentage", 0.0)) or 0.0
        amount = round(total_amount * pct / 100.0, 2)
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amount,
            "percentage": pct,
            "is_payer": is_payer,
        })
    return result


def calculate_custom_split(
    total_amount: float,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate shares for custom-amount splits.
    Validates custom amounts sum to the total amount within tolerance.
    """
    total_custom = sum(
        (p.amount_owed if hasattr(p, "amount_owed") else p.get("amount_owed", 0.0)) or 0.0
        for p in participants
    )
    if abs(total_custom - total_amount) > 0.50:
        raise ValueError(
            f"Custom amounts sum to {total_custom:.2f} but total is {total_amount:.2f}"
        )

    result = []
    for p in participants:
        amt = (p.amount_owed if hasattr(p, "amount_owed") else p.get("amount_owed", 0.0)) or 0.0
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amt,
            "percentage": round(amt / total_amount * 100.0, 2) if total_amount > 0 else 0.0,
            "is_payer": is_payer,
        })
    return result


def compute_split_amounts(
    split_type: SplitType,
    total_amount: float,
    participants: list[ParticipantCreate],
) -> list[dict[str, Any]]:
    """Dispatcher for calculating participant amounts based on method."""
    if split_type == SplitType.EQUAL:
        return calculate_equal_split(total_amount, participants)
    elif split_type == SplitType.PERCENTAGE:
        return calculate_percentage_split(total_amount, participants)
    elif split_type == SplitType.CUSTOM:
        return calculate_custom_split(total_amount, participants)
    raise ValueError(f"Unknown split type: {split_type}")


def create_expense_split(
    created_by: UUID,
    split_in: SplitCreate,
    db: Session,
) -> ExpenseSplit:
    """
    Create a shared expense split among participants.
    Automatically computes shares and creates debt notification.
    """
    participants_data = compute_split_amounts(
        split_in.split_type,
        split_in.total_amount,
        split_in.participants,
    )

    split = ExpenseSplit(
        created_by=created_by,
        title=split_in.title,
        total_amount=split_in.total_amount,
        currency=split_in.currency,
        split_type=split_in.split_type,
        description=split_in.description,
    )
    db.add(split)
    db.flush()

    for p in participants_data:
        db.add(
            SplitParticipant(
                split_id=split.id,
                participant_name=p["participant_name"],
                participant_user_id=p.get("participant_user_id"),
                friend_id=p.get("friend_id"),
                amount_owed=p["amount_owed"],
                percentage=p.get("percentage"),
                is_payer=p.get("is_payer", False),
            )
        )

    # Auto notification for creator
    other_participants = [p["participant_name"] for p in participants_data if not p.get("is_payer")]
    other_str = ", ".join(other_participants[:3])
    if len(other_participants) > 3:
        other_str += f" and {len(other_participants) - 3} others"

    db.add(
        Notification(
            user_id=created_by,
            title=f"Split Created: {split.title}",
            message=f"Shared expense of ₹{split.total_amount:,.2f} recorded with {other_str}.",
            notification_type=NotificationType.SPLIT_DEBT.value,
        )
    )

    db.commit()
    db.refresh(split)
    return split


def calculate_user_balance(user_id: UUID, db: Session) -> UserBalanceResponse:
    """
    Calculate who owes whom across all splits and settlements for the user.
    Maintains a per-contact running balance ledger.
    """
    user = db.query(User).filter(User.id == user_id).first()
    user_name = user.name if user else "You"

    # All splits created by the user
    user_splits = db.query(ExpenseSplit).filter(ExpenseSplit.created_by == user_id).all()
    split_ids = [s.id for s in user_splits]

    # Tracking per friend/contact name
    # owed_to_user: how much this contact owes user
    # user_owes: how much user owes this contact
    owed_to_user = defaultdict(float)
    user_owes = defaultdict(float)
    settled_to_user = defaultdict(float)
    settled_by_user = defaultdict(float)

    if split_ids:
        participants = (
            db.query(SplitParticipant)
            .filter(SplitParticipant.split_id.in_(split_ids))
            .all()
        )
        # Find payer for each split
        split_payers = {}
        for p in participants:
            if p.is_payer:
                split_payers[p.split_id] = p.participant_name

        for p in participants:
            payer = split_payers.get(p.split_id)
            p_name = p.participant_name.strip()

            # If user paid, others owe user
            if not payer or payer.lower() in ("you", "me", user_name.lower()):
                if not p.is_payer:
                    owed_to_user[p_name] += p.amount_owed
            else:
                # Someone else paid; if p is user, user owes payer
                if p_name.lower() in ("you", "me", user_name.lower()):
                    user_owes[payer] += p.amount_owed

    # Check settlements
    settlements = (
        db.query(Settlement)
        .filter(
            (Settlement.user_id == user_id) | (Settlement.split_id.in_(split_ids) if split_ids else False)
        )
        .all()
    )

    for s in settlements:
        payer = s.payer_name.strip()
        payee = s.payee_name.strip()

        # If friend paid user
        if payee.lower() in ("you", "me", user_name.lower()):
            settled_to_user[payer] += s.amount
        # If user paid friend
        elif payer.lower() in ("you", "me", user_name.lower()):
            settled_by_user[payee] += s.amount

    # Aggregate contacts
    all_contacts = set(owed_to_user.keys()) | set(user_owes.keys()) | set(settled_to_user.keys()) | set(settled_by_user.keys())
    # Exclude user's own name aliases
    all_contacts = {c for c in all_contacts if c.lower() not in ("you", "me", user_name.lower())}

    friend_balances = []
    total_owed_to_user = 0.0
    total_user_owes = 0.0

    for name in sorted(all_contacts):
        tot_owed_by_friend = round(owed_to_user[name], 2)
        tot_settled_by_friend = round(settled_to_user[name], 2)
        tot_owed_by_user = round(user_owes[name], 2)
        tot_settled_by_user = round(settled_by_user[name], 2)

        net_friend = (tot_owed_by_friend - tot_settled_by_friend) - (tot_owed_by_user - tot_settled_by_user)
        net_friend = round(net_friend, 2)

        if net_friend > 0:
            status_str = "owes_you"
            total_owed_to_user += net_friend
        elif net_friend < 0:
            status_str = "you_owe"
            total_user_owes += abs(net_friend)
        else:
            status_str = "settled"

        friend_balances.append(
            FriendBalanceItem(
                friend_name=name,
                net_balance=net_friend,
                total_owed_by_friend=tot_owed_by_friend,
                total_settled_by_friend=tot_settled_by_friend,
                total_owed_by_user=tot_owed_by_user,
                total_settled_by_user=tot_settled_by_user,
                status=status_str,
            )
        )

    net_overall = round(total_owed_to_user - total_user_owes, 2)

    return UserBalanceResponse(
        total_owed_to_user=round(total_owed_to_user, 2),
        total_user_owes=round(total_user_owes, 2),
        net_balance=net_overall,
        friend_balances=friend_balances,
    )


def get_settlement_history(
    user_id: UUID,
    db: Session,
    friend_name: Optional[str] = None,
) -> list[Settlement]:
    """Retrieve settlement history for the user, optionally filtered by friend name."""
    user_splits = db.query(ExpenseSplit.id).filter(ExpenseSplit.created_by == user_id).all()
    split_ids = [s[0] for s in user_splits]

    q = db.query(Settlement).filter(
        (Settlement.user_id == user_id) | (Settlement.split_id.in_(split_ids) if split_ids else False)
    )

    if friend_name:
        q = q.filter(
            (Settlement.payer_name.ilike(f"%{friend_name}%")) |
            (Settlement.payee_name.ilike(f"%{friend_name}%"))
        )

    return q.order_by(Settlement.created_at.desc()).all()


def record_settlement(
    user_id: UUID,
    settlement_in: SettlementCreate,
    db: Session,
) -> Settlement:
    """
    Record that a participant or friend has settled a debt.
    Updates debt status and triggers notification.
    """
    if settlement_in.split_id:
        split = db.query(ExpenseSplit).filter(
            ExpenseSplit.id == settlement_in.split_id,
            ExpenseSplit.created_by == user_id,
        ).first()
        if not split:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split not found")

    settlement = Settlement(
        user_id=user_id,
        split_id=settlement_in.split_id,
        payer_name=settlement_in.payer_name,
        payee_name=settlement_in.payee_name,
        amount=settlement_in.amount,
        status=SettlementStatus.SETTLED,
        settled_at=datetime.now(timezone.utc),
    )
    db.add(settlement)

    # Notification
    db.add(
        Notification(
            user_id=user_id,
            title="Debt Settlement Recorded",
            message=f"{settlement_in.payer_name} paid ₹{settlement_in.amount:,.2f} to {settlement_in.payee_name}.",
            notification_type=NotificationType.SETTLEMENT.value,
        )
    )

    db.commit()
    db.refresh(settlement)
    return settlement
