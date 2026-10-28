"""Documents router — upload files, trigger OCR processing, discard drafts."""
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.category import Category
from app.models.document import Document, DocumentType, ProcessingStatus
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.document import DocumentResponse, ExtractedItem, OCRResult
from app.services.categorization_service import categorize_merchant
from app.services.extraction_service import extract_transaction_data
from app.services.ocr_service import run_ocr
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
    Call POST /documents/{id}/process to run OCR.
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
    Run OCR and heuristic document parsing on uploaded file.
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
        raw_text = run_ocr(doc.file_url)
        doc.ocr_text = raw_text

        extracted = extract_transaction_data(raw_text)

        # Suggest category
        category_name = None
        category_id = None
        if extracted.get("merchant_name"):
            cat_id = categorize_merchant(extracted["merchant_name"], current_user.id, db)
            if cat_id:
                cat = db.query(Category).filter(Category.id == cat_id).first()
                if cat:
                    category_id = cat.id
                    category_name = cat.name

        doc.processing_status = ProcessingStatus.PROCESSED.value
        doc.ocr_confidence = extracted.get("confidence", 0.0)
        db.commit()

        items = [
            ExtractedItem(
                name=i["name"],
                quantity=i.get("quantity", 1),
                unit_price=i.get("unit_price", 0.0),
                total_price=i["total_price"],
            )
            for i in extracted.get("items", [])
        ]

        return OCRResult(
            document_id=doc.id,
            raw_text=raw_text,
            merchant_name=extracted.get("merchant_name"),
            amount=extracted.get("amount"),
            tax_amount=extracted.get("tax_amount"),
            date=extracted.get("date"),
            items=items,
            category_suggestion=category_name,
            suggested_category_id=category_id,
            reference_number=extracted.get("reference_number"),
            payment_status=extracted.get("payment_status", "success"),
            payment_direction=extracted.get("payment_direction", "debit"),
            confidence=extracted.get("confidence", 0.0),
            field_confidences=extracted.get("field_confidences", {}),
            validation_flags=extracted.get("validation_flags", []),
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        try:
            db.rollback()
            doc.processing_status = ProcessingStatus.FAILED.value
            db.commit()
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OCR processing failed: {str(e)}",
        )


@router.get("/{document_id}", response_model=DocumentResponse)
def get_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get document metadata and status."""
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return doc


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def discard_document(
    document_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Discard unconfirmed document draft and remove physical file from disk.
    Leaves no trace in permanent records.
    """
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    # Delete physical file
    try:
        if doc.file_url:
            p = Path(doc.file_url)
            if p.exists():
                p.unlink()
    except Exception:
        pass

    db.delete(doc)
    db.commit()
