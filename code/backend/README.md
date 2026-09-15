# Intelligent Expense Tracker — Backend

FastAPI backend connected to Supabase PostgreSQL.

## Stack
| Layer | Technology |
|-------|-----------|
| API Framework | FastAPI 0.141+ |
| ORM | SQLAlchemy 2.0 |
| Database | Supabase PostgreSQL (via psycopg2) |
| Auth | JWT (python-jose) + bcrypt (passlib) |
| OCR | Tesseract + pytesseract |
| Package Manager | uv |
| Python | 3.14 |

## Project Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI app, CORS, lifespan, router includes
│   ├── config.py            # pydantic-settings — reads .env
│   ├── database.py          # SQLAlchemy engine + session + Base
│   ├── models/              # ORM models (User, Transaction, Document, Split, Wishlist…)
│   ├── schemas/             # Pydantic I/O schemas
│   ├── routers/             # Route handlers (auth, transactions, documents, splits…)
│   ├── services/            # Business logic (OCR, categorization, analytics, NL…)
│   └── utils/               # security.py (bcrypt/JWT) + auth.py (dependency)
├── uploads/                 # User-uploaded files (gitignored)
├── .env                     # Secrets (gitignored)
├── .gitignore
├── pyproject.toml
└── README.md
```

## Setup

### 1. Prerequisites
- Python 3.14+
- [uv](https://docs.astral.sh/uv/) — `pip install uv`
- Tesseract OCR — `brew install tesseract` (macOS)
- poppler (for PDF OCR) — `brew install poppler`

### 2. Install dependencies
```bash
cd code/backend
uv sync
```

### 3. Configure environment
The `.env` file already contains your Supabase connection string:
```
DATABASE_URL=postgresql://...
```

Add a strong secret key for JWT:
```
SECRET_KEY=your-long-random-secret-here
```

### 4. Run the server
```bash
uv run uvicorn app.main:app --reload
```

Server starts at: **http://127.0.0.1:8000**

Interactive docs: **http://127.0.0.1:8000/docs**

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Register new user, returns JWT |
| POST | `/auth/login` | Login, returns JWT |
| GET | `/auth/me` | Get current user profile |

### Transactions
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/transactions` | Create expense |
| GET | `/transactions` | List with filters (category, month, date range, merchant) |
| GET | `/transactions/{id}` | Get single transaction |
| PUT | `/transactions/{id}` | Update (triggers preference learning on category change) |
| DELETE | `/transactions/{id}` | Soft delete |

### Documents & OCR
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/documents/upload` | Upload receipt/bill (JPEG, PNG, PDF) |
| POST | `/documents/{id}/process` | Run OCR → returns structured data for user verification |
| GET | `/documents/{id}` | Get document metadata |

### Analytics
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/analytics/summary` | Dashboard summary (current vs prev month, alerts) |
| GET | `/analytics/monthly?month=9&year=2026` | Detailed monthly breakdown |
| GET | `/analytics/categories` | Spending by category |
| GET | `/analytics/merchants` | Top merchants |
| GET | `/analytics/trends?months=6` | Monthly spending trend |

### Expense Splitting
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/splits` | Create split (equal/percentage/custom) |
| GET | `/splits` | List all splits |
| GET | `/splits/{id}` | Get split detail |
| POST | `/splits/settlements` | Record a settlement |

### Wishlist
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/wishlist` | Add wishlist item |
| GET | `/wishlist` | List all items |
| PUT | `/wishlist/{id}` | Update item |
| DELETE | `/wishlist/{id}` | Remove item |
| GET | `/wishlist/{id}/readiness` | Purchase readiness analysis (0–100) |

### AI Queries
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/ai/query` | Ask natural language question about expenses |

**Example queries:**
- "How much did I spend on food last month?"
- "Where did most of my money go this month?"
- "What are my recurring expenses?"
- "How much did I spend at Swiggy?"

## Security Notes

- Passwords are hashed with bcrypt (never stored in plaintext)
- JWT tokens expire after 7 days
- Every query filters by `user_id` — users cannot access each other's data
- `.env` is gitignored — never commit credentials
- File uploads validate MIME type before saving
- NL queries use only safe parameterised SQLAlchemy — no raw SQL from user input

## Development Order

1. Test `/ping` → should return `{"status": "ok"}`
2. `POST /auth/register` → create account
3. `POST /auth/login` → get token
4. Use token as Bearer in Swagger Authorize
5. `POST /transactions` → add expenses
6. `GET /analytics/summary` → see dashboard data
7. `POST /documents/upload` + `POST /documents/{id}/process` → test OCR
8. `POST /ai/query` → test NL queries
