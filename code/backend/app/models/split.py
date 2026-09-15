"""Expense splitting models — splits, participants, and settlements."""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class SplitType(str, enum.Enum):
    EQUAL = "equal"
    PERCENTAGE = "percentage"
    CUSTOM = "custom"


class SettlementStatus(str, enum.Enum):
    PENDING = "pending"
    SETTLED = "settled"


class ExpenseSplit(Base):
    """A group expense that is split among participants."""
    __tablename__ = "expense_splits"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    total_amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR", nullable=False)
    split_type = Column(Enum(SplitType), default=SplitType.EQUAL, nullable=False)
    description = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    created_by_user = relationship("User", back_populates="splits_created")
    participants = relationship("SplitParticipant", back_populates="split", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<ExpenseSplit id={self.id} title={self.title} amount={self.total_amount}>"


class SplitParticipant(Base):
    """One person's share in an expense split."""
    __tablename__ = "split_participants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    split_id = Column(UUID(as_uuid=True), ForeignKey("expense_splits.id", ondelete="CASCADE"), nullable=False, index=True)
    transaction_id = Column(UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True)

    # Participant info — may or may not be a registered user
    participant_name = Column(String(255), nullable=False)
    participant_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    amount_owed = Column(Float, nullable=False)
    percentage = Column(Float, nullable=True)  # used when split_type = PERCENTAGE
    is_payer = Column(Boolean, default=False, nullable=False)  # who originally paid

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    split = relationship("ExpenseSplit", back_populates="participants")
    transaction = relationship("Transaction", back_populates="split_participants")

    def __repr__(self) -> str:
        return f"<SplitParticipant name={self.participant_name} owes={self.amount_owed}>"


class Settlement(Base):
    """Records when a participant settles their debt."""
    __tablename__ = "settlements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    split_id = Column(UUID(as_uuid=True), ForeignKey("expense_splits.id", ondelete="CASCADE"), nullable=False, index=True)
    payer_name = Column(String(255), nullable=False)
    payee_name = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(Enum(SettlementStatus), default=SettlementStatus.PENDING, nullable=False)
    settled_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<Settlement {self.payer_name} → {self.payee_name} ₹{self.amount} [{self.status}]>"
