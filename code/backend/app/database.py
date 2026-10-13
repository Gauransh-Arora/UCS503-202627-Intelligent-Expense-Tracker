"""
SQLAlchemy database setup.

Creates:
  - engine       → connection to Supabase PostgreSQL
  - SessionLocal → factory for database sessions
  - Base         → declarative base all models inherit from
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

db_url = settings.DATABASE_URL
if db_url.startswith("sqlite"):
    engine = create_engine(
        db_url,
        connect_args={"check_same_thread": False},
    )
else:
    engine = create_engine(
        db_url,
        pool_pre_ping=True,       # reconnect if connection dropped
        pool_size=5,
        max_overflow=10,
    )

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

Base = declarative_base()


def get_db():
    """FastAPI dependency — yields a DB session and closes it when done."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
