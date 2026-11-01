"""
Transaction Service — expense CRUD, history, details, and categories.
"""
from datetime import date
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import extract
from sqlalchemy.orm import Session, joinedload

from app.models.category import Category
from app.models.preference import UserCategoryPreference
from app.models.document import Document
from app.models.transaction import Transaction, TransactionItem, VerificationStatus
from app.schemas.transaction import (
    TransactionCreate,
    TransactionDetailResponse,
    TransactionResponse,
    TransactionUpdate,
)
from app.services.categorization_service import (
    categorize_merchant,
    get_global_merchant_rules,
    find_or_create_category,
    save_user_preference,
)


def get_categories(db: Session) -> list[Category]:
    """Retrieve all expense categories."""
    return db.query(Category).order_by(Category.name).all()


def create_transaction(
    user_id: UUID,
    tx_in: TransactionCreate,
    db: Session,
) -> Transaction:
    """
    Create a new expense transaction or confirm an OCR draft.
    - Idempotent: confirming an already confirmed document draft returns existing transaction.
    - Learns user categorization preferences from explicit user selection.
    """
    # 1. Idempotency guard for document drafts
    if tx_in.document_id:
        existing = (
            db.query(Transaction)
            .filter(
                Transaction.user_id == user_id,
                Transaction.document_id == tx_in.document_id,
                Transaction.is_deleted == False,
            )
            .first()
        )
        if existing:
            return existing

    category_id = tx_in.category_id
    auto_categorized = False

    if category_id is None and tx_in.category_name:
        matched_cat = find_or_create_category(tx_in.category_name, db)
        if matched_cat:
            category_id = matched_cat.id
            save_user_preference(tx_in.merchant_name, category_id, user_id, db)

    if category_id is None:
        suggested = categorize_merchant(tx_in.merchant_name, user_id, db)
        if suggested:
            category_id = suggested
            auto_categorized = True
        else:
            default_cat = find_or_create_category("Other", db)
            category_id = default_cat.id
            auto_categorized = True
    else:
        # User explicitly chose or corrected category -> learn preference!
        save_user_preference(tx_in.merchant_name, category_id, user_id, db)

    verif_status = (
        VerificationStatus.VERIFIED.value
        if tx_in.document_id
        else VerificationStatus.AUTO.value
    )

    doc_confidence = None
    if tx_in.document_id:
        doc = db.query(Document).filter(Document.id == tx_in.document_id).first()
        if doc:
            doc.processing_status = "verified"
            doc_confidence = doc.ocr_confidence

    tx = Transaction(
        user_id=user_id,
        merchant_name=tx_in.merchant_name,
        amount=tx_in.amount,
        currency=tx_in.currency,
        transaction_date=tx_in.transaction_date,
        payment_method=tx_in.payment_method.value if hasattr(tx_in.payment_method, "value") else str(tx_in.payment_method),
        description=tx_in.description,
        category_id=category_id,
        document_id=tx_in.document_id,
        auto_categorized=auto_categorized,
        verification_status=verif_status,
        ocr_confidence=doc_confidence,
        is_verified=True,
    )
    db.add(tx)
    db.flush()

    for item_in in tx_in.items:
        db.add(
            TransactionItem(
                transaction_id=tx.id,
                name=item_in.name,
                quantity=item_in.quantity,
                unit_price=item_in.unit_price,
                total_price=item_in.total_price,
                category_id=item_in.category_id or category_id,
            )
        )

    db.commit()
    return (
        db.query(Transaction)
        .options(joinedload(Transaction.category), joinedload(Transaction.items))
        .filter(Transaction.id == tx.id)
        .first()
    )


