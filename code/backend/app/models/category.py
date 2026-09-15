"""Category model."""
import uuid

from sqlalchemy import Boolean, Column, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base

# Default categories seeded on startup
DEFAULT_CATEGORIES = [
    ("Food", "🍔"),
    ("Groceries", "🛒"),
    ("Transport", "🚗"),
    ("Shopping", "🛍️"),
    ("Entertainment", "🎬"),
    ("Bills", "📄"),
    ("Healthcare", "💊"),
    ("Education", "📚"),
    ("Travel", "✈️"),
    ("Rent", "🏠"),
    ("Subscriptions", "🔄"),
    ("Other", "📦"),
]


class Category(Base):
    __tablename__ = "categories"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False, index=True)
    icon = Column(String(10), nullable=True)
    is_default = Column(Boolean, default=True, nullable=False)

    # Relationships
    transactions = relationship("Transaction", back_populates="category")
    preferences = relationship("UserCategoryPreference", back_populates="category")
    recurring_expenses = relationship("RecurringExpense", back_populates="category")

    def __repr__(self) -> str:
        return f"<Category name={self.name}>"
