"""Categories router — list and seed default categories."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from uuid import UUID
from typing import Optional

from app.database import get_db
from app.models.category import Category, DEFAULT_CATEGORIES
from app.utils.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/categories", tags=["Categories"])


class CategoryResponse(BaseModel):
    id: UUID
    name: str
    icon: Optional[str]
    is_default: bool

    model_config = {"from_attributes": True}


@router.get("/", response_model=list[CategoryResponse])
def list_categories(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Return all available expense categories."""
    return db.query(Category).order_by(Category.name).all()


@router.post("/seed", status_code=status.HTTP_201_CREATED)
def seed_categories(db: Session = Depends(get_db)):
    """
    Seed the default categories into the database.
    Safe to call multiple times — skips existing ones.
    Normally called once at startup.
    """
    created = 0
    for name, icon in DEFAULT_CATEGORIES:
        exists = db.query(Category).filter(Category.name == name).first()
        if not exists:
            db.add(Category(name=name, icon=icon, is_default=True))
            created += 1
    db.commit()
    return {"message": f"Seeded {created} new categories"}
