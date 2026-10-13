"""Documents router — upload files and trigger OCR processing."""
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.document import Document, DocumentType, ProcessingStatus
from app.models.transaction import Transaction, TransactionItem, VerificationStatus
from app.models.user import User
from app.schemas.document import DocumentResponse, OCRResult
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
    document_type: DocumentType = Form(DocumentType.RECEIPT),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a receipt, bill, or UPI screenshot.
    File is saved to disk and a Document record is created.
    Call POST /documents/{id}/process to run OCR.
    """
    # Validate MIME type
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

    # Ensure upload directory exists
    upload_dir = Path(settings.UPLOAD_DIR) / str(current_user.id)
    upload_dir.mkdir(parents=True, exist_ok=True)

    # Generate safe filename
    ext = Path(file.filename or "file").suffix or ".jpg"
    safe_name = f"{uuid.uuid4()}{ext}"
    file_path = upload_dir / safe_name

    content = await file.read()
    file_path.write_bytes(content)

    doc = Document(
        user_id=current_user.id,
        original_filename=file.filename or "unknown",
        file_url=str(file_path),
        mime_type=final_content_type,
        document_type=document_type.value if hasattr(document_type, "value") else str(document_type),
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
    Run OCR on an uploaded document and extract transaction data.
    Returns structured OCRResult for user verification before saving.
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
        raw_text = run_ocr(doc.file_url) # doc.file_path was replaced with doc.file_url
        doc.ocr_text = raw_text

        extracted = extract_transaction_data(raw_text)

        # Suggest category
        category_name = None
        if extracted.get("merchant_name"):
            cat_id = categorize_merchant(extracted["merchant_name"], current_user.id, db)
            if cat_id:
                from app.models.category import Category
                cat = db.query(Category).filter(Category.id == cat_id).first()
                category_name = cat.name if cat else None

        doc.processing_status = ProcessingStatus.PROCESSED.value
        if "confidence" in extracted:
            doc.ocr_confidence = extracted.get("confidence", 0.0)
        db.commit()

        return OCRResult(
            document_id=doc.id,
            raw_text=raw_text,
            merchant_name=extracted.get("merchant_name"),
            amount=extracted.get("amount"),
            tax_amount=extracted.get("tax_amount"),
            date=extracted.get("date"),
            items=extracted.get("items", []),
            category_suggestion=category_name,
            confidence=extracted.get("confidence", 0.0),
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
    """Get document metadata and OCR results."""
    doc = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id,
    ).first()
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return doc
