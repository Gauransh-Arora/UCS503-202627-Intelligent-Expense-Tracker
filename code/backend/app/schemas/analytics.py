"""Analytics Pydantic schemas."""
from typing import Optional
from pydantic import BaseModel


class CategoryBreakdown(BaseModel):
    category_name: str
    category_icon: Optional[str]
    total_amount: float
    transaction_count: int
    percentage: float  # of total spending


class MerchantSummary(BaseModel):
    merchant_name: str
    total_amount: float
    transaction_count: int
    last_transaction_date: Optional[str]


class SpendingTrend(BaseModel):
    month: str   # "YYYY-MM"
    total_amount: float
    transaction_count: int


class MonthlySummary(BaseModel):
    month: str   # "YYYY-MM"
    total_spending: float
    transaction_count: int
    avg_daily_spending: float
    top_category: Optional[str]
    top_merchant: Optional[str]
    categories: list[CategoryBreakdown] = []


class AnalyticsSummary(BaseModel):
    """High-level summary for the dashboard."""
    current_month_spending: float
    previous_month_spending: float
    month_over_month_change_pct: float
    avg_monthly_spending: float
    total_transactions: int
    top_categories: list[CategoryBreakdown] = []
    top_merchants: list[MerchantSummary] = []
    spending_trend: list[SpendingTrend] = []
    unusual_spending_alerts: list[str] = []
