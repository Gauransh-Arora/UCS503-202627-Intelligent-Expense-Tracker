"""
Authentication Service — user registration, login, and token generation.
"""
from uuid import UUID
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User
from app.utils.security import create_access_token, hash_password, verify_password


def register_user(name: str, email: str, password: str, db: Session) -> tuple[User, str]:
    """
    Register a new user account.
    Returns (user, jwt_token).

    Raises:
        HTTPException: If an account with this email already exists.
    """
    existing = db.query(User).filter(User.email == email.strip().lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        name=name.strip(),
        email=email.strip().lower(),
        password_hash=hash_password(password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return user, token


def login_user(email: str, password: str, db: Session) -> tuple[User, str]:
    """
    Authenticate an existing user.
    Returns (user, jwt_token).

    Raises:
        HTTPException: If credentials are invalid or account is disabled.
    """
    user = db.query(User).filter(User.email == email.strip().lower()).first()

    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )

    token = create_access_token(user.id)
    return user, token
