"""Document model — represents uploaded receipts, bills, and statements."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import relationship

from app.database import Base


class DocumentType(str, enum.Enum):
    RECEIPT = "receipt"
    BILL = "bill"
    UPI_SCREENSHOT = "upi_screenshot"
    BANK_STATEMENT = "bank_statement"


class ProcessingStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    PROCESSING = "processing"
    PROCESSED = "processed"
    FAILED = "failed"
    CONFIRMED = "confirmed"
    DISCARDED = "discarded"


class Document(Base):
    """An uploaded document file belonging to a user."""
    __tablename__ = "documents"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    original_filename = Column(String(255), nullable=False)
    file_url = Column(String(512), nullable=False)
    mime_type = Column(String(100), default="image/jpeg", nullable=True)
    document_type = Column(String(50), default="receipt", nullable=False)

    # Parsing results
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
        """Run Vision LLM and extract candidate transaction draft fields."""
        from app.services.vision_service import is_vision_available, parse_receipt_with_vision

        if not self.file_url:
            raise ValueError("No file URL associated with this document.")
        if is_vision_available():
            parsed = parse_receipt_with_vision(self.file_url) or {}
            self.ocr_text = parsed.get("raw_text") or ""
            self.ocr_confidence = parsed.get("confidence", 0.95)
            self.processing_status = ProcessingStatus.PROCESSED.value
            return parsed
        return {}

    def get_confidence(self) -> float:
        """Return overall confidence score (0.0 to 1.0)."""
        return float(self.ocr_confidence or 0.0)

    def __repr__(self) -> str:
        return f"<Document id={self.id} type={self.document_type} status={self.processing_status}>"
