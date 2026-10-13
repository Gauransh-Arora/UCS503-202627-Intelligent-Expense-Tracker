"""Notification Pydantic schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class NotificationCreate(BaseModel):
    title: str
    message: str
    notification_type: str = "system"


class NotificationResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    message: str
    notification_type: str
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UnreadCountResponse(BaseModel):
    unread_count: int


class AutoNotificationResult(BaseModel):
    generated_count: int
    notifications: list[NotificationResponse] = []
