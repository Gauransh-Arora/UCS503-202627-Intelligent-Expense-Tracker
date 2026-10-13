"""
Friend Service — manage contacts/friends local to user's account and per-contact debt ledgers.
"""
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.friend import Friend
from app.models.split import ExpenseSplit, Settlement, SplitParticipant
from app.models.user import User
from app.schemas.split import (
    FriendCreate,
    FriendLedgerItem,
    FriendLedgerResponse,
    FriendResponse,
)


def add_friend(user_id: UUID, friend_in: FriendCreate, db: Session) -> Friend:
    """Add a new friend / contact under the user's account."""
    existing = db.query(Friend).filter(
        Friend.user_id == user_id,
        Friend.name.ilike(friend_in.name.strip()),
    ).first()
    if existing:
        return existing

    friend = Friend(
        user_id=user_id,
        name=friend_in.name.strip(),
        email=friend_in.email.strip().lower() if friend_in.email else None,
        phone=friend_in.phone.strip() if friend_in.phone else None,
        avatar_url=friend_in.avatar_url,
    )
    db.add(friend)
    db.commit()
    db.refresh(friend)
    return friend


def get_friends(user_id: UUID, db: Session) -> list[Friend]:
    """List all contacts/friends for the user."""
    return db.query(Friend).filter(Friend.user_id == user_id).order_by(Friend.name).all()


def delete_friend(friend_id: UUID, user_id: UUID, db: Session) -> bool:
    """Delete a friend record."""
    friend = db.query(Friend).filter(
        Friend.id == friend_id,
        Friend.user_id == user_id,
    ).first()
    if not friend:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Friend not found")

    db.delete(friend)
    db.commit()
    return True


def get_friend_ledger(user_id: UUID, friend_id: UUID, db: Session) -> FriendLedgerResponse:
    """
    Retrieve chronological per-contact ledger of all splits and settlements
    associated with this friend, and calculate current running balance.
    """
    friend = db.query(Friend).filter(
        Friend.id == friend_id,
        Friend.user_id == user_id,
    ).first()
    if not friend:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Friend not found")

    user = db.query(User).filter(User.id == user_id).first()
    user_name = user.name if user else "You"

    # Find splits where friend was a participant or matched by name
    user_splits = db.query(ExpenseSplit).filter(ExpenseSplit.created_by == user_id).all()
    split_ids = [s.id for s in user_splits]

    ledger_entries: list[FriendLedgerItem] = []
    total_owed_by_friend = 0.0
    total_settled_by_friend = 0.0

    if split_ids:
        participants = (
            db.query(SplitParticipant)
            .filter(
                SplitParticipant.split_id.in_(split_ids),
                (SplitParticipant.friend_id == friend.id) | (SplitParticipant.participant_name.ilike(friend.name)),
            )
            .all()
        )
        for p in participants:
            split_obj = next((s for s in user_splits if s.id == p.split_id), None)
            split_title = split_obj.title if split_obj else "Shared Expense"
            date = split_obj.created_at if split_obj else p.created_at

            if not p.is_payer:
                total_owed_by_friend += p.amount_owed
                ledger_entries.append(
                    FriendLedgerItem(
                        id=p.id,
                        type="split",
                        date=date,
                        description=f"Share in '{split_title}'",
                        amount=p.amount_owed,
                        role="lent",  # user lent money to friend
                    )
                )

    # Find settlements involving this friend
    settlements = (
        db.query(Settlement)
        .filter(
            (Settlement.user_id == user_id) | (Settlement.split_id.in_(split_ids) if split_ids else False),
            (Settlement.payer_name.ilike(friend.name)) | (Settlement.payee_name.ilike(friend.name)),
        )
        .all()
    )

    for s in settlements:
        if s.payer_name.lower() == friend.name.lower():
            total_settled_by_friend += s.amount
            ledger_entries.append(
                FriendLedgerItem(
                    id=s.id,
                    type="settlement",
                    date=s.settled_at or s.created_at,
                    description=f"Settlement from {s.payer_name}",
                    amount=s.amount,
                    role="settled",
                )
            )

    ledger_entries.sort(key=lambda x: x.date, reverse=True)
    net = round(total_owed_by_friend - total_settled_by_friend, 2)
    status_str = "owes_you" if net > 0 else ("you_owe" if net < 0 else "settled")

    return FriendLedgerResponse(
        friend=FriendResponse.model_validate(friend),
        current_balance=net,
        status=status_str,
        ledger_entries=ledger_entries,
    )
