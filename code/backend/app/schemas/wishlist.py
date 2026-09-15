"""Wishlist Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator


class WishlistCreate(BaseModel):
    name: str
    expected_price: float
    currency: str = "INR"
    description: Optional[str] = None
    priority: str = "medium"
    url: Optional[str] = None

    @field_validator("expected_price")
    @classmethod
    def price_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Expected price must be positive")
        return v

    @field_validator("priority")
    @classmethod
    def valid_priority(cls, v: str) -> str:
        if v not in ("low", "medium", "high"):
            raise ValueError("Priority must be low, medium, or high")
        return v


class WishlistUpdate(BaseModel):
    name: Optional[str] = None
    expected_price: Optional[float] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    url: Optional[str] = None
    is_purchased: Optional[bool] = None


class WishlistResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    expected_price: float
    currency: str
    description: Optional[str]
    priority: str
    url: Optional[str]
    purchase_readiness: Optional[float]
    estimated_months: Optional[float]
    is_purchased: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ReadinessResponse(BaseModel):
    wishlist_item_id: UUID
    name: str
    expected_price: float
    purchase_readiness: float          # 0–100
    estimated_months: Optional[float]  # None if already affordable
    monthly_discretionary: float
    avg_monthly_spending: float
    analysis_notes: list[str] = []
