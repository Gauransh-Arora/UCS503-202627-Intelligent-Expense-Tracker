"""Documents router — upload files, trigger Vision LLM processing, discard drafts."""
from decimal import Decimal
import os
from pathlib import Path
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.category import Category
from app.models.document import Document, DocumentType, ProcessingStatus
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.document import DocumentResponse, ExtractedItem, OCRResult
from app.services.categorization_service import (
    categorize_merchant,
    categorize_transaction,
    find_or_create_category,
)
from app.services.vision_service import is_vision_available, parse_receipt_with_vision
from app.utils.auth import get_current_user

router = APIRouter(prefix="/documents", tags=["Documents"])

ALLOWED_MIME_TYPES = {
    "image/jpeg", "image/png", "image/webp", "image/heic",
    "application/pdf",
}


@router.post("/upload", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    document_type: str = Form("receipt"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a receipt, bill, or UPI screenshot.
    File is saved to disk and a Document record is created with 'uploaded' status.
    Call POST /documents/{id}/process to run Vision LLM parsing.
    """
    valid_extensions = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf"}
    ext = Path(file.filename or "file").suffix.lower()
    final_content_type = file.content_type

    if final_content_type not in ALLOWED_MIME_TYPES:
        if final_content_type == "application/octet-stream" and ext in valid_extensions:
            if ext in {".jpg", ".jpeg"}:
                final_content_type = "image/jpeg"
            elif ext == ".png":
                final_content_type = "image/png"
            elif ext == ".pdf":
                final_content_type = "application/pdf"
            elif ext == ".webp":
                final_content_type = "image/webp"
            elif ext == ".heic":
                final_content_type = "image/heic"
        else:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"File type '{final_content_type}' not supported. Use JPEG, PNG, WebP, or PDF.",
            )

    # Auto-detect document type if not specified
    doc_type = document_type.lower()
    if doc_type not in ("receipt", "bill", "upi_screenshot", "bank_statement"):
        if ext == ".pdf":
            doc_type = "bill"
        else:
            doc_type = "receipt"

    upload_dir = Path(settings.UPLOAD_DIR) / str(current_user.id)
    upload_dir.mkdir(parents=True, exist_ok=True)

    safe_name = f"{uuid.uuid4()}{ext}"
    file_path = upload_dir / safe_name

    content = await file.read()
    if len(content) > settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds limit of {settings.MAX_UPLOAD_SIZE_MB}MB",
        )

    file_path.write_bytes(content)

    doc = Document(
        user_id=current_user.id,
        original_filename=file.filename or "unknown",
        file_url=str(file_path),
        mime_type=final_content_type,
        document_type=doc_type,
        processing_status=ProcessingStatus.UPLOADED.value,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc


@router.post("/{document_id}/process", response_model=OCRResult)
def process_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Run Multimodal Vision LLM parsing on uploaded file.
    Returns structured draft details with per-field confidence for user review.
    Does NOT create a permanent expense transaction.
    """
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    if doc.processing_status == ProcessingStatus.PROCESSING.value:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Document is already being processed")

    doc.processing_status = ProcessingStatus.PROCESSING.value
    db.commit()

    try:
        extracted = None
        raw_text = ""

        # Multimodal Vision LLM extraction
        if is_vision_available():
            file_to_parse = doc.file_url
            if not os.path.exists(file_to_parse):
                candidates = [
                    Path(file_to_parse),
                    Path("code/backend") / file_to_parse,
                    Path(__file__).resolve().parent.parent.parent / file_to_parse,
                ]
                for cand in candidates:
                    if cand.exists():
                        file_to_parse = str(cand)
                        break

            vision_res = parse_receipt_with_vision(file_to_parse)
            if vision_res:
                extracted = vision_res
                raw_text = vision_res.get("raw_text") or (
                    f"{vision_res.get('merchant_name', '')} "
                    f"Amount: {vision_res.get('amount', '')} "
                    f"Date: {vision_res.get('date', '')}"
                )
                doc.ocr_text = raw_text

        if not extracted:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Unable to extract receipt details using Vision model. Please ensure GEMINI_API_KEY is configured.",
            )

        # Suggest category
        category_name = None
        category_id = None
        suggested_cat = extracted.get("category")
        if suggested_cat:
            cat = find_or_create_category(suggested_cat, db)
            if cat:
                category_id = cat.id
                category_name = cat.name

        if not category_id and extracted.get("merchant_name"):
            cat_id = categorize_merchant(extracted["merchant_name"], current_user.id, db)
            if cat_id:
                cat = db.query(Category).filter(Category.id == cat_id).first()
                if cat:
                    category_id = cat.id
                    category_name = cat.name

        if not category_id:
            guessed_name, _ = categorize_transaction(
                merchant_name=extracted.get("merchant_name") or "",
                description=raw_text[:200],
                user_id=current_user.id,
                db=db,
            )
            cat = find_or_create_category(guessed_name, db)
            if cat:
                category_id = cat.id
                category_name = cat.name

        # Parse line items if present
        line_items = []
        for item in extracted.get("items", []):
            qty = int(item.get("quantity") or 1)
            u_price = item.get("unit_price") or item.get("price")
            t_price = item.get("total_price") or (float(u_price) * qty if u_price is not None else None)
            if u_price is None and t_price is not None:
                u_price = round(float(t_price) / max(1, qty), 2)

            line_items.append(
                ExtractedItem(
                    name=item.get("name") or "Unknown Item",
                    quantity=qty,
                    unit_price=Decimal(str(u_price)) if u_price is not None else None,
                    total_price=Decimal(str(t_price)) if t_price is not None else None,
                    price=Decimal(str(t_price)) if t_price is not None else None,
                )
            )

        doc.processing_status = ProcessingStatus.PROCESSED.value
        doc.ocr_confidence = extracted.get("confidence", 0.95)
        db.commit()

        return OCRResult(
            document_id=doc.id,
            raw_text=raw_text,
            merchant_name=extracted.get("merchant_name"),
            amount=Decimal(str(extracted["amount"])) if extracted.get("amount") is not None else None,
            tax_amount=Decimal(str(extracted["tax_amount"])) if extracted.get("tax_amount") is not None else None,
            date=extracted.get("date"),
            transaction_date=extracted.get("date"),
            currency=extracted.get("currency", settings.DEFAULT_CURRENCY),
            payment_method=extracted.get("payment_method"),
            confidence=extracted.get("confidence", 0.95),
            field_confidences=extracted.get("field_confidences", {}),
            suggested_category_id=category_id,
            suggested_category=category_name,
            category_suggestion=category_name,
            reference_number=extracted.get("reference"),
            payment_status=extracted.get("payment_status", "success"),
            payment_direction=extracted.get("payment_direction", "debit"),
            items=line_items,
        )

    except HTTPException:
        doc.processing_status = ProcessingStatus.FAILED.value
        db.commit()
        raise
    except Exception as exc:
        doc.processing_status = ProcessingStatus.FAILED.value
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Vision parsing failed: {exc}",
        )


@router.delete("/{document_id}/discard", status_code=status.HTTP_200_OK)
def discard_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Discard an uploaded document and its parsed draft without creating a transaction.
    Removes the file from disk and marks the record as discarded.
    """
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    if doc.file_url and os.path.exists(doc.file_url):
        try:
            os.remove(doc.file_url)
        except OSError:
            pass

    doc.processing_status = ProcessingStatus.DISCARDED.value
    db.commit()
    return {"message": "Document discarded successfully", "document_id": str(document_id)}


@router.get("/{document_id}", response_model=DocumentResponse)
def get_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get metadata for an uploaded document."""
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    return doc


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Permanently delete a document record and its underlying file."""
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()

    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    if doc.file_url and os.path.exists(doc.file_url):
        try:
            os.remove(doc.file_url)
        except OSError:
            pass

    db.delete(doc)
    db.commit()
    return None
