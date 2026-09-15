"""RecurringExpense model — detected or manually added recurring transactions."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Frequency(str, enum.Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    YEARLY = "yearly"


class RecurringExpense(Base):
    __tablename__ = "recurring_expenses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)

    merchant_name = Column(String(255), nullable=False)
    average_amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    frequency = Column(Enum(Frequency), nullable=False)
    typical_day = Column(Integer, nullable=True)  # day of month (1–31) for monthly

    # Detection metadata
    confidence = Column(Float, nullable=True)  # 0–100 (system-detected)
    is_user_confirmed = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    detected_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="recurring_expenses")
    category = relationship("Category", back_populates="recurring_expenses")

    def __repr__(self) -> str:
        return f"<RecurringExpense merchant={self.merchant_name} freq={self.frequency} avg={self.average_amount}>"
