"""Document Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from app.models.document import DocumentType, ProcessingStatus


class DocumentResponse(BaseModel):
    id: UUID
    user_id: UUID
    original_filename: str
    file_size: Optional[str]
    mime_type: Optional[str]
    document_type: DocumentType
    processing_status: ProcessingStatus
    ocr_raw_text: Optional[str]
    processing_error: Optional[str]
    created_at: datetime
    processed_at: Optional[datetime]

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
