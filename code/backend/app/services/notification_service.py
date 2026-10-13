"""
Notification Service — manage in-app notifications and trigger auto-notifications
for unusual spending, upcoming bills, wishlist readiness, and shared expense debts.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.notification import Notification, NotificationType
from app.models.recurring import Frequency, RecurringExpense
from app.models.wishlist import WishlistItem


def create_notification(
    user_id: UUID,
    title: str,
    message: str,
    notification_type: str,
    db: Session,
) -> Notification:
    """Create and persist a new notification for user."""
    notif = Notification(
        user_id=user_id,
        title=title,
        message=message,
        notification_type=notification_type,
        is_read=False,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif


def get_notifications(
    user_id: UUID,
    db: Session,
    unread_only: bool = False,
    limit: int = 50,
) -> list[Notification]:
    """Retrieve user notifications, ordered newest first."""
    q = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        q = q.filter(Notification.is_read == False)
    return q.order_by(Notification.created_at.desc()).limit(limit).all()


def mark_as_read(
    notification_id: UUID,
    user_id: UUID,
    db: Session,
) -> bool:
    """Mark a single notification as read."""
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user_id,
    ).first()
    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    notif.is_read = True
    db.commit()
    return True


def mark_all_as_read(
    user_id: UUID,
    db: Session,
) -> int:
    """Mark all unread notifications as read for user."""
    unread = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False,
    ).all()
    count = len(unread)
    for n in unread:
        n.is_read = True
    db.commit()
    return count


def get_unread_count(
    user_id: UUID,
    db: Session,
) -> int:
    """Count unread notifications for user."""
    return db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False,
    ).count()


def generate_auto_notifications(
    user_id: UUID,
    db: Session,
) -> list[Notification]:
    """
    Automated notification generator:
    1. Unusual spending detection alerts
    2. Upcoming recurring expenses / bills
    3. Unsettled debt balances owed to the user
    4. Wishlist items that reached Comfortable status
    """
    generated: list[Notification] = []
    now = datetime.now(timezone.utc)

    # 1. Unusual spending alerts
    from app.services.intelligence_service import detect_unusual_spending
    alerts = detect_unusual_spending(user_id, db)
    for alert_text in alerts[:2]:
        # Check if identical alert already sent today
        existing = db.query(Notification).filter(
            Notification.user_id == user_id,
            Notification.title == "Unusual Spending Detected",
            Notification.message == alert_text,
        ).first()
        if not existing:
            notif = Notification(
                user_id=user_id,
                title="Unusual Spending Detected",
                message=alert_text,
                notification_type=NotificationType.UNUSUAL_SPENDING.value,
            )
            db.add(notif)
            generated.append(notif)

    # 2. Upcoming recurring payments (e.g. typical day within next 3 days)
    recurring_items = (
        db.query(RecurringExpense)
        .filter(
            RecurringExpense.user_id == user_id,
            RecurringExpense.is_active == True,
            RecurringExpense.typical_day.isnot(None),
        )
        .all()
    )
    today_day = now.day
    for r in recurring_items:
        diff_days = (r.typical_day - today_day) % 30
        if 0 <= diff_days <= 3:
            msg = f"Upcoming bill: {r.merchant_name} (₹{r.average_amount:,.2f}) is due around day {r.typical_day} of this month."
            existing = db.query(Notification).filter(
                Notification.user_id == user_id,
                Notification.message == msg,
            ).first()
            if not existing:
                notif = Notification(
                    user_id=user_id,
                    title=f"Bill Reminder: {r.merchant_name}",
                    message=msg,
                    notification_type=NotificationType.RECURRING_DUE.value,
                )
                db.add(notif)
                generated.append(notif)

    # 3. Unsettled shared expense debts
    from app.services.split_service import calculate_user_balance
    balance = calculate_user_balance(user_id, db)
    for fb in balance.friend_balances:
        if fb.net_balance > 500:  # Friend owes more than ₹500
            msg = f"{fb.friend_name} owes you ₹{fb.net_balance:,.2f} from shared expense splits."
            existing = db.query(Notification).filter(
                Notification.user_id == user_id,
                Notification.title == f"Outstanding Debt: {fb.friend_name}",
            ).first()
            if not existing:
                notif = Notification(
                    user_id=user_id,
                    title=f"Outstanding Debt: {fb.friend_name}",
                    message=msg,
                    notification_type=NotificationType.SPLIT_DEBT.value,
                )
                db.add(notif)
                generated.append(notif)

    # 4. Wishlist ready items
    wishlist_items = (
        db.query(WishlistItem)
        .filter(
            WishlistItem.user_id == user_id,
            WishlistItem.is_purchased == False,
            WishlistItem.verdict == "Comfortable",
        )
        .all()
    )
    for w in wishlist_items:
        msg = f"'{w.name}' (₹{w.expected_price:,.2f}) is within your discretionary budget and ready to purchase!"
        existing = db.query(Notification).filter(
            Notification.user_id == user_id,
            Notification.title == f"Wishlist Ready: {w.name}",
        ).first()
        if not existing:
            notif = Notification(
                user_id=user_id,
                title=f"Wishlist Ready: {w.name}",
                message=msg,
                notification_type=NotificationType.WISHLIST_UPDATE.value,
            )
            db.add(notif)
            generated.append(notif)

    if generated:
        db.commit()
        for g in generated:
            db.refresh(g)

    return generated
