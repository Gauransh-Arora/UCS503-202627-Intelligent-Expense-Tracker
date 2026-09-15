"""WishlistItem model — tracks desired purchases with readiness scoring."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class WishlistItem(Base):
    __tablename__ = "wishlist_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    expected_price = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    description = Column(Text, nullable=True)
    priority = Column(String(20), default="medium", nullable=False)  # low, medium, high
    url = Column(String(500), nullable=True)

    # Computed fields (updated by intelligence_service)
    purchase_readiness = Column(Float, nullable=True)   # 0–100
    estimated_months = Column(Float, nullable=True)     # months until affordable
    is_purchased = Column(Boolean, default=False, nullable=False)

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
    user = relationship("User", back_populates="wishlist_items")

    def __repr__(self) -> str:
        return f"<WishlistItem name={self.name} price={self.expected_price} readiness={self.purchase_readiness}>"
