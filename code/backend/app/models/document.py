"""Document model — stores uploaded receipts, bills, UPI screenshots, bank statements."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Enum, ForeignKey, String, Text, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base

import enum


class DocumentType(str, enum.Enum):
    RECEIPT = "receipt"
    BILL = "bill"
    UPI_SCREENSHOT = "upi_screenshot"
    BANK_STATEMENT = "bank_statement"


class ProcessingStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    PROCESSING = "processing"
    PROCESSED = "processed"
    VERIFIED = "verified"
    FAILED = "failed"


class Document(Base):
    __tablename__ = "documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # File info
    original_filename = Column(Text, nullable=True)
    file_url = Column(Text, nullable=True)
    mime_type = Column(String(100), nullable=True)

    # Document classification
    document_type = Column(String(50), default="receipt", nullable=False)

    # OCR results
    ocr_text = Column(Text, nullable=True)
    processing_status = Column(String(50), default="pending", nullable=False)
    ocr_confidence = Column(Float, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="documents")
    transactions = relationship("Transaction", back_populates="document")

    def __repr__(self) -> str:
        return f"<Document id={self.id} type={self.document_type} status={self.processing_status}>"
