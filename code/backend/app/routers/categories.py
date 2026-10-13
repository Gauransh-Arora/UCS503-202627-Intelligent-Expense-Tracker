"""Categories router — list and seed default categories."""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.category import DEFAULT_CATEGORIES, Category
from app.models.user import User
from app.services.transaction_service import get_categories as service_get_categories
from app.utils.auth import get_current_user

router = APIRouter(prefix="/categories", tags=["Categories"])


class CategoryResponse(BaseModel):
    id: UUID
    name: str
    icon: Optional[str]
    is_default: bool

    model_config = {"from_attributes": True}


@router.get("/", response_model=list[CategoryResponse])
def get_categories(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Retrieve all expense categories."""
    return service_get_categories(db)


# Alias
list_categories = get_categories


@router.post("/seed", status_code=status.HTTP_201_CREATED)
def seed_categories(db: Session = Depends(get_db)):
    """Seed default categories if they don't exist."""
    created = 0
    for name, icon in DEFAULT_CATEGORIES:
        exists = db.query(Category).filter(Category.name == name).first()
        if not exists:
            db.add(Category(name=name, icon=icon, is_default=True))
            created += 1
    db.commit()
    return {"message": f"Seeded {created} new categories"}
