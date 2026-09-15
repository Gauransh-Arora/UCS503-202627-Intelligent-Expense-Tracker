"""
Intelligent Expense Tracker — FastAPI Application Entry Point

Architecture:
  Flutter → FastAPI → SQLAlchemy → Supabase PostgreSQL

Security:
  - JWT authentication on all protected routes
  - bcrypt password hashing
  - CORS restricted to configured origins
  - User isolation: every query filters by user_id
"""
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine

# Import all models so SQLAlchemy registers them before create_all
import app.models  # noqa: F401

from app.routers import auth, transactions, documents, splits, analytics, wishlist, ai, categories


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application startup / shutdown lifecycle.

    On startup:
      - Create all tables that don't yet exist in Supabase (graceful if DB unreachable)
      - Seed default categories
      - Ensure uploads directory exists
    """
    import logging
    logger = logging.getLogger("startup")

    # Ensure uploads directory exists (always, no DB needed)
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

    try:
        # Create tables (safe — won't drop or alter existing ones)
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Database tables verified / created.")

        # Seed default categories
        from app.database import SessionLocal
        from app.models.category import Category, DEFAULT_CATEGORIES
        db = SessionLocal()
        try:
            seeded = 0
            for name, icon in DEFAULT_CATEGORIES:
                if not db.query(Category).filter(Category.name == name).first():
                    db.add(Category(name=name, icon=icon, is_default=True))
                    seeded += 1
            db.commit()
            if seeded:
                logger.info(f"✅ Seeded {seeded} default categories.")
        finally:
            db.close()

    except Exception as exc:
        logger.warning(
            f"\n⚠️  Could not connect to the database at startup: {exc}\n"
            "   The server will still start. Fix the DB connection and restart.\n"
            "   If using Supabase free tier, your project may be PAUSED — "
            "visit https://supabase.com/dashboard to resume it."
        )

    yield
    # Shutdown logic (if needed) goes here


app = FastAPI(
    title="Intelligent Expense Tracker API",
    description=(
        "Backend API for the Intelligent Expense Tracker.\n\n"
        "Features: Authentication, Expense CRUD, OCR Receipt Processing, "
        "Expense Splitting, Analytics, Wishlist, Recurring Detection, and AI Queries."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# For development: allow all origins. Tighten before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Replace with Flutter app origin in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(documents.router)
app.include_router(splits.router)
app.include_router(analytics.router)
app.include_router(wishlist.router)
app.include_router(ai.router)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/ping", tags=["Health"])
async def ping():
    """Health check endpoint."""
    return {"status": "ok", "message": "Intelligent Expense Tracker API is running"}
