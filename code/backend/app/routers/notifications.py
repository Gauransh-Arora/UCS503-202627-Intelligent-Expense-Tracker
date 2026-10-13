"""Notifications router — view notifications, mark as read, and trigger auto notifications."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.notification import (
    AutoNotificationResult,
    NotificationResponse,
    UnreadCountResponse,
)
from app.services.notification_service import (
    generate_auto_notifications as service_generate_auto_notifications,
    get_notifications as service_get_notifications,
    get_unread_count as service_get_unread_count,
    mark_all_as_read as service_mark_all_as_read,
    mark_as_read as service_mark_as_read,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/", response_model=list[NotificationResponse])
def get_notifications(
    unread_only: bool = Query(False),
    limit: int = Query(50, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List notifications for the current user."""
    return service_get_notifications(
        user_id=current_user.id,
        db=db,
        unread_only=unread_only,
        limit=limit,
    )


@router.get("/unread-count", response_model=UnreadCountResponse)
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the number of unread notifications."""
    return UnreadCountResponse(unread_count=service_get_unread_count(current_user.id, db))


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_notification_as_read(
    notification_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a notification as read."""
    service_mark_as_read(notification_id, current_user.id, db)


@router.post("/read-all", status_code=status.HTTP_200_OK)
def mark_all_notifications_as_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all unread notifications as read."""
    count = service_mark_all_as_read(current_user.id, db)
    return {"message": f"Marked {count} notifications as read"}


@router.post("/trigger-auto", response_model=AutoNotificationResult)
def trigger_auto_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Scan spending anomalies, recurring bills, and shared debts to generate auto notifications."""
    notifs = service_generate_auto_notifications(current_user.id, db)
    return AutoNotificationResult(
        generated_count=len(notifs),
        notifications=[NotificationResponse.model_validate(n) for n in notifs],
    )
