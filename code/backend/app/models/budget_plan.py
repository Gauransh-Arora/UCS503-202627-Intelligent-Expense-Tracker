"""BudgetPlan model — tracks monthly spending limits and savings goals."""
from decimal import Decimal
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Numeric, String, Uuid, UniqueConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class BudgetPlan(Base):
    """
    Monthly budget plan defining spending limits and savings targets.
    Month format: 'YYYY-MM' (e.g. '2026-10').
    """
    __tablename__ = "budget_plans"
    __table_args__ = (
        UniqueConstraint("user_id", "month", name="uq_user_budget_month"),
    )

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    month = Column(String(7), nullable=False, index=True)  # YYYY-MM
    spending_limit = Column(Numeric(12, 2), nullable=False)
    savings_goal = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))

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
    user = relationship("User", back_populates="budget_plans")

    def update_limits(
        self,
        spending_limit: Decimal | float | int | str,
        savings_goal: Decimal | float | int | str | None = None,
    ) -> None:
        """Update spending limit and savings goal."""
        self.spending_limit = Decimal(str(spending_limit))
        if savings_goal is not None:
            self.savings_goal = Decimal(str(savings_goal))

    def available_budget(self, current_spending: Decimal | float | int | str) -> Decimal:
        """Calculate remaining budget after current spending and savings allocation."""
        spent = Decimal(str(current_spending))
        # Available budget is spending limit minus current spending
        return max(Decimal("0.00"), Decimal(str(self.spending_limit)) - spent)

    def __repr__(self) -> str:
        return f"<BudgetPlan month={self.month} limit={self.spending_limit} savings={self.savings_goal}>"
