"""Wishlist Pydantic schemas with Decimal precision."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_serializer, field_validator


class WishlistCreate(BaseModel):
    name: str
    expected_price: Optional[Decimal] = None
    price: Optional[Decimal] = None
    currency: str = "INR"
    description: Optional[str] = None
    priority: str = "medium"
    url: Optional[str] = None

    @field_validator("expected_price", mode="before")
    @classmethod
    def resolve_price(cls, v, info):
        return v

    def model_post_init(self, __context) -> None:
        if self.expected_price is None and self.price is not None:
            self.expected_price = Decimal(str(self.price))
        if self.expected_price is None:
            raise ValueError("expected_price or price is required")
        if self.expected_price <= Decimal("0.00"):
            raise ValueError("Expected price must be positive")
        self.expected_price = round(self.expected_price, 2)

    @field_validator("priority")
    @classmethod
    def valid_priority(cls, v: str) -> str:
        if v not in ("low", "medium", "high"):
            raise ValueError("Priority must be low, medium, or high")
        return v


class WishlistUpdate(BaseModel):
    name: Optional[str] = None
    expected_price: Optional[Decimal] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    url: Optional[str] = None
    is_purchased: Optional[bool] = None


class WishlistResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    expected_price: Decimal
    currency: str
    description: Optional[str]
    priority: str
    url: Optional[str]
    purchase_readiness: Optional[float]
    estimated_months: Optional[float]
    verdict: Optional[str] = None
    discretionary_budget: Optional[Decimal] = None
    is_purchased: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_serializer("expected_price", when_used="json")
    def serialize_price(self, v: Decimal) -> float:
        return float(v)

    @field_serializer("discretionary_budget", when_used="json")
    def serialize_budget(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class ReadinessResponse(BaseModel):
    wishlist_item_id: UUID
    name: str
    expected_price: Decimal
    purchase_readiness: float          # 0–100
    estimated_months: Optional[float]  # None if already affordable
    monthly_discretionary: Decimal
    avg_monthly_spending: Decimal
    spending_limit: Optional[Decimal] = None
    savings_goal: Optional[Decimal] = None
    verdict: str                       # Exactly: "Comfortable", "Possible", "Not Recommended Currently"
    analysis_notes: list[str] = []

    @field_serializer("expected_price", "monthly_discretionary", "avg_monthly_spending", when_used="json")
    def serialize_decimals(self, v: Decimal) -> float:
        return float(v)

    @field_serializer("spending_limit", "savings_goal", when_used="json")
    def serialize_optional_decimals(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class DiscretionaryBudgetInfo(BaseModel):
    monthly_discretionary: Decimal
    avg_monthly_spending: Decimal
    monthly_recurring: Decimal
    savings_reserve: Decimal
    spending_limit: Optional[Decimal] = None
    savings_goal: Optional[Decimal] = None
    analysis_notes: list[str] = []

    @field_serializer("monthly_discretionary", "avg_monthly_spending", "monthly_recurring", "savings_reserve", when_used="json")
    def serialize_decimals(self, v: Decimal) -> float:
        return float(v)

    @field_serializer("spending_limit", "savings_goal", when_used="json")
    def serialize_optional_decimals(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class SubscriptionResponse(BaseModel):
    merchant_name: str
    monthly_amount: Decimal
    annual_amount: Decimal
    frequency: str
    confidence: float
    category_name: Optional[str] = None
    typical_day: Optional[int] = None
    status: str = "active"

    @field_serializer("monthly_amount", "annual_amount", when_used="json")
    def serialize_amounts(self, v: Decimal) -> float:
        return float(v)
