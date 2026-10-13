"""Test configuration and shared fixtures using SQLite with StaticPool."""
import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.category import DEFAULT_CATEGORIES, Category
from app.models.user import User
from app.utils.security import create_access_token, hash_password


@pytest.fixture(scope="session")
def engine():
    test_engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=test_engine)
    return test_engine


@pytest.fixture(scope="function")
def db_session(engine):
    """Provides a transactional database session reset for each test."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = Session()

    # Seed default categories
    for name, icon in DEFAULT_CATEGORIES:
        session.add(Category(name=name, icon=icon, is_default=True))
    session.commit()

    try:
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture(scope="function")
def client(db_session):
    """TestClient wired to the test DB session."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def test_user(db_session):
    """Create a fresh test user for each test."""
    user = User(
        name="Test User",
        email=f"user_{uuid.uuid4().hex[:6]}@example.com",
        password_hash=hash_password("password123"),
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture(scope="function")
def auth_headers(test_user):
    """Auth Bearer headers for test user."""
    token = create_access_token(test_user.id)
    return {"Authorization": f"Bearer {token}"}
