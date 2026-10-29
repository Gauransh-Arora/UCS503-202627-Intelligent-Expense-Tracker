"""
Categorization Service — data-driven merchant categorization with user preference overrides.

Priority:
1. User-specific preferences learned from corrections (highest priority)
2. Data-driven global rules loaded from config/JSON
3. None (caller falls back to 'Other')
"""
import json
import logging
from pathlib import Path
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.preference import UserCategoryPreference

logger = logging.getLogger(__name__)

_RULES_FILE = Path(__file__).resolve().parent.parent / "data" / "merchant_category_rules.json"
_CACHED_RULES: dict[str, str] | None = None
_CACHED_MTIME: float = 0.0


def get_global_merchant_rules() -> dict[str, str]:
    """
    Load data-driven merchant category rules from JSON file.
    Reloads dynamically if file modification time changes.
    """
    global _CACHED_RULES, _CACHED_MTIME
    try:
        if _RULES_FILE.exists():
            mtime = _RULES_FILE.stat().st_mtime
            if _CACHED_RULES is None or mtime != _CACHED_MTIME:
                with open(_RULES_FILE, "r", encoding="utf-8") as f:
                    _CACHED_RULES = json.load(f)
                _CACHED_MTIME = mtime
            return _CACHED_RULES or {}
    except Exception as e:
        logger.warning(f"Failed to load merchant rules from {_RULES_FILE}: {e}")

    if _CACHED_RULES is not None:
        return _CACHED_RULES
    return {}


# Backward compatibility alias
MERCHANT_CATEGORY_RULES = get_global_merchant_rules()


def categorize_merchant(
    merchant_name: str,
    user_id: UUID,
    db: Session,
) -> UUID | None:
    """
    Returns the category UUID for the given merchant name.

    Priority:
    1. User-specific preference (learned from corrections, highest priority)
    2. Data-driven global rule map (from JSON config)
    3. None
    """
    if not merchant_name or not merchant_name.strip():
        return None

    merchant_lower = merchant_name.lower().strip()

    # 1. User preferences take precedence
    preferences = (
        db.query(UserCategoryPreference)
        .filter(UserCategoryPreference.user_id == user_id)
        .all()
    )
    for p in preferences:
        pref_name = p.merchant_name.lower().strip()
        if pref_name in merchant_lower or merchant_lower in pref_name:
            return p.category_id

    # 2. Check global data-driven rules
    rules = get_global_merchant_rules()
    for keyword, category_name in rules.items():
        if keyword.lower() in merchant_lower:
            cat = db.query(Category).filter(Category.name.ilike(category_name)).first()
            if cat:
                return cat.id

    return None


def save_user_preference(
    merchant_name: str,
    category_id: UUID,
    user_id: UUID,
    db: Session,
) -> UserCategoryPreference:
    """
    Save or update a user's merchant→category preference.
    Called when the user corrects an auto-categorized or draft transaction.
    """
    name_lower = merchant_name.lower().strip()

    existing = (
        db.query(UserCategoryPreference)
        .filter(
            UserCategoryPreference.user_id == user_id,
            UserCategoryPreference.merchant_name == name_lower,
        )
        .first()
    )

    if existing:
        existing.category_id = category_id
        pref = existing
    else:
        pref = UserCategoryPreference(
            user_id=user_id,
            category_id=category_id,
            merchant_name=name_lower,
        )
        db.add(pref)

    db.commit()
    db.refresh(pref)
    return pref


def categorize_transaction(
    merchant_name: str = "",
    description: str = "",
    user_id: UUID | None = None,
    db: Session | None = None,
) -> tuple[str, float]:
    """
    Returns (category_name, confidence).
    Checks user preference first, then data-driven rules, then description keywords.
    """
    text = (merchant_name or description or "").strip().lower()
    if not text:
        return "Others", 0.0

    if user_id and db:
        preferences = (
            db.query(UserCategoryPreference)
            .filter(UserCategoryPreference.user_id == user_id)
            .all()
        )
        for p in preferences:
            if p.merchant_name.lower() in text or text in p.merchant_name.lower():
                cat = db.query(Category).filter(Category.id == p.category_id).first()
                if cat:
                    return cat.name, 1.0

    rules = get_global_merchant_rules()
    for kw, cat_name in rules.items():
        if kw.lower() in text:
            if db:
                matched_db_cat = (
                    db.query(Category)
                    .filter(
                        (Category.name.ilike(cat_name))
                        | (Category.name.ilike(f"{cat_name}%"))
                        | (Category.name.ilike(f"%{cat_name}%"))
                    )
                    .first()
                )
                if matched_db_cat:
                    return matched_db_cat.name, 0.85
            return cat_name, 0.85

    return "Others", 0.50


def learn_user_category_preference(
    user_id: UUID,
    merchant_name: str,
    category_name: str,
    db: Session,
) -> UserCategoryPreference:
    """Save user category preference by category name."""
    cat = find_or_create_category(category_name, db)
    return save_user_preference(merchant_name, cat.id, user_id, db)


def find_or_create_category(
    category_name_or_keyword: str | None,
    db: Session,
) -> Category:
    """
    Intelligently resolve a category by name, alias, keyword, or create it if new.
    Always returns a valid Category object.
    """
    all_cats = db.query(Category).all()
    if not all_cats:
        # Fallback create default categories if DB was somehow empty
        from app.models.category import DEFAULT_CATEGORIES
        for name, icon in DEFAULT_CATEGORIES:
            db.add(Category(name=name, icon=icon, is_default=True))
        db.commit()
        all_cats = db.query(Category).all()

    default_cat = (
        next((c for c in all_cats if c.name.lower() in ("other", "others")), None)
        or all_cats[0]
    )

    if not category_name_or_keyword or not str(category_name_or_keyword).strip():
        return default_cat

    clean = str(category_name_or_keyword).strip().lower()

    # 1. Exact match (case-insensitive)
    for c in all_cats:
        if c.name.lower() == clean:
            return c

    # 2. Known common UI aliases and synonyms
    alias_map = {
        "food & dining": "Food",
        "food and dining": "Food",
        "dining": "Food",
        "restaurant": "Food",
        "cafe": "Food",
        "health": "Healthcare",
        "health & fitness": "Healthcare",
        "medical": "Healthcare",
        "pharmacy": "Healthcare",
        "travel": "Travel",
        "transport": "Transport",
        "transportation": "Transport",
        "cab": "Transport",
        "commute": "Transport",
        "shopping": "Shopping",
        "grocery": "Groceries",
        "groceries": "Groceries",
        "supermarket": "Groceries",
        "bill": "Bills",
        "bills & utilities": "Bills",
        "utilities": "Bills",
        "electricity": "Bills",
        "entertainment": "Entertainment",
        "movies": "Entertainment",
        "education": "Education",
        "tuition": "Education",
        "rent": "Rent",
        "housing": "Rent",
        "subscription": "Subscriptions",
        "subscriptions": "Subscriptions",
        "other": "Other",
        "others": "Other",
        "uncategorized": "Other",
    }

    target = alias_map.get(clean)
    if target:
        for c in all_cats:
            if c.name.lower() == target.lower():
                return c

    # 3. Substring / contains match
    for c in all_cats:
        c_low = c.name.lower()
        if c_low in clean or clean in c_low:
            return c

    # 4. If nothing matched, create category so user-entered custom category works dynamically
    new_cat = Category(
        name=category_name_or_keyword.strip().title(),
        icon="📦",
        is_default=False,
    )
    db.add(new_cat)
    db.commit()
    db.refresh(new_cat)
    return new_cat
