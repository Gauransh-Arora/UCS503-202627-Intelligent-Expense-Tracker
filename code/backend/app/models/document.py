"""Document model — stores uploaded receipts, bills, UPI screenshots, bank statements."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Enum, ForeignKey, String, Text, Float, Uuid
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

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

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

    def extract_or_parse(self) -> dict:
        """Run OCR and extract candidate transaction draft fields."""
        from app.services.ocr_service import run_ocr
        from app.services.extraction_service import extract_transaction_data

        if not self.file_url:
            raise ValueError("No file URL associated with this document.")
        raw_text = run_ocr(self.file_url)
        self.ocr_text = raw_text
        parsed = extract_transaction_data(raw_text)
        self.ocr_confidence = parsed.get("confidence", 0.0)
        self.processing_status = ProcessingStatus.PROCESSED.value
        return parsed

    def get_confidence(self) -> float:
        """Return overall OCR confidence score (0.0 to 1.0)."""
        return float(self.ocr_confidence or 0.0)

    def __repr__(self) -> str:
        return f"<Document id={self.id} type={self.document_type} status={self.processing_status}>"
