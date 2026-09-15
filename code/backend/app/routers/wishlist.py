"""Wishlist router — manage wish items and compute purchase readiness."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import ReadinessResponse, WishlistCreate, WishlistResponse, WishlistUpdate
from app.services.intelligence_service import compute_purchase_readiness
from app.utils.auth import get_current_user

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])


def _get_item_or_404(item_id: UUID, user_id: UUID, db: Session) -> WishlistItem:
    item = db.query(WishlistItem).filter(
        WishlistItem.id == item_id,
        WishlistItem.user_id == user_id,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wishlist item not found")
    return item


@router.post("/", response_model=WishlistResponse, status_code=status.HTTP_201_CREATED)
def create_wishlist_item(
    item_in: WishlistCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = WishlistItem(
        user_id=current_user.id,
        **item_in.model_dump(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/", response_model=list[WishlistResponse])
def list_wishlist(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(WishlistItem)
        .filter(WishlistItem.user_id == current_user.id)
        .order_by(WishlistItem.created_at.desc())
        .all()
    )


@router.get("/{item_id}", response_model=WishlistResponse)
def get_wishlist_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _get_item_or_404(item_id, current_user.id, db)


@router.put("/{item_id}", response_model=WishlistResponse)
def update_wishlist_item(
    item_id: UUID,
    item_update: WishlistUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = _get_item_or_404(item_id, current_user.id, db)
    for field, value in item_update.model_dump(exclude_unset=True).items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wishlist_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = _get_item_or_404(item_id, current_user.id, db)
    db.delete(item)
    db.commit()


@router.get("/{item_id}/readiness", response_model=ReadinessResponse)
def get_purchase_readiness(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Analyze the user's spending history and compute purchase readiness (0–100)
    for the given wishlist item.
    """
    item = _get_item_or_404(item_id, current_user.id, db)
    return compute_purchase_readiness(item, current_user.id, db)
