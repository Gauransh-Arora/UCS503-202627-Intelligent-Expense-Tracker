"""Document Pydantic schemas."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_serializer


class DocumentResponse(BaseModel):
    id: UUID
    user_id: UUID
    original_filename: Optional[str] = None
    file_url: Optional[str] = None
    mime_type: Optional[str] = None
    document_type: str
    processing_status: str
    ocr_text: Optional[str] = None
    ocr_confidence: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ExtractedItem(BaseModel):
    name: str
    quantity: int = 1
    unit_price: Optional[Decimal] = None
    total_price: Optional[Decimal] = None
    price: Optional[Decimal] = None

    @field_serializer("unit_price", "total_price", "price", when_used="json")
    def serialize_prices(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None


class OCRResult(BaseModel):
    """Structured data extracted from OCR/Vision raw text with per-field confidence."""
    document_id: UUID
    raw_text: str
    merchant_name: Optional[str] = None
    amount: Optional[Decimal] = None
    tax_amount: Optional[Decimal] = None
    date: Optional[str] = None
    transaction_date: Optional[str] = None
    currency: Optional[str] = "INR"
    payment_method: Optional[str] = None
    items: list[ExtractedItem] = []
    category_suggestion: Optional[str] = None
    suggested_category: Optional[str] = None
    suggested_category_id: Optional[UUID] = None
    reference_number: Optional[str] = None
    payment_status: str = "success"
    payment_direction: str = "debit"
    confidence: float = 0.0   # 0.0–1.0 overall
    field_confidences: dict[str, float] = {}
    validation_flags: list[str] = []

    @field_serializer("amount", "tax_amount", when_used="json")
    def serialize_amounts(self, v: Optional[Decimal]) -> Optional[float]:
        return float(v) if v is not None else None
