"""
Benchmark: Parse + DB upload timing for Bank_Statement_Nov2025_Oct2026.csv
Run from the backend directory:
    cd code/backend && python tests/benchmark_statement.py
"""
import os, sys, time
from pathlib import Path
from decimal import Decimal
from datetime import datetime

# ── make sure 'app' is importable ──────────────────────────────────────────────
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# ── load .env if present ───────────────────────────────────────────────────────
env_file = BACKEND_DIR.parent.parent / ".env"
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

os.environ.setdefault("DATABASE_URL", f"sqlite:///{BACKEND_DIR.parent.parent}/expenses.db")

STATEMENT_CSV = Path(__file__).parent / "Bank_Statement_Nov2025_Oct2026.csv"

# ── colour helpers ─────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
RED    = "\033[91m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def banner(text: str) -> None:
    print(f"\n{BOLD}{CYAN}{'─'*60}{RESET}")
    print(f"{BOLD}{CYAN}  {text}{RESET}")
    print(f"{BOLD}{CYAN}{'─'*60}{RESET}")

def ok(label: str, value: str) -> None:
    print(f"  {GREEN}✔{RESET}  {label:40s}  {BOLD}{value}{RESET}")

def info(label: str, value: str) -> None:
    print(f"  {YELLOW}→{RESET}  {label:40s}  {value}")


# ══════════════════════════════════════════════════════════════════════════════
# 1. PARSE BENCHMARK
# ══════════════════════════════════════════════════════════════════════════════
banner("PHASE 1 — Parsing the bank statement CSV")

from app.services.bank_statement_service import _parse_csv

# ── Cold run (includes any first-import overhead) ────────────────────────────
t0 = time.perf_counter()
rows, meta = _parse_csv(str(STATEMENT_CSV))
parse_time_cold = time.perf_counter() - t0

# ── Warm run (rules already cached) ──────────────────────────────────────────
t0 = time.perf_counter()
rows, meta = _parse_csv(str(STATEMENT_CSV))
parse_time_warm = time.perf_counter() - t0

total_rows        = len(rows)
debit_rows        = [r for r in rows if r.get("debit")]
credit_rows       = [r for r in rows if r.get("credit")]
total_debit_amt   = sum(r["debit"]  for r in debit_rows)
total_credit_amt  = sum(r["credit"] for r in credit_rows)
unique_categories = len({r["category"] for r in rows})
unique_merchants  = len({r["merchant"] for r in rows})

ok("Rows parsed",               str(total_rows))
ok("Debit transactions",        f"{len(debit_rows)}  (₹{total_debit_amt:,.2f})")
ok("Credit transactions",       f"{len(credit_rows)}  (₹{total_credit_amt:,.2f})")
ok("Unique merchants detected", str(unique_merchants))
ok("Categories auto-assigned",  str(unique_categories))
info("Period",                  f"{meta.get('period_from')}  →  {meta.get('period_to')}")

print()
ok("Parse time  (cold, incl. import)", f"{parse_time_cold*1000:.1f} ms")
ok("Parse time  (warm / cached)",      f"{parse_time_warm*1000:.1f} ms")
info("Per-row cost (warm)",            f"{parse_time_warm/max(total_rows,1)*1000:.3f} ms/row")


# ══════════════════════════════════════════════════════════════════════════════
# 2. DB UPLOAD BENCHMARK  (naive sequential — current behaviour)
# ══════════════════════════════════════════════════════════════════════════════
banner("PHASE 2 — DB upload timing  (current sequential approach)")

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.transaction import Transaction, TransactionStatus
from app.models.category import Category
import uuid
from datetime import timezone

db: Session = SessionLocal()

# Grab (or create) a throw-away test category
test_cat = db.query(Category).filter_by(name="BenchmarkCategory").first()
if not test_cat:
    test_cat = Category(name="BenchmarkCategory", icon="science", is_default=False)
    db.add(test_cat)
    db.commit()
    db.refresh(test_cat)

FAKE_USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")

# ── Sequential (ORM add, one by one inside one transaction) ─────────────────
def make_txn(row: dict) -> Transaction:
    date_val = datetime.strptime(row["date"], "%Y-%m-%d").date()
    return Transaction(
        user_id=FAKE_USER_ID,
        category_id=test_cat.id,
        amount=Decimal(str(round(row["debit"], 2))),
        transaction_date=date_val,
        merchant_name=(row.get("merchant") or "Unknown")[:100],
        description=(row.get("description") or "")[:500],
        transaction_type="expense",
        currency="INR",
        payment_method="upi",
        verification_status="auto",
        is_verified=True,
        auto_categorized=False,
        is_deleted=False,
    )

txn_objects = [make_txn(r) for r in debit_rows]

t0 = time.perf_counter()
for txn in txn_objects:
    db.add(txn)
