"""Expense splitting models — splits, participants, and settlements."""
from decimal import Decimal
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Numeric, String, Text, Uuid
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

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    created_by = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    total_amount = Column(Numeric(12, 2), nullable=False)
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

    def validate_total(self) -> bool:
        """Validate that all participant shares sum exactly to total_amount."""
        total_shares = sum(
            Decimal(str(p.amount_owed))
            for p in self.participants
        )
        return total_shares == Decimal(str(self.total_amount))

    def confirm(self) -> bool:
        """Confirm split after validating total."""
        return self.validate_total()

    def __repr__(self) -> str:
        return f"<ExpenseSplit id={self.id} title={self.title} amount={self.total_amount}>"


class SplitParticipant(Base):
    """One person's share in an expense split."""
    __tablename__ = "split_participants"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    split_id = Column(Uuid, ForeignKey("expense_splits.id", ondelete="CASCADE"), nullable=False, index=True)
    transaction_id = Column(Uuid, ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True)

    # Participant info — may or may not be a registered user or saved friend
    participant_name = Column(String(255), nullable=False)
    participant_user_id = Column(Uuid, ForeignKey("users.id"), nullable=True)
    friend_id = Column(Uuid, ForeignKey("friends.id", ondelete="SET NULL"), nullable=True)

    amount_owed = Column(Numeric(12, 2), nullable=False)
    amount_settled = Column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    percentage = Column(Numeric(5, 2), nullable=True)  # used when split_type = PERCENTAGE
    is_payer = Column(Boolean, default=False, nullable=False)  # who originally paid

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    split = relationship("ExpenseSplit", back_populates="participants")
    transaction = relationship("Transaction", back_populates="split_participants")

    def outstanding_amount(self) -> Decimal:
        """Calculate outstanding owed amount after settlements."""
        owed = Decimal(str(self.amount_owed))
        settled = Decimal(str(self.amount_settled or "0.00"))
        return max(Decimal("0.00"), owed - settled)

    def record_settlement(self, amount: Decimal | float | int | str) -> Decimal:
        """Record partial or full settlement towards this share."""
        settle_amt = Decimal(str(amount))
        curr_settled = Decimal(str(self.amount_settled or "0.00"))
        self.amount_settled = curr_settled + settle_amt
        return self.outstanding_amount()

    def __repr__(self) -> str:
        return f"<SplitParticipant name={self.participant_name} owes={self.amount_owed} settled={self.amount_settled}>"


class Settlement(Base):
    """Records when a participant settles their debt."""
    __tablename__ = "settlements"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    split_id = Column(Uuid, ForeignKey("expense_splits.id", ondelete="CASCADE"), nullable=True, index=True)
    payer_name = Column(String(255), nullable=False)
    payee_name = Column(String(255), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    status = Column(Enum(SettlementStatus), default=SettlementStatus.SETTLED, nullable=False)
    settled_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<Settlement {self.payer_name} → {self.payee_name} ₹{self.amount} [{self.status}]>"
