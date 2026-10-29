"""Transaction and TransactionItem models — the core expense tables."""
import enum
import uuid
from datetime import date as dt_date, datetime, timezone

from decimal import Decimal
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship, synonym

from app.database import Base


class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    UPI = "upi"
    CARD = "card"
    NET_BANKING = "bank"
    WALLET = "wallet"
    OTHER = "other"


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"       # OCR result awaiting user confirmation
    VERIFIED = "verified"     # User confirmed
    AUTO = "auto"             # Manually entered — no OCR
    DISCARDED = "discarded"   # User rejected draft
    CONFIRMED = "verified"    # Spec alias
    DRAFT = "pending"         # Spec alias


# Semantic alias for specification
TransactionStatus = VerificationStatus


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(Uuid, ForeignKey("categories.id"), nullable=True)
    document_id = Column(Uuid, ForeignKey("documents.id", ondelete="SET NULL"), nullable=True)

    # Core fields
    transaction_type = Column(String(50), default="expense", nullable=False)
    is_verified = Column(Boolean, default=True, nullable=False)
    merchant_name = Column(String(255), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    transaction_date = Column(Date, nullable=False)
    payment_method = Column(String(50), default="upi", nullable=False)
    description = Column(Text, nullable=True)

    # OCR / AI
    verification_status = Column(String(50), default="auto", nullable=False)
    ocr_confidence = Column(Float, nullable=True)  # 0.0 – 1.0

    # Categorization
    auto_categorized = Column(Boolean, default=False, nullable=False)

    # Soft delete
    is_deleted = Column(Boolean, default=False, nullable=False)

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

    # Specification compatibility synonyms
    status = synonym("verification_status")
    merchant = synonym("merchant_name")
    date = synonym("transaction_date")
    notes = synonym("description")

    # Relationships
    user = relationship("User", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")
    document = relationship("Document", back_populates="transactions")
    items = relationship("TransactionItem", back_populates="transaction", cascade="all, delete-orphan")
    split_participants = relationship("SplitParticipant", back_populates="transaction")

    @property
    def category_name(self) -> str | None:
        """Name of the associated category, if available."""
        return self.category.name if self.category else None

    def validate_required(self) -> bool:
        """Validate required transaction fields."""
        if not self.merchant_name or not self.merchant_name.strip():
            return False
        if self.amount is None or Decimal(str(self.amount)) <= Decimal("0.00"):
            return False
        if not self.transaction_date:
            return False
        return True

    def confirm(self) -> None:
        """Confirm a draft transaction into permanently stored expense."""
        self.is_verified = True
        self.verification_status = VerificationStatus.VERIFIED.value

    def update_details(
        self,
        merchant_name: str | None = None,
        amount: Decimal | float | int | str | None = None,
        category_id: uuid.UUID | None = None,
        transaction_date: dt_date | None = None,
        description: str | None = None,
    ) -> None:
        """Update transaction details."""
        if merchant_name is not None:
            self.merchant_name = merchant_name.strip()
        if amount is not None:
            self.amount = Decimal(str(amount))
        if category_id is not None:
            self.category_id = category_id
        if transaction_date is not None:
            self.transaction_date = transaction_date
        if description is not None:
            self.description = description

    def __repr__(self) -> str:
        return f"<Transaction id={self.id} merchant={self.merchant_name} amount={self.amount}>"


class TransactionItem(Base):
    """Individual line items within a bill (e.g. Domino's: Pizza ₹300, Coke ₹60)."""
    __tablename__ = "transaction_items"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    transaction_id = Column(Uuid, ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    quantity = Column(Integer, default=1, nullable=False)
    unit_price = Column(Numeric(12, 2), nullable=True)
    total_price = Column(Numeric(12, 2), nullable=False)
    category_id = Column(Uuid, ForeignKey("categories.id"), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    transaction = relationship("Transaction", back_populates="items")

    def subtotal(self) -> Decimal:
        """Calculate line item subtotal."""
        if self.total_price is not None:
            return Decimal(str(self.total_price))
        if self.unit_price is not None:
            return Decimal(str(self.unit_price)) * Decimal(self.quantity or 1)
        return Decimal("0.00")

    def __repr__(self) -> str:
        return f"<TransactionItem name={self.name} total={self.total_price}>"
