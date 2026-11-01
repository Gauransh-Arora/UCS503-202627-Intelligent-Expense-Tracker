"""Split Pydantic schemas with Decimal precision."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_serializer, field_validator

from app.models.split import SplitType, SettlementStatus


class ParticipantCreate(BaseModel):
    participant_name: str
    amount_owed: Decimal = Decimal("0.00")
    percentage: Optional[Decimal] = None
    is_payer: bool = False
    participant_user_id: Optional[UUID] = None
    friend_id: Optional[UUID] = None


class ParticipantResponse(BaseModel):
    id: UUID
    participant_name: str
    amount_owed: Decimal
    amount_settled: Decimal = Decimal("0.00")
    percentage: Optional[Decimal] = None
    is_payer: bool

    model_config = {"from_attributes": True}

    @field_serializer("amount_owed", "amount_settled", when_used="json")
    def serialize_amounts(self, v: Decimal) -> float:
        return float(v)

    @field_serializer("percentage", when_used="json")
    def serialize_percentage(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class SplitCreate(BaseModel):
    title: str
    total_amount: Decimal
    currency: str = "INR"
    split_type: SplitType = SplitType.EQUAL
    description: Optional[str] = None
    participants: list[ParticipantCreate]

    @field_validator("split_type", mode="before")
    @classmethod
    def normalize_split_type(cls, v):
        if str(v).lower() == "exact":
            return SplitType.CUSTOM
        return v

    @field_validator("total_amount")
    @classmethod
    def amount_positive(cls, v: Decimal) -> Decimal:
        if v <= Decimal("0.00"):
            raise ValueError("Total amount must be positive")
        return round(v, 2)

    @field_validator("participants")
    @classmethod
    def at_least_two(cls, v: list) -> list:
        if len(v) < 2:
            raise ValueError("A split needs at least 2 participants")
        return v


class SplitResponse(BaseModel):
    id: UUID
    title: str
    total_amount: Decimal
    currency: str
    split_type: SplitType
    description: Optional[str]
    participants: list[ParticipantResponse] = []
    created_at: datetime

    model_config = {"from_attributes": True}

    @field_serializer("total_amount", when_used="json")
    def serialize_total(self, v: Decimal) -> float:
        return float(v)


class SettlementCreate(BaseModel):
    split_id: Optional[UUID] = None
    payer_name: str
    payee_name: str
    amount: Decimal

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: Decimal) -> Decimal:
        if v <= Decimal("0.00"):
            raise ValueError("Settlement amount must be positive")
        return round(v, 2)


class SettlementResponse(BaseModel):
    id: UUID
    split_id: Optional[UUID] = None
    payer_name: str
    payee_name: str
    amount: float
    status: SettlementStatus
    settled_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class FriendBalanceItem(BaseModel):
    friend_name: str
    friend_id: Optional[UUID] = None
    net_balance: float      # Positive: friend owes user; Negative: user owes friend
    total_owed_by_friend: float
    total_settled_by_friend: float
    total_owed_by_user: float
    total_settled_by_user: float
    status: str             # "owes_you", "you_owe", "settled"


class UserBalanceResponse(BaseModel):
    total_owed_to_user: float   # what friends owe current user
    total_user_owes: float      # what current user owes friends
    net_balance: float          # total_owed_to_user - total_user_owes
    friend_balances: list[FriendBalanceItem] = []


class FriendCreate(BaseModel):
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None


class FriendResponse(BaseModel):
    id: UUID
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class FriendLedgerItem(BaseModel):
    id: UUID
    type: str  # "split" or "settlement"
    date: datetime
    description: str
    amount: float
    role: str  # "borrowed" or "lent" or "settled"


class FriendLedgerResponse(BaseModel):
    friend: FriendResponse
    current_balance: float
    status: str
    ledger_entries: list[FriendLedgerItem] = []
