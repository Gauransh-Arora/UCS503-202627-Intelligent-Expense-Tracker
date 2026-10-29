"""BudgetPlan Pydantic schemas."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_serializer, field_validator


class BudgetPlanCreate(BaseModel):
    month: str | int  # YYYY-MM or integer 1-12
    year: Optional[int] = None
    spending_limit: Decimal
    savings_goal: Decimal = Decimal("0.00")
    notes: Optional[str] = None

    @field_validator("month", mode="before")
    @classmethod
    def validate_month_format(cls, v) -> str:
        return str(v).strip()

    def model_post_init(self, __context) -> None:
        import re
        m_str = str(self.month).strip()
        if not re.match(r"^\d{4}-(?:0[1-9]|1[0-2])$", m_str):
            if self.year and m_str.isdigit():
                m_int = int(m_str)
                if 1 <= m_int <= 12:
                    self.month = f"{self.year:04d}-{m_int:02d}"
                    return
            raise ValueError("Month must be in YYYY-MM format (e.g. 2026-10) or provide month and year")

    @field_validator("spending_limit", "savings_goal")
    @classmethod
    def non_negative(cls, v: Decimal) -> Decimal:
        if v < Decimal("0.00"):
            raise ValueError("Amount cannot be negative")
        return round(v, 2)


class BudgetPlanUpdate(BaseModel):
    spending_limit: Optional[Decimal] = None
    savings_goal: Optional[Decimal] = None

    @field_validator("spending_limit", "savings_goal")
    @classmethod
    def non_negative(cls, v: Optional[Decimal]) -> Optional[Decimal]:
        if v is not None and v < Decimal("0.00"):
            raise ValueError("Amount cannot be negative")
        return round(v, 2) if v is not None else None


class BudgetPlanResponse(BaseModel):
    id: UUID
    user_id: UUID
    month: str
    spending_limit: Decimal
    savings_goal: Decimal
    current_spending: Optional[Decimal] = None
    available_budget: Optional[Decimal] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @field_validator("available_budget", mode="before")
    @classmethod
    def filter_callable(cls, v):
        if callable(v):
            return None
        return v

    model_config = {"from_attributes": True}

    @field_serializer("spending_limit", "savings_goal", when_used="json")
    def serialize_limits(self, v: Decimal) -> float:
        return float(v)

    @field_serializer("current_spending", "available_budget", when_used="json")
    def serialize_optionals(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None
