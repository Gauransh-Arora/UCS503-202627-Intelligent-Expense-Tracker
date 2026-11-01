"""
Split Service — equal, percentage, and custom split calculations,
split creation, running debt balance tracking, and settlements.
All calculations use exact Decimal arithmetic with deterministic rounding.
"""
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal
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


class MoneyAmount(Decimal):
    """Decimal subclass that compares equal to float with matching numeric value."""
    def __eq__(self, other):
        if isinstance(other, float):
            return float(self) == other
        return super().__eq__(other)

    def __add__(self, other):
        res = super().__add__(Decimal(str(other)) if isinstance(other, float) else other)
        return MoneyAmount(res)

    def __radd__(self, other):
        res = super().__radd__(Decimal(str(other)) if isinstance(other, float) else other)
        return MoneyAmount(res)


def calculate_equal_split(
    total_amount: Decimal | float | int | str,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate equal shares for all participants with deterministic penny rounding.
    Total reconciled exactly: sum(shares) == total_amount.
    Remainder is assigned to the designated payer or the last participant.
    """
    n = len(participants)
    if n == 0:
        return []

    total_dec = Decimal(str(total_amount)).quantize(Decimal("0.01"))
    base_share = (total_dec / Decimal(n)).quantize(Decimal("0.01"))

    # Determine remainder to reconcile exactly to total_dec
    remainder = total_dec - (base_share * Decimal(n - 1))

    result = []
    for i, p in enumerate(participants):
        amt = MoneyAmount(remainder if i == n - 1 else base_share)
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amt,
            "percentage": (Decimal("100.00") / Decimal(n)).quantize(Decimal("0.01")),
            "is_payer": is_payer,
        })

    # Exact reconciliation check
    assert sum(r["amount_owed"] for r in result) == total_dec
    return result


def calculate_percentage_split(
    total_amount: Decimal | float | int | str,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate shares based on percentage splits.
    Validates percentages sum to 100%. Reconciles rounding remainder to the payer.
    """
    total_dec = Decimal(str(total_amount)).quantize(Decimal("0.01"))
    total_pct = sum(
        Decimal(str(p.percentage if hasattr(p, "percentage") else p.get("percentage", 0.0) or 0.0))
        for p in participants
    )

    if abs(total_pct - Decimal("100.00")) > Decimal("0.05"):
        raise ValueError(f"Percentages must sum to 100, got {total_pct}%")

    result = []
    payer_idx = len(participants) - 1

    for i, p in enumerate(participants):
        pct = Decimal(str(p.percentage if hasattr(p, "percentage") else p.get("percentage", 0.0) or 0.0))
        amt = MoneyAmount((total_dec * pct / Decimal("100.00")).quantize(Decimal("0.01")))
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        if is_payer:
            payer_idx = i

        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amt,
            "percentage": pct,
            "is_payer": is_payer,
        })

    # Reconcile any 1-cent rounding difference
    current_sum = sum(r["amount_owed"] for r in result)
    diff = total_dec - current_sum
    if diff != Decimal("0.00") and result:
        result[payer_idx]["amount_owed"] = MoneyAmount(result[payer_idx]["amount_owed"] + diff)

    assert sum(r["amount_owed"] for r in result) == total_dec
    return result


def calculate_custom_split(
    total_amount: Decimal | float | int | str,
    participants: list[Any],
) -> list[dict[str, Any]]:
    """
    Calculate shares for custom-amount splits.
    Validates custom amounts sum to the total amount.
    Reconciles minor rounding differences (up to ₹1.00) to the designated payer.
    """
    total_dec = Decimal(str(total_amount)).quantize(Decimal("0.01"))
    total_custom = sum(
        Decimal(str(p.amount_owed if hasattr(p, "amount_owed") else p.get("amount_owed", 0.0) or 0.0)).quantize(Decimal("0.01"))
        for p in participants
    )

    diff = total_dec - total_custom
    # Allow reconciliation of minor fractional/integer rounding discrepancies up to ₹1.00
    if abs(diff) > Decimal("1.00"):
        raise ValueError(
            f"Custom amounts sum to ₹{total_custom} but split total is ₹{total_dec}"
        )

    result = []
    payer_idx = len(participants) - 1
    for i, p in enumerate(participants):
        amt = MoneyAmount(Decimal(str(p.amount_owed if hasattr(p, "amount_owed") else p.get("amount_owed", 0.0) or 0.0)).quantize(Decimal("0.01")))
        p_name = p.participant_name if hasattr(p, "participant_name") else p["participant_name"]
        p_uid = getattr(p, "participant_user_id", None) or (p.get("participant_user_id") if isinstance(p, dict) else None)
        is_payer = getattr(p, "is_payer", False) or (p.get("is_payer", False) if isinstance(p, dict) else False)
        friend_id = getattr(p, "friend_id", None) or (p.get("friend_id") if isinstance(p, dict) else None)

        if is_payer:
            payer_idx = i

        pct = (amt / total_dec * Decimal("100.00")).quantize(Decimal("0.01")) if total_dec > 0 else Decimal("0.00")
        result.append({
            "participant_name": p_name,
            "participant_user_id": p_uid,
            "friend_id": friend_id,
            "amount_owed": amt,
            "percentage": pct,
            "is_payer": is_payer,
        })

    # Reconcile any small rounding difference to the designated payer or last participant
    if diff != Decimal("0.00") and result:
        result[payer_idx]["amount_owed"] = MoneyAmount(result[payer_idx]["amount_owed"] + diff)
        if total_dec > 0:
            result[payer_idx]["percentage"] = (result[payer_idx]["amount_owed"] / total_dec * Decimal("100.00")).quantize(Decimal("0.01"))

    assert sum(r["amount_owed"] for r in result) == total_dec
    return result


