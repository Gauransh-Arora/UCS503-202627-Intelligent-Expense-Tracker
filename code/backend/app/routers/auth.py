"""Authentication router — register, login, get and update current user."""
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.user import Token, UserCreate, UserLogin, UserResponse, UserUpdate
from app.services.auth_service import login_user as auth_login_user, register_user as auth_register_user
from app.utils.auth import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register_user(user_in: UserCreate, db: Session = Depends(get_db)):
    """Register a new user. Returns a JWT token immediately."""
    user, token = auth_register_user(
        name=user_in.name,
        email=user_in.email,
        password=user_in.password,
        db=db,
    )
    if user_in.monthly_income is not None:
        user.monthly_income = Decimal(str(user_in.monthly_income))
        db.commit()
        db.refresh(user)
    return Token(access_token=token, user=UserResponse.model_validate(user))


# Alias endpoint for consistency
register = register_user


@router.post("/login", response_model=Token)
def login_user(credentials: UserLogin, db: Session = Depends(get_db)):
    """Login with email + password. Returns a JWT token."""
    user, token = auth_login_user(
        email=credentials.email,
        password=credentials.password,
        db=db,
    )
    return Token(access_token=token, user=UserResponse.model_validate(user))


# Alias endpoint
login = login_user


@router.get("/me", response_model=UserResponse)
def get_user_profile(current_user: User = Depends(get_current_user)):
    """Return the currently authenticated user's profile."""
    return current_user


@router.patch("/me", response_model=UserResponse)
@router.put("/me", response_model=UserResponse)
def update_user_profile(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update current user profile, including name, email, and monthly income."""
    if user_update.name is not None:
        current_user.name = user_update.name.strip()
    if user_update.email is not None:
        new_email = user_update.email.lower().strip()
        existing = db.query(User).filter(User.email == new_email, User.id != current_user.id).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email address is already in use",
            )
        current_user.email = new_email
    if user_update.monthly_income is not None:
        current_user.monthly_income = Decimal(str(user_update.monthly_income))

    db.commit()
    db.refresh(current_user)
    return current_user
