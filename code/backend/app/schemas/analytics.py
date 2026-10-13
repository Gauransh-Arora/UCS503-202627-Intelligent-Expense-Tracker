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


class ItemSpendingSummary(BaseModel):
    item_name: str
    total_amount: float
    total_quantity: int
    avg_unit_price: float
    transaction_count: int


class CategoryComparisonItem(BaseModel):
    category_name: str
    current_amount: float
    previous_amount: float
    difference_amount: float
    percentage_change: float


class MonthlyComparison(BaseModel):
    current_month: str
    current_total: float
    current_count: int
    previous_month: str
    previous_total: float
    previous_count: int
    difference_amount: float
    percentage_change: float
    verdict: str
    category_comparison: list[CategoryComparisonItem] = []


class SpendingSummaryResponse(BaseModel):
    summary_text: str
    period: str
    total_spent: float
    transaction_count: int
    top_category: Optional[str] = None
    top_merchant: Optional[str] = None
    key_insights: list[str] = []
