"""Split Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.models.split import SplitType, SettlementStatus


class ParticipantCreate(BaseModel):
    participant_name: str
    amount_owed: float
    percentage: Optional[float] = None
    is_payer: bool = False
    participant_user_id: Optional[UUID] = None


class ParticipantResponse(BaseModel):
    id: UUID
    participant_name: str
    amount_owed: float
    percentage: Optional[float]
    is_payer: bool

    model_config = {"from_attributes": True}


class SplitCreate(BaseModel):
    title: str
    total_amount: float
    currency: str = "INR"
    split_type: SplitType = SplitType.EQUAL
    description: Optional[str] = None
    participants: list[ParticipantCreate]

    @field_validator("total_amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Total amount must be positive")
        return v

    @field_validator("participants")
    @classmethod
    def at_least_two(cls, v: list) -> list:
        if len(v) < 2:
            raise ValueError("A split needs at least 2 participants")
        return v


class SplitResponse(BaseModel):
    id: UUID
    title: str
    total_amount: float
    currency: str
    split_type: SplitType
    description: Optional[str]
    participants: list[ParticipantResponse] = []
    created_at: datetime

    model_config = {"from_attributes": True}


class SettlementCreate(BaseModel):
    split_id: UUID
    payer_name: str
    payee_name: str
    amount: float


class SettlementResponse(BaseModel):
    id: UUID
    split_id: UUID
    payer_name: str
    payee_name: str
    amount: float
    status: SettlementStatus
    settled_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}