def create_bulk_transactions(
    user_id: UUID,
    tx_list: list[TransactionCreate],
    db: Session,
) -> list[Transaction]:
    """Bulk create transactions efficiently in a single DB commit."""
    categories = db.query(Category).all()
    cat_by_name = {c.name.lower().strip(): c for c in categories}
    default_cat = cat_by_name.get("other") or (categories[0] if categories else None)

    preferences = (
        db.query(UserCategoryPreference)
        .filter(UserCategoryPreference.user_id == user_id)
        .all()
    )
    pref_map = {p.merchant_name.lower().strip(): p.category_id for p in preferences}
    rules = get_global_merchant_rules()

    created_txs = []
    new_prefs = {}

    for tx_in in tx_list:
        category_id = tx_in.category_id
        auto_categorized = False

        if category_id is None and tx_in.category_name:
            c_name = tx_in.category_name.lower().strip()
            if c_name in cat_by_name:
                category_id = cat_by_name[c_name].id
            else:
                matched_cat = find_or_create_category(tx_in.category_name, db)
                cat_by_name[matched_cat.name.lower().strip()] = matched_cat
                category_id = matched_cat.id
            if tx_in.merchant_name:
                new_prefs[tx_in.merchant_name.lower().strip()] = category_id

        if category_id is None:
            m_lower = tx_in.merchant_name.lower().strip()
            for pref_name, p_cat_id in pref_map.items():
                if pref_name in m_lower or m_lower in pref_name:
                    category_id = p_cat_id
                    break
            if category_id is None:
                for kw, r_cat_name in rules.items():
                    if kw.lower() in m_lower:
                        r_lower = r_cat_name.lower().strip()
                        if r_lower in cat_by_name:
                            category_id = cat_by_name[r_lower].id
                            break
            if category_id is None:
                category_id = default_cat.id if default_cat else None
                auto_categorized = True
        else:
            if tx_in.merchant_name:
                new_prefs[tx_in.merchant_name.lower().strip()] = category_id

        verif_status = (
            VerificationStatus.VERIFIED.value
            if tx_in.document_id
            else VerificationStatus.AUTO.value
        )

        tx = Transaction(
            user_id=user_id,
            merchant_name=tx_in.merchant_name,
            amount=tx_in.amount,
            currency=tx_in.currency,
            transaction_date=tx_in.transaction_date,
            payment_method=tx_in.payment_method.value if hasattr(tx_in.payment_method, "value") else str(tx_in.payment_method),
            description=tx_in.description,
            category_id=category_id,
            document_id=tx_in.document_id,
            auto_categorized=auto_categorized,
            verification_status=verif_status,
            is_verified=True,
        )
        db.add(tx)
        created_txs.append(tx)

    for m_name, c_id in new_prefs.items():
        if m_name not in pref_map:
            pref = UserCategoryPreference(
                user_id=user_id,
                category_id=c_id,
                merchant_name=m_name,
            )
            db.add(pref)

    db.commit()

    tx_ids = [t.id for t in created_txs]
    fetched = (
        db.query(Transaction)
        .options(joinedload(Transaction.category), joinedload(Transaction.items))
        .filter(Transaction.id.in_(tx_ids))
        .all()
    )
    tx_map = {t.id: t for t in fetched}
    return [tx_map[tid] for tid in tx_ids if tid in tx_map]


