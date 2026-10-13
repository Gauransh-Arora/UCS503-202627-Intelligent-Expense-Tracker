"""Friend model — contacts stored under a user's account for expense splitting."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, String, Uuid
from sqlalchemy.orm import relationship

from app.database import Base


class Friend(Base):
    __tablename__ = "friends"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=True)
    phone = Column(String(50), nullable=True)
    avatar_url = Column(String(500), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="friends")

    def __repr__(self) -> str:
        return f"<Friend id={self.id} name={self.name} user_id={self.user_id}>"
