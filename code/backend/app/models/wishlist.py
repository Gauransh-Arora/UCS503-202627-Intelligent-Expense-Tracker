"""WishlistItem model — tracks desired purchases with readiness scoring."""
from decimal import Decimal
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Numeric, String, Text, Uuid
from sqlalchemy.orm import relationship

from app.database import Base


class WishlistItem(Base):
    __tablename__ = "wishlist_items"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    expected_price = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    description = Column(Text, nullable=True)
    priority = Column(String(20), default="medium", nullable=False)  # low, medium, high
    url = Column(String(500), nullable=True)

    # Computed fields (updated by intelligence_service)
    purchase_readiness = Column(Float, nullable=True)   # 0–100
    estimated_months = Column(Float, nullable=True)     # months until affordable
    verdict = Column(String(50), nullable=True)         # "Comfortable", "Possible", "Not Recommended Currently"
    discretionary_budget = Column(Numeric(12, 2), nullable=True)
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

    def update_price(self, new_price: Decimal | float | int | str) -> None:
        """Update expected purchase price."""
        self.expected_price = Decimal(str(new_price))

    def check_readiness(self, db) -> dict:
        """Evaluate purchase readiness using intelligence service."""
        from app.services.intelligence_service import calculate_purchase_readiness
        res = calculate_purchase_readiness(self, self.user_id, db)
        return res.model_dump()

    def __repr__(self) -> str:
        return f"<WishlistItem name={self.name} price={self.expected_price} readiness={self.purchase_readiness}>"