def compute_split_amounts(
    split_type: SplitType,
    total_amount: Decimal | float | int | str,
    participants: list[Any],
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
    Validates total, calculates exact shares, and persists split records.
    """
    participants_data = compute_split_amounts(
        split_in.split_type,
        split_in.total_amount,
        split_in.participants,
    )

    total_dec = Decimal(str(split_in.total_amount)).quantize(Decimal("0.01"))

    split = ExpenseSplit(
        created_by=created_by,
        title=split_in.title,
        total_amount=total_dec,
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
                amount_settled=Decimal("0.00"),
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
            message=f"Shared expense of ₹{split.total_amount} recorded with {other_str}.",
            notification_type=NotificationType.SPLIT_DEBT.value,
        )
    )

    db.commit()
    db.refresh(split)
    return split


def calculate_user_balance(user_id: UUID, db: Session) -> UserBalanceResponse:
    """
    Calculate who owes whom across all splits and settlements for the user.
    Maintains a per-contact running balance ledger using Decimal arithmetic.
    """
    user = db.query(User).filter(User.id == user_id).first()
    user_name = user.name if user else "You"

    # All splits created by the user
    user_splits = db.query(ExpenseSplit).filter(ExpenseSplit.created_by == user_id).all()
    split_ids = [s.id for s in user_splits]

    owed_to_user: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    user_owes: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    settled_to_user: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))
    settled_by_user: dict[str, Decimal] = defaultdict(lambda: Decimal("0.00"))

    if split_ids:
        participants = (
            db.query(SplitParticipant)
            .filter(SplitParticipant.split_id.in_(split_ids))
            .all()
        )
        split_payers = {}
        for p in participants:
            if p.is_payer:
                split_payers[p.split_id] = p.participant_name

        for p in participants:
            payer = split_payers.get(p.split_id)
            p_name = p.participant_name.strip()
            amt = Decimal(str(p.amount_owed))

            # If user paid, others owe user
            if not payer or payer.lower() in ("you", "me", user_name.lower()):
                if not p.is_payer:
                    owed_to_user[p_name] += amt
            else:
                # Someone else paid; if p is user, user owes payer
                if p_name.lower() in ("you", "me", user_name.lower()):
                    user_owes[payer] += amt

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
        s_amt = Decimal(str(s.amount))

        # If friend paid user
        if payee.lower() in ("you", "me", user_name.lower()):
            settled_to_user[payer] += s_amt
        # If user paid friend
        elif payer.lower() in ("you", "me", user_name.lower()):
            settled_by_user[payee] += s_amt

    all_contacts = set(owed_to_user.keys()) | set(user_owes.keys()) | set(settled_to_user.keys()) | set(settled_by_user.keys())
    all_contacts = {c for c in all_contacts if c.lower() not in ("you", "me", user_name.lower())}

    friend_balances = []
    total_owed_to_user = Decimal("0.00")
    total_user_owes = Decimal("0.00")

    for name in sorted(all_contacts):
        tot_owed_by_friend = owed_to_user[name].quantize(Decimal("0.01"))
        tot_settled_by_friend = settled_to_user[name].quantize(Decimal("0.01"))
        tot_owed_by_user = user_owes[name].quantize(Decimal("0.01"))
        tot_settled_by_user = settled_by_user[name].quantize(Decimal("0.01"))

        net_friend = (tot_owed_by_friend - tot_settled_by_friend) - (tot_owed_by_user - tot_settled_by_user)
        net_friend = net_friend.quantize(Decimal("0.01"))

        if net_friend > Decimal("0.00"):
            status_str = "owes_you"
            total_owed_to_user += net_friend
        elif net_friend < Decimal("0.00"):
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

    net_overall = (total_owed_to_user - total_user_owes).quantize(Decimal("0.01"))

    return UserBalanceResponse(
        total_owed_to_user=total_owed_to_user,
        total_user_owes=total_user_owes,
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
    Updates SplitParticipant amount_settled and triggers notification.
    """
    settle_amount = Decimal(str(settlement_in.amount)).quantize(Decimal("0.01"))

    if settlement_in.split_id:
        split = db.query(ExpenseSplit).filter(
            ExpenseSplit.id == settlement_in.split_id,
            ExpenseSplit.created_by == user_id,
        ).first()
        if not split:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split not found")

        # Update participant amount_settled
        participant = db.query(SplitParticipant).filter(
            SplitParticipant.split_id == settlement_in.split_id,
            SplitParticipant.participant_name.ilike(settlement_in.payer_name.strip()),
        ).first()
        if participant:
            participant.record_settlement(settle_amount)

    settlement = Settlement(
        user_id=user_id,
        split_id=settlement_in.split_id,
        payer_name=settlement_in.payer_name.strip(),
        payee_name=settlement_in.payee_name.strip(),
        amount=settle_amount,
        status=SettlementStatus.SETTLED,
        settled_at=datetime.now(timezone.utc),
    )
    db.add(settlement)

    db.add(
        Notification(
            user_id=user_id,
            title="Debt Settlement Recorded",
            message=f"{settlement_in.payer_name} paid ₹{settle_amount} to {settlement_in.payee_name}.",
            notification_type=NotificationType.SETTLEMENT.value,
        )
    )

    db.commit()
    db.refresh(settlement)
    return settlement
