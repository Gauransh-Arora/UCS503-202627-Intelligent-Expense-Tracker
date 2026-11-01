"""Application configuration settings."""
from pathlib import Path
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application runtime configuration."""

    # Core Database
    DATABASE_URL: str = "sqlite:///./expenses.db"

    # File uploads
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_MIME_TYPES: list[str] = [
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "application/pdf",
        "text/csv",
    ]

    # Locale & Currency
    DEFAULT_CURRENCY: str = "INR"
    DEFAULT_LOCALE: str = "en_IN"

    # Extraction Settings (Multimodal Vision LLM)
    EXTRACTION_PROVIDER: str = "gemini"
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-3.5-flash-lite"

    # Recurring Detection Tolerances
    RECURRING_AMOUNT_TOLERANCE_PCT: float = 0.15
    RECURRING_INTERVAL_TOLERANCE_DAYS: int = 4

    # Unusual Spending Detection (Statistical Rule: Mean ± k*σ or Median/MAD)
    UNUSUAL_SPENDING_SENSITIVITY_K: float = 2.0
    MIN_HISTORY_MONTHS_FOR_ANOMALY: int = 2
    MIN_TRANSACTIONS_FOR_ANOMALY: int = 5

    # Wishlist & Discretionary Budget
    READINESS_COMFORTABLE_RATIO: float = 0.50
    READINESS_POSSIBLE_RATIO: float = 1.00

    # JWT Authentication
    SECRET_KEY: str = Field(
        default="intelligent-expense-tracker-dev-secret-key-change-in-production-2026",
        description="HMAC secret key for JWT token encoding/decoding",
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    model_config = SettingsConfigDict(
        env_file=str(Path(__file__).resolve().parent.parent / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
