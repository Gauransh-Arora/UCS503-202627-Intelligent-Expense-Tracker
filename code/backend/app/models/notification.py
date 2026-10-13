"""Notification model — in-app notifications for debts, alerts, and recurring bills."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import relationship

from app.database import Base


class NotificationType(str, enum.Enum):
    SPLIT_DEBT = "split_debt"
    SETTLEMENT = "settlement"
    UNUSUAL_SPENDING = "unusual_spending"
    RECURRING_DUE = "recurring_due"
    SUBSCRIPTION_ALERT = "subscription_alert"
    WISHLIST_UPDATE = "wishlist_update"
    SYSTEM = "system"


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    notification_type = Column(String(50), default=NotificationType.SYSTEM.value, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="notifications")

    def __repr__(self) -> str:
        return f"<Notification id={self.id} type={self.notification_type} title={self.title}>"
