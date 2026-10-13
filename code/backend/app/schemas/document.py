"""Document Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from app.models.document import DocumentType, ProcessingStatus


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
    unit_price: float
    total_price: float


class OCRResult(BaseModel):
    """Structured data extracted from OCR raw text."""
    document_id: UUID
    raw_text: str
    merchant_name: Optional[str] = None
    amount: Optional[float] = None
    tax_amount: Optional[float] = None
    date: Optional[str] = None
    items: list[ExtractedItem] = []
    category_suggestion: Optional[str] = None
    confidence: float = 0.0   # 0.0–1.0
