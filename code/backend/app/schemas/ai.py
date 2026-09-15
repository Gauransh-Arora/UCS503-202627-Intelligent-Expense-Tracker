"""AI / Natural Language query schemas."""
from typing import Optional
from pydantic import BaseModel


class NLQueryRequest(BaseModel):
    question: str   # "How much did I spend on food last month?"


class NLQueryResponse(BaseModel):
    question: str
    answer: str                         # Human-readable answer
    data: Optional[dict] = None         # Structured data (amounts, lists, etc.)
    query_type: Optional[str] = None    # "spending_by_category", "top_merchant", etc.
    period: Optional[str] = None        # "last_month", "this_year", etc.
