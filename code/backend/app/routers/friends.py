"""Friends & Contacts router — manage contacts for splits and per-contact debt ledgers."""
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.split import (
    FriendCreate,
    FriendLedgerResponse,
    FriendResponse,
)
from app.services.friend_service import (
    add_friend as service_add_friend,
    delete_friend as service_delete_friend,
    get_friend_ledger as service_get_friend_ledger,
    get_friends as service_get_friends,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/friends", tags=["Friends & Contacts"])


@router.post("/", response_model=FriendResponse, status_code=status.HTTP_201_CREATED)
def add_friend(
    friend_in: FriendCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add a new contact/friend under user's account for splitting expenses."""
    return service_add_friend(current_user.id, friend_in, db)


@router.get("/", response_model=list[FriendResponse])
def get_friends(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all contacts/friends for the current user."""
    return service_get_friends(current_user.id, db)


@router.delete("/{friend_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_friend(
    friend_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove a contact/friend."""
    service_delete_friend(friend_id, current_user.id, db)


@router.get("/{friend_id}/ledger", response_model=FriendLedgerResponse)
def get_friend_ledger(
    friend_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get per-contact debt ledger: all splits, settlements, and running balance with this friend."""
    return service_get_friend_ledger(current_user.id, friend_id, db)
