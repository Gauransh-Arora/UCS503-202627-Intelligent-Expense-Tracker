"""Wishlist router — manage wish items, discretionary budget, and purchase readiness evaluation."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import (
    DiscretionaryBudgetInfo,
    ReadinessResponse,
    WishlistCreate,
    WishlistResponse,
    WishlistUpdate,
)
from app.services.intelligence_service import (
    add_wishlist_item as service_add_wishlist_item,
    calculate_discretionary_budget as service_calculate_discretionary_budget,
    calculate_purchase_readiness as service_calculate_purchase_readiness,
    delete_wishlist_item as service_delete_wishlist_item,
    get_wishlist_items as service_get_wishlist_items,
    update_wishlist_item as service_update_wishlist_item,
)
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
def add_wishlist_item(
    item_in: WishlistCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Save a planned purchase to the wishlist."""
    return service_add_wishlist_item(current_user.id, item_in, db)


# Alias
create_wishlist_item = add_wishlist_item


@router.get("/", response_model=list[WishlistResponse])
def get_wishlist_items(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve all wishlist entries."""
    return service_get_wishlist_items(current_user.id, db)


# Alias
list_wishlist = get_wishlist_items


@router.get("/budget", response_model=DiscretionaryBudgetInfo)
def calculate_discretionary_budget(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estimate available discretionary budget for planned purchases."""
    return service_calculate_discretionary_budget(current_user.id, db)


@router.get("/{item_id}", response_model=WishlistResponse)
def get_wishlist_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get single wishlist item."""
    return _get_item_or_404(item_id, current_user.id, db)


@router.put("/{item_id}", response_model=WishlistResponse)
def update_wishlist_item(
    item_id: UUID,
    item_update: WishlistUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update wishlist item."""
    return service_update_wishlist_item(item_id, current_user.id, item_update, db)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wishlist_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove item from wishlist."""
    service_delete_wishlist_item(item_id, current_user.id, db)


@router.get("/{item_id}/readiness", response_model=ReadinessResponse)
def calculate_purchase_readiness(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Evaluate a purchase against spending, savings goals, and recurring expenses.
    Returns verdict: Comfortable, Possible, or Not recommended currently.
    """
    item = _get_item_or_404(item_id, current_user.id, db)
    return service_calculate_purchase_readiness(item, current_user.id, db)


# Alias
get_purchase_readiness = calculate_purchase_readiness
