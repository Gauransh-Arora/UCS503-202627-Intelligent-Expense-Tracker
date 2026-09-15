"""
Categorization Service — rule-based merchant categorization with user preference override.

Priority:
1. User's saved preferences (highest priority)
2. Global rule map (keyword → category name)
3. None (caller can fall back to "Other")
"""
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.preference import UserCategoryPreference

# ── Global rule map ───────────────────────────────────────────────────────────
# Maps lowercase merchant keywords → category name
MERCHANT_CATEGORY_RULES: dict[str, str] = {
    # Food
    "swiggy": "Food",
    "zomato": "Food",
    "domino": "Food",
    "pizza": "Food",
    "mcdonald": "Food",
    "kfc": "Food",
    "burger king": "Food",
    "subway": "Food",
    "starbucks": "Food",
    "cafe coffee day": "Food",
    "ccd": "Food",
    "haldiram": "Food",
    "barbeque nation": "Food",
    "restaurant": "Food",
    "dhaba": "Food",
    "hotel": "Food",

    # Groceries
    "bigbasket": "Groceries",
    "blinkit": "Groceries",
    "zepto": "Groceries",
    "reliance fresh": "Groceries",
    "dmart": "Groceries",
    "more supermarket": "Groceries",
    "spencer": "Groceries",
    "grofers": "Groceries",
    "jiomart": "Groceries",
    "nature basket": "Groceries",
    "supermarket": "Groceries",
    "grocery": "Groceries",
    "kirana": "Groceries",

    # Transport
    "uber": "Transport",
    "ola": "Transport",
    "rapido": "Transport",
    "namma yatri": "Transport",
    "irctc": "Transport",
    "makemytrip": "Transport",
    "redbus": "Transport",
    "metro": "Transport",
    "auto": "Transport",
    "rickshaw": "Transport",
    "petrol": "Transport",
    "diesel": "Transport",
    "hp petrol": "Transport",
    "indian oil": "Transport",
    "bharat petroleum": "Transport",

    # Shopping
    "amazon": "Shopping",
    "flipkart": "Shopping",
    "myntra": "Shopping",
    "ajio": "Shopping",
    "meesho": "Shopping",
    "nykaa": "Shopping",
    "snapdeal": "Shopping",
    "decathlon": "Shopping",
    "h&m": "Shopping",
    "zara": "Shopping",
    "max fashion": "Shopping",
    "reliance trends": "Shopping",
    "lifestyle": "Shopping",

    # Entertainment
    "netflix": "Entertainment",
    "prime video": "Entertainment",
    "hotstar": "Entertainment",
    "disney": "Entertainment",
    "zee5": "Entertainment",
    "sony liv": "Entertainment",
    "spotify": "Entertainment",
    "jiosaavn": "Entertainment",
    "gaana": "Entertainment",
    "pvr": "Entertainment",
    "inox": "Entertainment",
    "bookmyshow": "Entertainment",
    "steam": "Entertainment",

    # Bills
    "bsnl": "Bills",
    "airtel": "Bills",
    "jio": "Bills",
    "vodafone": "Bills",
    "vi ": "Bills",
    "tata sky": "Bills",
    "dish tv": "Bills",
    "electricity": "Bills",
    "bescom": "Bills",
    "tata power": "Bills",
    "adani electricity": "Bills",
    "water bill": "Bills",
    "gas bill": "Bills",
    "indane": "Bills",
    "hp gas": "Bills",
    "bharat gas": "Bills",

    # Healthcare
    "apollo": "Healthcare",
    "fortis": "Healthcare",
    "max hospital": "Healthcare",
    "1mg": "Healthcare",
    "medplus": "Healthcare",
    "netmeds": "Healthcare",
    "pharmeasy": "Healthcare",
    "pharmacy": "Healthcare",
    "medical": "Healthcare",
    "hospital": "Healthcare",
    "clinic": "Healthcare",
    "doctor": "Healthcare",
    "diagnostics": "Healthcare",
    "dr lal": "Healthcare",

    # Education
    "byju": "Education",
    "unacademy": "Education",
    "vedantu": "Education",
    "coursera": "Education",
    "udemy": "Education",
    "chegg": "Education",
    "school": "Education",
    "college": "Education",
    "university": "Education",
    "tuition": "Education",
    "coaching": "Education",

    # Travel
    "goibibo": "Travel",
    "yatra": "Travel",
    "cleartrip": "Travel",
    "easemytrip": "Travel",
    "oyo": "Travel",
    "treebo": "Travel",
    "hotel booking": "Travel",
    "air india": "Travel",
    "indigo": "Travel",
    "spicejet": "Travel",
    "vistara": "Travel",
    "akasa": "Travel",

    # Subscriptions
    "microsoft 365": "Subscriptions",
    "office 365": "Subscriptions",
    "google one": "Subscriptions",
    "icloud": "Subscriptions",
    "dropbox": "Subscriptions",
    "notion": "Subscriptions",
    "canva": "Subscriptions",
    "github": "Subscriptions",
    "chatgpt": "Subscriptions",
    "claude": "Subscriptions",
}


def categorize_merchant(
    merchant_name: str,
    user_id: UUID,
    db: Session,
) -> UUID | None:
    """
    Returns the category UUID for the given merchant name.

    Priority:
    1. User-specific preference (learned from corrections)
    2. Global rule map
    3. None
    """
    merchant_lower = merchant_name.lower().strip()

    # 1. Check user preferences
    pref = (
        db.query(UserCategoryPreference)
        .filter(UserCategoryPreference.user_id == user_id)
        .all()
    )
    for p in pref:
        if p.merchant_keyword.lower() in merchant_lower:
            return p.category_id

    # 2. Check global rules
    for keyword, category_name in MERCHANT_CATEGORY_RULES.items():
        if keyword in merchant_lower:
            cat = db.query(Category).filter(Category.name == category_name).first()
            if cat:
                return cat.id

    return None


def save_user_preference(
    merchant_name: str,
    category_id: UUID,
    user_id: UUID,
    db: Session,
) -> None:
    """
    Save or update a user's merchant→category preference.
    Called when the user corrects an auto-categorized transaction.
    """
    keyword = merchant_name.lower().strip()

    existing = (
        db.query(UserCategoryPreference)
        .filter(
            UserCategoryPreference.user_id == user_id,
            UserCategoryPreference.merchant_keyword == keyword,
        )
        .first()
    )

    if existing:
        existing.category_id = category_id
        existing.usage_count += 1
    else:
        db.add(
            UserCategoryPreference(
                user_id=user_id,
                category_id=category_id,
                merchant_keyword=keyword,
            )
        )
    db.commit()
