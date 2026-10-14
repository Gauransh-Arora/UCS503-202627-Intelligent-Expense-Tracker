"""Pydantic schemas for Bank Statement endpoints."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel


class BankStatementRow(BaseModel):
    """A single parsed transaction row from a bank statement."""
    date: str                           # YYYY-MM-DD
    description: str
    debit: Optional[float] = None
    credit: Optional[float] = None
    balance: Optional[float] = None
    category: Optional[str] = None


class BankStatementUploadResponse(BaseModel):
    """Returned immediately after a statement is uploaded (before parsing)."""
    id: UUID
    user_id: UUID
    original_filename: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class BankStatementResponse(BaseModel):
    """Full statement details including parsed rows."""
    id: UUID
    user_id: UUID
    original_filename: str
    mime_type: Optional[str] = None
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    statement_period_from: Optional[str] = None
    statement_period_to: Optional[str] = None
    status: str
    total_transactions: int
    total_debits: float
    total_credits: float
    parsed_rows: Optional[list[dict[str, Any]]] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BankStatementSummary(BaseModel):
    """Lightweight list-item (no rows payload)."""
    id: UUID
    original_filename: str
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    statement_period_from: Optional[str] = None
    statement_period_to: Optional[str] = None
    status: str
    total_transactions: int
    total_debits: float
    total_credits: float
    created_at: datetime

    model_config = {"from_attributes": True}
