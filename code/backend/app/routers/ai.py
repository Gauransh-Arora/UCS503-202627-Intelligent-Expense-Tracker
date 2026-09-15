"""AI natural-language query router."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.ai import NLQueryRequest, NLQueryResponse
from app.services.nl_service import answer_nl_query
from app.utils.auth import get_current_user

router = APIRouter(prefix="/ai", tags=["AI Queries"])


@router.post("/query", response_model=NLQueryResponse)
def natural_language_query(
    request: NLQueryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Answer a natural-language question about the user's expenses.

    Examples:
    - "How much did I spend on food last month?"
    - "What are my recurring expenses?"
    - "Where did most of my money go this year?"
    - "How much did I spend at Swiggy?"
    """
    return answer_nl_query(request.question, current_user.id, db)
