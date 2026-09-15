"""UserCategoryPreference model — remembers user-corrected categorizations."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class UserCategoryPreference(Base):
    """
    When a user corrects the auto-categorization (e.g. Amazon → Groceries),
    this table remembers the mapping so future transactions match correctly.
    """
    __tablename__ = "user_category_preferences"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=False)

    # The merchant keyword that triggered this preference
    merchant_keyword = Column(String(255), nullable=False, index=True)
    usage_count = Column(Integer, default=1, nullable=False)  # how often this rule fired

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
    user = relationship("User", back_populates="category_preferences")
    category = relationship("Category", back_populates="preferences")

    def __repr__(self) -> str:
        return f"<UserCategoryPreference keyword={self.merchant_keyword} → category={self.category_id}>"
