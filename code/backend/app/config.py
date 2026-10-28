"""
Application configuration using pydantic-settings.
All values are loaded from the .env file.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "sqlite:///./expenses.db"

    # JWT
    SECRET_KEY: str = "change-me-in-production-use-a-long-random-secret"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # File uploads
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_SIZE_MB: int = 15
    SUPPORTED_MIME_TYPES: list[str] = [
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

    # OCR & Extraction
    OCR_PROVIDER: str = "paddleocr"
    OCR_CONFIDENCE_THRESHOLD: float = 0.60

    # Recurring Detection Tolerances
    RECURRING_AMOUNT_TOLERANCE_PCT: float = 0.15
    RECURRING_INTERVAL_TOLERANCE_DAYS: int = 4

    # Unusual Spending Detection (Statistical Rule: Mean ± k*σ or Median/MAD)
    UNUSUAL_SPENDING_SENSITIVITY_K: float = 2.0
    MIN_HISTORY_MONTHS_FOR_ANOMALY: int = 2
    MIN_TRANSACTIONS_FOR_ANOMALY: int = 5

    # Wishlist & Purchase Readiness
    READINESS_COMFORTABLE_RATIO: float = 1.0
    READINESS_POSSIBLE_RATIO: float = 2.5

    # Duplicate Detection
    DUPLICATE_AMOUNT_TOLERANCE: float = 0.01
    DUPLICATE_DATE_TOLERANCE_DAYS: int = 2

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