db.commit()
db_seq_time = time.perf_counter() - t0

# Collect IDs after commit
seq_ids = [t.id for t in txn_objects]

ok("Rows inserted (sequential)", str(len(txn_objects)))
ok("DB sequential time",         f"{db_seq_time*1000:.1f} ms")
info("Per-row cost",             f"{db_seq_time/max(len(txn_objects),1)*1000:.3f} ms/row")

# ── Cleanup sequential run ───────────────────────────────────────────────────
db.query(Transaction).filter(Transaction.id.in_(seq_ids)).delete(synchronize_session=False)
db.commit()


# ══════════════════════════════════════════════════════════════════════════════
# 3. OPTIMISED BULK INSERT  (bulk_insert_mappings — no ORM overhead per row)
# ══════════════════════════════════════════════════════════════════════════════
banner("PHASE 3 — Optimised bulk insert  (bulk_insert_mappings)")

now = datetime.now(timezone.utc)
bulk_ids = [uuid.uuid4() for _ in debit_rows]

mappings = [
    {
        "id":                  bulk_ids[i],
        "user_id":             FAKE_USER_ID,
        "category_id":         test_cat.id,
        "amount":              Decimal(str(round(r["debit"], 2))),
        "transaction_date":    datetime.strptime(r["date"], "%Y-%m-%d").date(),
        "merchant_name":       (r.get("merchant") or "Unknown")[:100],
        "description":         (r.get("description") or "")[:500],
        "transaction_type":    "expense",
        "currency":            "INR",
        "payment_method":      "upi",
        "verification_status": "auto",
        "is_verified":         True,
        "auto_categorized":    False,
        "is_deleted":          False,
        "created_at":          now,
        "updated_at":          now,
    }
    for i, r in enumerate(debit_rows)
]

t0 = time.perf_counter()
db.bulk_insert_mappings(Transaction, mappings)
db.commit()
db_bulk_time = time.perf_counter() - t0

ok("Rows inserted (bulk)",   str(len(mappings)))
ok("DB bulk insert time",    f"{db_bulk_time*1000:.1f} ms")
info("Per-row cost",         f"{db_bulk_time/max(len(mappings),1)*1000:.3f} ms/row")

speedup = db_seq_time / max(db_bulk_time, 0.0001)
ok("Speed-up vs sequential", f"{speedup:.1f}×  🚀")

# ── Cleanup bulk run ─────────────────────────────────────────────────────────
db.query(Transaction).filter(Transaction.id.in_(bulk_ids)).delete(synchronize_session=False)
db.commit()
db.close()


# ══════════════════════════════════════════════════════════════════════════════
# 4. SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
banner("SUMMARY")
total_optimised = parse_time_warm + db_bulk_time
total_current   = parse_time_warm + db_seq_time

print(f"""
  {BOLD}Statement file  {RESET}  {STATEMENT_CSV.name}
  {BOLD}Total rows      {RESET}  {total_rows}  ({len(debit_rows)} debits, {len(credit_rows)} credits)

  ┌──────────────────────────────────────┬────────────────┐
  │  Step                                │  Time          │
  ├──────────────────────────────────────┼────────────────┤
  │  CSV parse  (cold, incl. imports)    │  {parse_time_cold*1000:>7.1f} ms     │
  │  CSV parse  (warm / cached rules)    │  {parse_time_warm*1000:>7.1f} ms     │
  │  DB insert  (sequential, current)    │  {db_seq_time*1000:>7.1f} ms     │
  │  DB insert  (bulk_insert_mappings)   │  {db_bulk_time*1000:>7.1f} ms  ←   │
  ├──────────────────────────────────────┼────────────────┤
  │  Total  (current  = warm + seq)      │  {total_current*1000:>7.1f} ms     │
  │  Total  (optimised = warm + bulk)    │  {total_optimised*1000:>7.1f} ms     │
  └──────────────────────────────────────┴────────────────┘

  {GREEN}{BOLD}Bulk insert is {speedup:.1f}× faster than sequential inserts.{RESET}
""")

print(f"{BOLD}What we'll fix in the router:{RESET}")
recs = [
    ("Switch merge to bulk_insert_mappings",
     "One SQL executemany instead of N individual INSERTs"),
    ("Return HTTP 202 + background task for /parse",
     "User gets instant response; polls status or gets SSE progress"),
    ("Stream SSE progress (parse %) to frontend",
     "Show a live row-count progress bar while large files parse"),
    ("Cache category lookups per-request",
     "One DB query → dict, avoid N+1 per row during merge"),
    ("Intra-file dedup in-memory (already done)",
     "Cross-history query is already batched — no extra work"),
]
for title, detail in recs:
    print(f"  {GREEN}•{RESET}  {BOLD}{title}{RESET}")
    print(f"      {detail}")
print()
