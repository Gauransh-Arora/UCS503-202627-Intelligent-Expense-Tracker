"""BudgetPlan router — monthly limits, savings goals, and available budget."""
from decimal import Decimal
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.budget_plan import BudgetPlan
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.budget import BudgetPlanCreate, BudgetPlanResponse, BudgetPlanUpdate
from app.utils.auth import get_current_user

router = APIRouter(prefix="/budgets", tags=["Budgets"])


def _compute_month_spending(user_id: uuid.UUID, month_str: str, db: Session) -> Decimal:
    """Calculate actual spending for given 'YYYY-MM'."""
    try:
        y, m = map(int, month_str.split("-"))
    except ValueError:
        return Decimal("0.00")

    total = (
        db.query(func.sum(Transaction.amount))
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            extract("year", Transaction.transaction_date) == y,
            extract("month", Transaction.transaction_date) == m,
        )
        .scalar()
    )
    return Decimal(str(total or "0.00"))


@router.post("/", response_model=BudgetPlanResponse, status_code=status.HTTP_201_CREATED)
def create_or_update_budget_plan(
    plan_in: BudgetPlanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create or update monthly budget plan (spending limit and savings goal)."""
    plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == current_user.id,
            BudgetPlan.month == plan_in.month,
        )
        .first()
    )

    if plan:
        plan.update_limits(plan_in.spending_limit, plan_in.savings_goal)
    else:
        plan = BudgetPlan(
            user_id=current_user.id,
            month=plan_in.month,
            spending_limit=plan_in.spending_limit,
            savings_goal=plan_in.savings_goal,
        )
        db.add(plan)

    db.commit()
    db.refresh(plan)

    spent = _compute_month_spending(current_user.id, plan.month, db)
    avail = plan.available_budget(spent)

    resp = BudgetPlanResponse.model_validate(plan)
    resp.current_spending = spent
    resp.available_budget = avail
    return resp


@router.get("/", response_model=list[BudgetPlanResponse])
def list_budget_plans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all budget plans for the authenticated user."""
    plans = (
        db.query(BudgetPlan)
        .filter(BudgetPlan.user_id == current_user.id)
        .order_by(BudgetPlan.month.desc())
        .all()
    )

    results = []
    for p in plans:
        spent = _compute_month_spending(current_user.id, p.month, db)
        r = BudgetPlanResponse.model_validate(p)
        r.current_spending = spent
        r.available_budget = p.available_budget(spent)
        results.append(r)
    return results


@router.get("/available")
def get_available_budget(
    month: Optional[str | int] = None,
    year: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Calculate target budget vs actual spending tracking and available discretionary budget."""
    from datetime import date as dt_date
    today = dt_date.today()
    if year is None:
        year = today.year
    if month is None:
        month = today.month

    if isinstance(month, int) or (isinstance(month, str) and month.isdigit()):
        month_str = f"{year:04d}-{int(month):02d}"
    else:
        month_str = str(month)

    plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == current_user.id,
            BudgetPlan.month == month_str,
        )
        .first()
    )

    spent = _compute_month_spending(current_user.id, month_str, db)
    spending_limit = plan.spending_limit if plan else Decimal("0.00")
    savings_goal = plan.savings_goal if plan else Decimal("0.00")
    avail = plan.available_budget(spent) if plan else Decimal("0.00")

    pct_used = float(spent / spending_limit * 100) if spending_limit > 0 else 0.0
    is_overspent = spent > spending_limit if spending_limit > 0 else False
    warning = pct_used >= 80.0

    return {
        "month": month_str,
        "spending_limit": float(spending_limit),
        "savings_goal": float(savings_goal),
        "spent_so_far": float(spent),
        "current_spending": float(spent),
        "available_budget": float(avail),
        "percentage_used": round(pct_used, 2),
        "is_overspent": is_overspent,
        "warning_triggered": warning,
    }


@router.get("/{month}", response_model=BudgetPlanResponse)
def get_budget_plan(
    month: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get budget plan for a specific month (e.g. '2026-10')."""
    plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == current_user.id,
            BudgetPlan.month == month,
        )
        .first()
    )
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Budget plan for {month} not found",
        )

    spent = _compute_month_spending(current_user.id, plan.month, db)
    r = BudgetPlanResponse.model_validate(plan)
    r.current_spending = spent
    r.available_budget = plan.available_budget(spent)
    return r


@router.put("/{month}", response_model=BudgetPlanResponse)
def update_budget_plan(
    month: str,
    update_in: BudgetPlanUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update spending limit or savings goal for a month."""
    plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == current_user.id,
            BudgetPlan.month == month,
        )
        .first()
    )
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Budget plan for {month} not found",
        )

    if update_in.spending_limit is not None:
        plan.spending_limit = update_in.spending_limit
    if update_in.savings_goal is not None:
        plan.savings_goal = update_in.savings_goal

    db.commit()
    db.refresh(plan)

    spent = _compute_month_spending(current_user.id, plan.month, db)
    r = BudgetPlanResponse.model_validate(plan)
    r.current_spending = spent
    r.available_budget = plan.available_budget(spent)
    return r


@router.delete("/{month}", status_code=status.HTTP_204_NO_CONTENT)
def delete_budget_plan(
    month: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete budget plan for a month."""
    plan = (
        db.query(BudgetPlan)
        .filter(
            BudgetPlan.user_id == current_user.id,
            BudgetPlan.month == month,
        )
        .first()
    )
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Budget plan for {month} not found",
        )

    db.delete(plan)
    db.commit()
