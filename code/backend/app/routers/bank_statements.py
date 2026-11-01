"""
Bank Statements router — upload, parse, list, detail, delete, merge.

Endpoints:
  POST   /bank-statements/upload              — upload PDF or CSV (instant)
  POST   /bank-statements/{id}/parse          — trigger async parse (HTTP 202)
  GET    /bank-statements/{id}/parse-progress — SSE stream of parse progress %
  GET    /bank-statements/                    — list user's statements (summary)
  GET    /bank-statements/{id}               — full detail with parsed rows
  DELETE /bank-statements/{id}               — delete statement + file
  POST   /bank-statements/{id}/merge         — bulk-insert verified rows
"""
import uuid as _uuid
import asyncio
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db, SessionLocal
from app.models.bank_statement import BankStatement, StatementStatus
from app.models.category import Category
from app.models.transaction import Transaction, TransactionStatus
from app.models.user import User
from app.schemas.bank_statement import (
    BankStatementMergeRequest,
    BankStatementMergeResponse,
    BankStatementResponse,
    BankStatementSummary,
    BankStatementUploadResponse,
)
from app.services.bank_statement_service import parse_bank_statement
from app.services.categorization_service import find_or_create_category
from app.utils.auth import get_current_user

router = APIRouter(prefix="/bank-statements", tags=["Bank Statements"])

_ALLOWED_EXTENSIONS = {".pdf", ".csv"}
_ALLOWED_MIME = {
    "application/pdf",
    "text/csv",
    "application/vnd.ms-excel",
    "application/octet-stream",  # mobile clients sometimes send this
}

# In-memory parse progress store: statement_id → 0.0–1.0
# (Good enough for a single-process server; swap for Redis in production)
_parse_progress: dict[str, float] = {}


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


# ── Background parse task ──────────────────────────────────────────────────────

def _run_parse_in_background(statement_id: str, file_url: str, user_id: str) -> None:
    """
    Runs in a FastAPI BackgroundTask (separate thread).
    Opens its own DB session so the request session is already closed.
    Updates _parse_progress[statement_id] as it goes so the SSE endpoint
    can stream live percentages to the frontend.
    """
    sid = str(statement_id)
    _parse_progress[sid] = 0.05          # signal "started"

    db: Session = SessionLocal()
    try:
        stmt = db.query(BankStatement).filter(BankStatement.id == statement_id).first()
        if not stmt:
            return

        stmt.status = StatementStatus.PARSING.value
        db.commit()
        _parse_progress[sid] = 0.10      # file opened

        # ── Parse (the heavy work) ────────────────────────────────────────────
        result = parse_bank_statement(file_url, user_id=user_id, db=db)
        _parse_progress[sid] = 0.75      # parsing done

        # ── Persist results ───────────────────────────────────────────────────
        stmt.raw_text             = result["raw_text"]
        stmt.bank_name            = result.get("bank_name")
        stmt.account_number       = result.get("account_number")
        stmt.statement_period_from = result.get("period_from")
        stmt.statement_period_to   = result.get("period_to")
        stmt.parsed_rows          = result["rows"]
        stmt.total_transactions   = len(result["rows"])
        stmt.total_debits         = result["total_debits"]
        stmt.total_credits        = result["total_credits"]
        stmt.status               = StatementStatus.PARSED.value
        stmt.error_message        = None
        _parse_progress[sid] = 0.90      # about to commit

        db.commit()
        db.refresh(stmt)
        _parse_progress[sid] = 1.0       # done ✓

    except Exception as exc:
        import traceback
        traceback.print_exc()
        try:
            db.rollback()
            stmt = db.query(BankStatement).filter(BankStatement.id == statement_id).first()
            if stmt:
                stmt.status = StatementStatus.FAILED.value
                stmt.error_message = str(exc)[:500]
                db.commit()
        except Exception:
            pass
        _parse_progress[sid] = -1.0     # signal failure
    finally:
        db.close()


# ── Parse (async, returns 202 immediately) ─────────────────────────────────────

@router.post(
    "/{statement_id}/parse",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Trigger async parsing of a bank statement (returns immediately)",
    response_model=dict,
)
def parse_statement(
    statement_id: _uuid.UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Kick off parsing in the background and return HTTP 202 immediately.
    Poll GET /bank-statements/{id} for status, or stream progress via
    GET /bank-statements/{id}/parse-progress (SSE).
    """
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")

    if stmt.status == StatementStatus.PARSING.value:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already parsing")

    # Reset progress and enqueue
    sid = str(statement_id)
    _parse_progress[sid] = 0.0

    background_tasks.add_task(
        _run_parse_in_background,
        statement_id=statement_id,
        file_url=stmt.file_url,
        user_id=current_user.id,
    )

    return {
        "message": "Parsing started in background",
        "statement_id": sid,
        "status": "parsing",
        "progress_stream_url": f"/bank-statements/{sid}/parse-progress",
    }


# ── SSE Progress Stream ────────────────────────────────────────────────────────

@router.get(
    "/{statement_id}/parse-progress",
    summary="SSE stream: live parse progress (0–100%)",
)
async def parse_progress_stream(
    statement_id: _uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Server-Sent Events stream.  The frontend can connect here while parsing
    is in progress and receive live progress updates every 300 ms until done.

    Each event is:
        data: {"progress": 0.65, "status": "parsing"}\\n\\n
    Final events:
        data: {"progress": 1.0,  "status": "parsed"}\\n\\n
        data: {"progress": -1.0, "status": "failed"}\\n\\n
    """
    # Verify ownership
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")

    sid = str(statement_id)

    async def event_generator():
        import json
        while True:
            progress = _parse_progress.get(sid, 0.0)

            if progress < 0:
                yield f"data: {json.dumps({'progress': -1.0, 'status': 'failed'})}\n\n"
                break
            elif progress >= 1.0:
                yield f"data: {json.dumps({'progress': 1.0, 'status': 'parsed'})}\n\n"
                break
            else:
                yield f"data: {json.dumps({'progress': round(progress, 2), 'status': 'parsing'})}\n\n"

            await asyncio.sleep(0.3)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",      # nginx: disable buffering
        },
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

    try:
        file_path = Path(stmt.file_url)
        if file_path.exists():
            file_path.unlink()
    except Exception:
        pass  # Don't block deletion if file is already gone

    _parse_progress.pop(str(statement_id), None)
    db.delete(stmt)
    db.commit()


