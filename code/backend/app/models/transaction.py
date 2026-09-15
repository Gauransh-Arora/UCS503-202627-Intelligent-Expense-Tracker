"""Transaction and TransactionItem models — the core expense tables."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    UPI = "upi"
    CARD = "card"
    NET_BANKING = "net_banking"
    WALLET = "wallet"
    OTHER = "other"


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"       # OCR result awaiting user confirmation
    VERIFIED = "verified"     # User confirmed
    AUTO = "auto"             # Manually entered — no OCR


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)
    document_id = Column(UUID(as_uuid=True), ForeignKey("documents.id", ondelete="SET NULL"), nullable=True)

    # Core fields
    merchant_name = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    transaction_date = Column(Date, nullable=False)
    payment_method = Column(Enum(PaymentMethod), default=PaymentMethod.UPI, nullable=False)
    description = Column(Text, nullable=True)

    # OCR / AI
    verification_status = Column(Enum(VerificationStatus), default=VerificationStatus.AUTO, nullable=False)
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

    # Relationships
    user = relationship("User", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")
    document = relationship("Document", back_populates="transactions")
    items = relationship("TransactionItem", back_populates="transaction", cascade="all, delete-orphan")
    split_participants = relationship("SplitParticipant", back_populates="transaction")

    def __repr__(self) -> str:
        return f"<Transaction id={self.id} merchant={self.merchant_name} amount={self.amount}>"


class TransactionItem(Base):
    """Individual line items within a bill (e.g. Domino's: Pizza ₹300, Coke ₹60)."""
    __tablename__ = "transaction_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transaction_id = Column(UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False, index=True)

    item_name = Column(String(255), nullable=False)
    quantity = Column(Integer, default=1, nullable=False)
    unit_price = Column(Float, nullable=False)
    total_price = Column(Float, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    transaction = relationship("Transaction", back_populates="items")

    def __repr__(self) -> str:
        return f"<TransactionItem name={self.item_name} total={self.total_price}>"
