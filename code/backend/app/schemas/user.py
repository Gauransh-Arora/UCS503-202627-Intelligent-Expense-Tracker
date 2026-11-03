"""User Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, field_validator


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    monthly_income: Optional[float] = 60000.0

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    monthly_income: Optional[float] = None

    @field_validator("monthly_income")
    @classmethod
    def validate_income(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError("Monthly income cannot be negative")
        return v


class UserResponse(BaseModel):
    id: UUID
    name: str
    email: str
    is_active: bool
    monthly_income: Optional[float] = 60000.0
    avatar_url: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenData(BaseModel):
    user_id: UUID | None = None


class AccountDeleteResponse(BaseModel):
    message: str = "Account and all associated data deleted successfully"