def get_transactions(
    user_id: UUID,
    db: Session,
    category_id: Optional[UUID] = None,
    payment_method: Optional[str] = None,
    month: Optional[int] = None,
    year: Optional[int] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    merchant: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> list[Transaction]:
    """
    Retrieve chronological expense history for the user with optional filters.
    Sorted chronologically descending (most recent first).
    """
    q = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_deleted == False,
    )

    if category_id:
        q = q.filter(Transaction.category_id == category_id)
    if payment_method:
        q = q.filter(Transaction.payment_method == payment_method)
    if month:
        q = q.filter(extract("month", Transaction.transaction_date) == month)
    if year:
        q = q.filter(extract("year", Transaction.transaction_date) == year)
    if start_date:
        q = q.filter(Transaction.transaction_date >= start_date)
    if end_date:
        q = q.filter(Transaction.transaction_date <= end_date)
    if merchant:
        q = q.filter(Transaction.merchant_name.ilike(f"%{merchant}%"))

    txns = (
        q.options(
            joinedload(Transaction.category),
            joinedload(Transaction.items),
        )
        .order_by(Transaction.transaction_date.desc(), Transaction.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    # Heal any existing legacy transactions in database that have category_id == None
    has_fixes = False
    for t in txns:
        if t.category_id is None:
            suggested = categorize_merchant(t.merchant_name, user_id, db)
            if not suggested:
                other_cat = find_or_create_category("Other", db)
                suggested = other_cat.id if other_cat else None
            if suggested:
                t.category_id = suggested
                t.auto_categorized = True
                has_fixes = True
    if has_fixes:
        db.commit()

    return txns


def update_transaction(
    transaction_id: UUID,
    user_id: UUID,
    tx_update: TransactionUpdate,
    db: Session,
) -> Transaction:
    """Edit transaction details. Learns user preference if category changes."""
    tx = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .first()
    )
    if not tx:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    update_data = tx_update.model_dump(exclude_unset=True)

    if "category_name" in update_data and update_data["category_name"] and "category_id" not in update_data:
        matched_cat = find_or_create_category(update_data.pop("category_name"), db)
        if matched_cat:
            update_data["category_id"] = matched_cat.id

    if "category_id" in update_data and update_data["category_id"] != tx.category_id:
        if update_data["category_id"] is not None:
            save_user_preference(tx.merchant_name, update_data["category_id"], user_id, db)

    for field, value in update_data.items():
        if field == "payment_method" and hasattr(value, "value"):
            setattr(tx, field, value.value)
        elif field == "verification_status" and hasattr(value, "value"):
            setattr(tx, field, value.value)
        else:
            setattr(tx, field, value)

    db.commit()
    return (
        db.query(Transaction)
        .options(joinedload(Transaction.category), joinedload(Transaction.items))
        .filter(Transaction.id == tx.id)
        .first()
    )


def delete_transaction(
    transaction_id: UUID,
    user_id: UUID,
    db: Session,
) -> bool:
    """Soft-delete an expense transaction."""
    tx = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .first()
    )
    if not tx:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    tx.is_deleted = True
    db.commit()
    return True


def get_transaction_details(
    transaction_id: UUID,
    user_id: UUID,
    db: Session,
) -> TransactionDetailResponse:
    """
    Retrieve comprehensive transaction details including:
    - Merchant, amount, date, payment method, description
    - Individual line items
    - Expense category details
    - Source document details (OCR receipt, bill, etc.)
    """
    tx = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == user_id,
            Transaction.is_deleted == False,
        )
        .first()
    )
    if not tx:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    category_info = None
    if tx.category:
        category_info = {
            "id": tx.category.id,
            "name": tx.category.name,
            "icon": tx.category.icon,
        }

    doc_info = None
    if tx.document:
        doc_info = {
            "id": tx.document.id,
            "original_filename": tx.document.original_filename,
            "file_url": tx.document.file_url,
            "mime_type": tx.document.mime_type,
            "document_type": tx.document.document_type,
            "processing_status": tx.document.processing_status,
            "ocr_confidence": tx.document.ocr_confidence,
            "ocr_text": tx.document.ocr_text,
        }

    return TransactionDetailResponse(
        id=tx.id,
        user_id=tx.user_id,
        merchant_name=tx.merchant_name,
        amount=tx.amount,
        currency=tx.currency,
        transaction_date=tx.transaction_date,
        payment_method=tx.payment_method,
        description=tx.description,
        is_verified=tx.is_verified,
        verification_status=tx.verification_status,
        ocr_confidence=tx.ocr_confidence,
        auto_categorized=tx.auto_categorized,
        category_id=tx.category_id,
        category_name=tx.category.name if tx.category else None,
        category=category_info,
        source_document=doc_info,
        items=[
            {
                "id": it.id,
                "name": it.name,
                "quantity": it.quantity,
                "unit_price": it.unit_price,
                "total_price": it.total_price,
                "category_id": it.category_id,
            }
            for it in tx.items
        ],
        created_at=tx.created_at,
        updated_at=tx.updated_at,
    )
