"""Transaction Pydantic schemas."""
from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator

from app.models.transaction import PaymentMethod, VerificationStatus


class TransactionItemCreate(BaseModel):
    name: str
    quantity: int = 1
    unit_price: Optional[float] = None
    total_price: float
    category_id: Optional[UUID] = None


class TransactionItemResponse(BaseModel):
    id: UUID
    name: str
    quantity: int
    unit_price: Optional[float]
    total_price: float
    category_id: Optional[UUID]

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
    amount: float
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
