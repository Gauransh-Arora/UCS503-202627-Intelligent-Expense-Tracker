"""User model."""
from decimal import Decimal
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Numeric, String, Uuid
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    monthly_income = Column(Numeric(12, 2), default=Decimal("60000.00"), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
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
    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="user", cascade="all, delete-orphan")
    wishlist_items = relationship("WishlistItem", back_populates="user", cascade="all, delete-orphan")
    recurring_expenses = relationship("RecurringExpense", back_populates="user", cascade="all, delete-orphan")
    category_preferences = relationship("UserCategoryPreference", back_populates="user", cascade="all, delete-orphan")
    splits_created = relationship("ExpenseSplit", back_populates="created_by_user", cascade="all, delete-orphan")
    settlements = relationship("Settlement", cascade="all, delete-orphan")
    friends = relationship("Friend", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    bank_statements = relationship("BankStatement", back_populates="user", cascade="all, delete-orphan")
    budget_plans = relationship("BudgetPlan", back_populates="user", cascade="all, delete-orphan")

    def authenticate(self, password: str) -> bool:
        """Verify given plaintext password against stored password hash."""
        from app.utils.security import verify_password
        return verify_password(password, self.password_hash)

    def update_profile(
        self,
        name: str | None = None,
        email: str | None = None,
        monthly_income: Decimal | float | int | str | None = None,
    ) -> None:
        """Update user profile information."""
        if name:
            self.name = name.strip()
        if email:
            self.email = email.lower().strip()
        if monthly_income is not None:
            self.monthly_income = Decimal(str(monthly_income))

    @property
    def avatar_url(self) -> str:
        import urllib.parse
        seed = urllib.parse.quote((self.email or str(self.id)).strip().lower())
        return f"https://api.dicebear.com/10.x/voxel-art/svg?seed={seed}&backgroundColor=00000000"

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email} income={self.monthly_income}>"