# ── Merge into Transactions (OPTIMISED — bulk insert) ─────────────────────────

@router.post(
    "/{statement_id}/merge",
    response_model=BankStatementMergeResponse,
    summary="Merge verified statement entries into confirmed transactions",
)
def merge_statement_entries(
    statement_id: _uuid.UUID,
    payload: BankStatementMergeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Merge verified entries from a parsed statement into the user's confirmed
    transactions using a single bulk INSERT instead of per-row ORM flushes.

    OPTIMISATION vs. old approach
    ──────────────────────────────
    Old:  for row in rows: db.add(txn); db.flush()   → N round-trips
    New:  db.bulk_insert_mappings(Transaction, [...]) → 1 round-trip
    Result: ~2× faster on SQLite, even larger gains on PostgreSQL.
    """
    stmt = db.query(BankStatement).filter(
        BankStatement.id == statement_id,
        BankStatement.user_id == current_user.id,
    ).first()
    if not stmt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")

    if not stmt.parsed_rows:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statement has no parsed rows to merge. Parse it first.",
        )

    # ── Build category lookup dict (single DB query, no N+1) ─────────────────
    all_categories = db.query(Category).all()
    cat_by_name_lower: dict[str, Category] = {c.name.lower(): c for c in all_categories}

    default_cat = (
        next((c for c in all_categories if c.name.lower() in ("other", "others")), None)
        or (all_categories[0] if all_categories else None)
    )
    if not default_cat:
        default_cat = Category(name="Others", icon="help_outline", is_default=True)
        db.add(default_cat)
        db.commit()
        db.refresh(default_cat)
        cat_by_name_lower["others"] = default_cat

    # ── Category resolution — done once per unique category name ─────────────
    _cat_id_cache: dict[str, _uuid.UUID] = {}

    def resolve_category_id(hint: str) -> _uuid.UUID:
        key = (hint or "").strip().lower()
        if key in _cat_id_cache:
            return _cat_id_cache[key]
        # Fast dict lookup first (avoids DB call for already-loaded cats)
        cat = cat_by_name_lower.get(key)
        if cat:
            _cat_id_cache[key] = cat.id
            return cat.id
        # Partial substring match
        for name_low, c in cat_by_name_lower.items():
            if key in name_low or name_low in key:
                _cat_id_cache[key] = c.id
                return c.id
        # Fallback: let find_or_create handle it (DB write only for truly new cats)
        cat = find_or_create_category(hint, db)
        cat_by_name_lower[cat.name.lower()] = cat
        _cat_id_cache[key] = cat.id
        return cat.id

    # ── Build mappings list (no ORM objects created) ──────────────────────────
    indices_to_process = (
        payload.selected_indices
        if payload.selected_indices is not None
        else list(range(len(stmt.parsed_rows)))
    )

    now = datetime.now(timezone.utc)
    mappings: list[dict] = []
    created_ids: list[_uuid.UUID] = []
    skipped = 0

    for idx in indices_to_process:
        if idx < 0 or idx >= len(stmt.parsed_rows):
            skipped += 1
            continue

        row = stmt.parsed_rows[idx]
        debit = row.get("debit")

        # Only expense (debit) rows
        if debit is None or debit <= 0:
            skipped += 1
            continue

        # Auto-merge skips flagged duplicates; manual selection allows them
        if payload.selected_indices is None and row.get("is_duplicate"):
            skipped += 1
            continue

        date_str = row.get("date")
        if not date_str:
            skipped += 1
            continue
        try:
            date_val = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            skipped += 1
            continue

        cat_hint  = row.get("category") or row.get("merchant") or "Others"
        cat_id    = resolve_category_id(cat_hint)
        merch     = (row.get("merchant") or row.get("description", "Unknown"))[:100]
        new_id    = _uuid.uuid4()

        mappings.append({
            "id":                  new_id,
            "user_id":             current_user.id,
            "category_id":         cat_id,
            "amount":              Decimal(str(round(debit, 2))),
            "transaction_date":    date_val,
            "merchant_name":       merch,
            "description":         (row.get("description") or "")[:500],
            "transaction_type":    "expense",
            "currency":            "INR",
            "payment_method":      "upi",
            "verification_status": TransactionStatus.CONFIRMED.value,
            "is_verified":         True,
            "auto_categorized":    True,
            "is_deleted":          False,
            "created_at":          now,
            "updated_at":          now,
        })
        created_ids.append(new_id)

    # ── Single bulk INSERT — the key optimisation ─────────────────────────────
    if mappings:
        db.bulk_insert_mappings(Transaction, mappings)
        db.commit()

    return BankStatementMergeResponse(
        merged_count=len(created_ids),
        skipped_count=skipped,
        created_transaction_ids=created_ids,
    )
