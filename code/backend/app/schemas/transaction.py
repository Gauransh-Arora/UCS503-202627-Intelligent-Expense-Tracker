"""Transaction Pydantic schemas with Decimal precision."""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_serializer, field_validator

from app.models.transaction import PaymentMethod, VerificationStatus


class TransactionItemCreate(BaseModel):
    name: str
    quantity: int = 1
    unit_price: Optional[Decimal] = None
    total_price: Decimal
    category_id: Optional[UUID] = None


class TransactionItemResponse(BaseModel):
    id: UUID
    name: str
    quantity: int
    unit_price: Optional[Decimal]
    total_price: Decimal
    category_id: Optional[UUID]

    model_config = {"from_attributes": True}

    @field_serializer("unit_price", "total_price", when_used="json")
    def serialize_prices(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class TransactionCreate(BaseModel):
    merchant_name: str
    amount: Decimal
    currency: str = "INR"
    transaction_date: date
    payment_method: PaymentMethod = PaymentMethod.UPI
    description: Optional[str] = None
    category_id: Optional[UUID] = None
    document_id: Optional[UUID] = None
    items: list[TransactionItemCreate] = []

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: Decimal) -> Decimal:
        if v <= Decimal("0.00"):
            raise ValueError("Amount must be positive")
        return round(v, 2)

    @field_validator("merchant_name")
    @classmethod
    def merchant_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Merchant name cannot be empty")
        return v.strip()


class TransactionUpdate(BaseModel):
    merchant_name: Optional[str] = None
    amount: Optional[Decimal] = None
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
    amount: Decimal
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

    @field_serializer("amount", when_used="json")
    def serialize_amount(self, v: Decimal) -> float:
        return float(v)


class CategoryMiniResponse(BaseModel):
    id: UUID
    name: str
    icon: Optional[str] = None

    model_config = {"from_attributes": True}


class SourceDocumentMiniResponse(BaseModel):
    id: UUID
    original_filename: Optional[str] = None
    file_url: Optional[str] = None
    mime_type: Optional[str] = None
    document_type: str
    processing_status: str
    ocr_confidence: Optional[float] = None
    ocr_text: Optional[str] = None

    model_config = {"from_attributes": True}


class TransactionDetailResponse(BaseModel):
    id: UUID
    user_id: UUID
    merchant_name: str
    amount: Decimal
    currency: str
    transaction_date: date
    payment_method: PaymentMethod
    description: Optional[str]
    is_verified: bool = True
    verification_status: VerificationStatus
    ocr_confidence: Optional[float]
    auto_categorized: bool
    category_id: Optional[UUID]
    category: Optional[CategoryMiniResponse] = None
    source_document: Optional[SourceDocumentMiniResponse] = None
    items: list[TransactionItemResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
