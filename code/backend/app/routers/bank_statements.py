"""
Bank Statements router — upload, parse, list, detail, delete.

Endpoints:
  POST   /bank-statements/upload         — upload PDF or CSV
  POST   /bank-statements/{id}/parse     — trigger parsing
  GET    /bank-statements/               — list user's statements (summary)
  GET    /bank-statements/{id}           — full detail with parsed rows
  DELETE /bank-statements/{id}           — delete statement + file
"""
import uuid as _uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.bank_statement import BankStatement, StatementStatus
from app.models.user import User
from app.schemas.bank_statement import (
    BankStatementResponse,
    BankStatementSummary,
    BankStatementUploadResponse,
)
from app.services.bank_statement_service import parse_bank_statement
from app.utils.auth import get_current_user

router = APIRouter(prefix="/bank-statements", tags=["Bank Statements"])

_ALLOWED_EXTENSIONS = {".pdf", ".csv"}
_ALLOWED_MIME = {
    "application/pdf",
    "text/csv",
    "application/vnd.ms-excel",
    "application/octet-stream",  # mobile clients sometimes send this
}


# ── Upload ─────────────────────────────────────────────────────────────────────

@router.post(
    "/upload",
    response_model=BankStatementUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a bank statement (PDF or CSV)",
)
async def upload_bank_statement(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a bank statement PDF or CSV.
    The file is saved to disk and a BankStatement record is created with
    status='uploaded'. Call POST /bank-statements/{id}/parse to extract rows.
    """
    ext = Path(file.filename or "file").suffix.lower()
    if ext not in _ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type '{ext}'. Upload a PDF or CSV.",
        )

    # Save to disk
    upload_dir = Path(settings.UPLOAD_DIR) / "statements" / str(current_user.id)
    upload_dir.mkdir(parents=True, exist_ok=True)

    safe_name = f"{_uuid.uuid4()}{ext}"
    file_path = upload_dir / safe_name
    content = await file.read()
    file_path.write_bytes(content)

    stmt = BankStatement(
        user_id=current_user.id,
        original_filename=file.filename or "statement",
        file_url=str(file_path),
        mime_type=file.content_type or "application/octet-stream",
        status=StatementStatus.UPLOADED.value,
    )
    db.add(stmt)
    db.commit()
    db.refresh(stmt)
    return stmt


# ── Parse ──────────────────────────────────────────────────────────────────────

@router.post(
    "/{statement_id}/parse",
    response_model=BankStatementResponse,
    summary="Parse / re-parse a bank statement",
)
def parse_statement(
    statement_id: _uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Trigger parsing of the uploaded statement file.
    Existing parsed rows are replaced. Returns the full BankStatementResponse.
    """
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")

    if stmt.status == StatementStatus.PARSING.value:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already parsing")

    stmt.status = StatementStatus.PARSING.value
    db.commit()

    try:
        result = parse_bank_statement(stmt.file_url)

        stmt.raw_text = result["raw_text"]
        stmt.bank_name = result.get("bank_name")
        stmt.account_number = result.get("account_number")
        stmt.statement_period_from = result.get("period_from")
        stmt.statement_period_to = result.get("period_to")
        stmt.parsed_rows = result["rows"]
        stmt.total_transactions = len(result["rows"])
        stmt.total_debits = result["total_debits"]
        stmt.total_credits = result["total_credits"]
        stmt.status = StatementStatus.PARSED.value
        stmt.error_message = None

        db.commit()
        db.refresh(stmt)
        return stmt

    except Exception as exc:
        import traceback
        traceback.print_exc()
        try:
            db.rollback()
            stmt.status = StatementStatus.FAILED.value
            stmt.error_message = str(exc)[:500]
            db.commit()
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Parsing failed: {exc}",
        )


# ── List ───────────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[BankStatementSummary],
    summary="List all bank statements for the current user",
)
def list_statements(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return a list of statement summaries (no row data) for the current user."""
    stmts = (
        db.query(BankStatement)
        .filter(BankStatement.user_id == current_user.id)
        .order_by(BankStatement.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return stmts


# ── Detail ─────────────────────────────────────────────────────────────────────

@router.get(
    "/{statement_id}",
    response_model=BankStatementResponse,
    summary="Get full details + parsed rows of a statement",
)
def get_statement(
    statement_id: _uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return full statement including all parsed transaction rows."""
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")
    return stmt


# ── Delete ─────────────────────────────────────────────────────────────────────

@router.delete(
    "/{statement_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a bank statement",
)
def delete_statement(
    statement_id: _uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete the statement record and the underlying file from disk."""
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")

    # Delete file
    try:
        file_path = Path(stmt.file_url)
        if file_path.exists():
            file_path.unlink()
    except Exception:
        pass  # Don't block deletion if file is already gone

    db.delete(stmt)
    db.commit()
