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
from decimal import Decimal
import statistics
from sqlalchemy import func, extract
from app.models.transaction import Transaction


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

    # 5. Mid-month (Day >= 15) & Late-month (Day >= 25) spending surplus vs historical mean/median
    surplus_notifs = _check_periodic_wishlist_affordability(user_id, db, now)
    generated.extend(surplus_notifs)

    if generated:
        db.commit()
        for g in generated:
            db.refresh(g)

    return generated


def _check_periodic_wishlist_affordability(
    user_id: UUID,
    db: Session,
    now: datetime,
) -> list[Notification]:
    """
    Checks if user is at mid-month (>= 15th) or late-month (>= 25th).
    If month-to-date spending is below the expected curve of the last 2-3 months
    (mean or median), finds unpurchased wishlist items that the surplus can cover.
    """
    current_day = now.day
    if current_day < 15:
        return []

    curr_year = now.year
    curr_month = now.month

    # Dedup check: Ensure we haven't already notified this user for this period in this month & year
    period_title_prefix = f"Wishlist Goal Achievable ({'Late-Month' if current_day >= 25 else 'Mid-Month'})"
    existing_period_notif = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.title.like(f"{period_title_prefix}%"),
        extract("year", Notification.created_at) == curr_year,
        extract("month", Notification.created_at) == curr_month,
    ).first()

    if existing_period_notif:
        return []

    # 1. Calculate spending for last 2-3 prior calendar months
    historical_totals: list[float] = []
    for m_back in [1, 2, 3]:
        calc_month = curr_month - m_back
        calc_year = curr_year
        while calc_month <= 0:
            calc_month += 12
            calc_year -= 1

        month_sum = (
            db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
            .filter(
                Transaction.user_id == user_id,
                Transaction.is_deleted == False,
                extract("year", Transaction.transaction_date) == calc_year,
                extract("month", Transaction.transaction_date) == calc_month,
            )
            .scalar()
        )
        if month_sum and float(month_sum) > 0:
            historical_totals.append(float(month_sum))

    if len(historical_totals) < 2:
        return []

    hist_mean = statistics.mean(historical_totals)
    hist_median = statistics.median(historical_totals)
    benchmark_monthly = min(hist_mean, hist_median)

    # 2. Calculate current month-to-date spending
    curr_mtd_spending = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
            extract("year", Transaction.transaction_date) == curr_year,
            extract("month", Transaction.transaction_date) == curr_month,
        )
        .scalar()
    )
    curr_mtd = float(curr_mtd_spending or 0.0)

    # 3. Expected spending curve up to current day (normalized over 30 days)
    progress_ratio = min(1.0, current_day / 30.0)
    expected_spending = benchmark_monthly * progress_ratio

    if curr_mtd >= expected_spending:
        return []

    surplus = expected_spending - curr_mtd
    if surplus < 100.0:
        return []

    # 4. Check wishlist for unpurchased items that this surplus can cover
    matching_wishlist = (
        db.query(WishlistItem)
        .filter(
            WishlistItem.user_id == user_id,
            WishlistItem.is_purchased == False,
            WishlistItem.expected_price <= Decimal(str(round(surplus, 2))),
        )
        .order_by(WishlistItem.expected_price.desc())
        .first()
    )

    if not matching_wishlist:
        return []

    item_name = matching_wishlist.name
    item_price = float(matching_wishlist.expected_price)

    title = f"{period_title_prefix}: {item_name}"
    message = (
        f"You're spending below your historical average by ₹{surplus:,.0f} this month! "
        f"Your wishlist item '{item_name}' (₹{item_price:,.0f}) is comfortably within your savings surplus. "
        f"Treat yourself or achieve your goal!"
    )

    notif = Notification(
        user_id=user_id,
        title=title,
        message=message,
        notification_type=NotificationType.WISHLIST_UPDATE.value,
    )
    db.add(notif)
    return [notif]
