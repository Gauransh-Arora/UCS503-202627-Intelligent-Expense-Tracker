"""Transaction Pydantic schemas."""
from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.models.transaction import PaymentMethod, VerificationStatus


class TransactionItemCreate(BaseModel):
    item_name: str
    quantity: int = 1
    unit_price: float
    total_price: float


class TransactionItemResponse(BaseModel):
    id: UUID
    item_name: str
    quantity: int
    unit_price: float
    total_price: float

    model_config = {"from_attributes": True}


class TransactionCreate(BaseModel):
    merchant_name: str
    amount: float
    currency: str = "INR"
    transaction_date: date
    payment_method: PaymentMethod = PaymentMethod.UPI
    description: Optional[str] = None
    category_id: Optional[UUID] = None
    document_id: Optional[UUID] = None
    items: list[TransactionItemCreate] = []

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v

    @field_validator("merchant_name")
    @classmethod
    def merchant_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Merchant name cannot be empty")
        return v.strip()


class TransactionUpdate(BaseModel):
    merchant_name: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None
    transaction_date: Optional[date] = None
    payment_method: Optional[PaymentMethod] = None
    description: Optional[str] = None
    category_id: Optional[UUID] = None
    verification_status: Optional[VerificationStatus] = None


class TransactionResponse(BaseModel):
    id: UUID
    user_id: UUID
    merchant_name: str
    amount: float
    currency: str
    transaction_date: date
    payment_method: PaymentMethod
    description: Optional[str]
    category_id: Optional[UUID]
    document_id: Optional[UUID]
    verification_status: VerificationStatus
    ocr_confidence: Optional[float]
    auto_categorized: bool
    items: list[TransactionItemResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
