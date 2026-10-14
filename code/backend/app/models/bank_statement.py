"""Bank Statement models — per-user uploaded PDF/CSV statements with parsed rows."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.database import Base


class StatementStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    PARSING = "parsing"
    PARSED = "parsed"
    FAILED = "failed"


class BankStatement(Base):
    """Stores a single uploaded bank statement for a user."""

    __tablename__ = "bank_statements"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # File metadata
    original_filename = Column(Text, nullable=False)
    file_url = Column(Text, nullable=False)
    mime_type = Column(String(100), nullable=True)

    # Bank / account info extracted from the statement
    bank_name = Column(String(255), nullable=True)
    account_number = Column(String(50), nullable=True)  # last-4 only
    statement_period_from = Column(String(20), nullable=True)  # YYYY-MM-DD
    statement_period_to = Column(String(20), nullable=True)    # YYYY-MM-DD

    # Parsing results
    status = Column(String(30), default=StatementStatus.UPLOADED.value, nullable=False)
    raw_text = Column(Text, nullable=True)
    total_transactions = Column(Integer, default=0, nullable=False)
    total_debits = Column(Float, default=0.0, nullable=False)
    total_credits = Column(Float, default=0.0, nullable=False)

    # Parsed rows stored as JSON list — each row: {date, description, debit, credit, balance}
    parsed_rows = Column(JSON, nullable=True)

    error_message = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="bank_statements")

    def __repr__(self) -> str:
        return (
            f"<BankStatement id={self.id} bank={self.bank_name} "
            f"status={self.status} rows={self.total_transactions}>"
        )
