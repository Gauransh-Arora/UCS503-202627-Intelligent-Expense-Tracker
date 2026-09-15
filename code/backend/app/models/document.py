"""Document model — stores uploaded receipts, bills, UPI screenshots, bank statements."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base

import enum


class DocumentType(str, enum.Enum):
    RECEIPT = "receipt"
    BILL = "bill"
    UPI_SCREENSHOT = "upi_screenshot"
    BANK_STATEMENT = "bank_statement"
    OTHER = "other"


class ProcessingStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class Document(Base):
    __tablename__ = "documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # File info
    original_filename = Column(String(255), nullable=False)
    stored_filename = Column(String(255), nullable=False)  # UUID-based safe name
    file_path = Column(String(500), nullable=False)
    file_size = Column(String(50), nullable=True)
    mime_type = Column(String(100), nullable=True)

    # Document classification
    document_type = Column(Enum(DocumentType), default=DocumentType.RECEIPT, nullable=False)

    # OCR results
    ocr_raw_text = Column(Text, nullable=True)
    processing_status = Column(Enum(ProcessingStatus), default=ProcessingStatus.PENDING, nullable=False)
    processing_error = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    processed_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="documents")
    transactions = relationship("Transaction", back_populates="document")

    def __repr__(self) -> str:
        return f"<Document id={self.id} type={self.document_type} status={self.processing_status}>"
