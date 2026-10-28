# Gap Analysis and Audit Report — Intelligent Expense Tracker

**Date:** 2026-10-28  
**Project:** UCS503 Software Engineering Course Project — Intelligent Expense Tracker  
**Author:** Senior Full-Stack Engineering Audit  

---

## 1. Executive Summary

This audit evaluates the codebase against the UCS503 course project specification. The repository contains a functional FastAPI backend and Flutter mobile frontend, with baseline integration for authentication, transaction CRUD, OCR (PaddleOCR/Tesseract), split calculations, basic analytics, and natural language querying.

However, several critical gaps, architectural mismatches, and violations of non-negotiable rules were identified:
1. **Missing Data Models & Modules:** `BudgetPlan` is completely absent; `calculate_discretionary_budget` hardcodes a 20% savings reserve instead of using budget plans. Bank statement parsing has no duplicate detection and no merge endpoint to insert verified transactions into history.
2. **Money Correctness Violation:** All financial amounts in models, schemas, and split calculators use Python `float` and SQL `Float` instead of `Decimal` and `NUMERIC(12, 2)`, with custom split allowing up to 50 paise slack instead of deterministic exact reconciliation.
3. **Hardcoded Configurations:** Merchant-to-category rules are hardcoded in Python code (`categorization_service.py`), seed scripts use hardcoded UUIDs (`seed_mock.py`), and the Flutter app hardcodes a LAN IP (`172.16.213.72:8000`). `.env.example` is missing.
4. **OCR & Verification Pipeline Deficiencies:** Image preprocessing before OCR is missing. In the Flutter OCR review screen, the user's category selection and the `document_id` are omitted from the confirmation payload, breaking the user-correction feedback loop and document linking. Discarding drafts does not clean up uploaded files.
5. **NLQ Fallback Violation:** Unsupported natural-language queries default to returning total spending rather than honestly reporting inability to answer.
6. **Testing Deficiencies:** Existing test suite has only 19 backend tests and 1 frontend smoke test. There are no tests for currency formatting variations, date parsing edge cases, duplicate detection, user isolation, bank statement merging, or frontend screen states. Synthetic fixtures generator is missing.

---

## 2. Gap Analysis Matrix

| Feature / UC | Status | Evidence (File, Failing Test, Error) | Planned Fix |
|---|---|---|---|
| **Auth & Profile** | Working | `app/routers/auth.py`, `app/services/auth_service.py`. JWT + bcrypt works. `test_auth_and_expenses.py` passes. | Add profile update methods (`updateProfile()`), strengthen token expiry & settings configuration. |
| **Manual Entry** | Working | `app/routers/transactions.py`, `app/services/transaction_service.py`, `lib/features/add_expense/manual_expense_screen.dart`. | Convert amount representation to `Decimal`/`NUMERIC`. Add category preference learning when category is explicitly selected. |
| **UC-01: Extract Expense (Bill / UPI)** | Partially working | `app/services/ocr_service.py`, `app/services/extraction_service.py`. Naive confidence (`fields_found / 3`). No image preprocessing (grayscale, contrast, deskew). No validation of total = items + tax - discount. No UPI payment status (success/failed/pending) or direction checking. | Add image preprocessing module using PIL. Implement line-item/tax reconciliation and per-field confidence scores. Detect UPI status (flag failed/pending) and direction (debit vs credit). |
| **UC-02: Verify & Confirm Extracted Transaction** | Broken | `lib/features/add_expense/ocr_flow/ocr_review_screen.dart` lines 73-85: `category_id` and `document_id` are omitted in payload. Discard draft leaves uploaded file indefinitely. Confirming twice creates duplicates. | Fix frontend payload to pass `category_id` and `document_id`. Feed corrections into user preferences on confirmation. Add `DELETE /documents/{id}` for discarding drafts. Ensure idempotent confirmation. |
| **UC-03: Split Shared Expense** | Partially working | `app/services/split_service.py`, `app/models/split.py`. Uses `float`, custom split tolerance allows ±0.50 discrepancy. Model lacks `amount_settled` on participant and `outstandingAmount()` method. Ledger uses fragile name string matching. | Refactor models & calculations to `Decimal`/`NUMERIC`. Enforce exact sum-to-total validation with deterministic remainder assignment. Add settlement ledger tracking per participant and contact. |
| **UC-04: View Spending Analytics** | Partially working | `app/services/analytics_service.py`, `app/routers/analytics.py`. Dimension drill-down endpoint missing. Frontend has some static mock fallbacks. | Implement `/analytics/drilldown` endpoint for category/merchant/item drill-down. Wire frontend directly to live analytics API with zero mock data. |
| **UC-05: Recurring & Unusual Spending** | Partially working | `app/services/intelligence_service.py`, `app/services/recurring_service.py`. Unusual spending uses hardcoded thresholds (1.8x, 3.0x, 1500) without statistical rule (mean ± k·σ or median/MAD) or minimum-history guard. Does not run automatically on dashboard load. | Implement statistical anomaly detection (median/MAD or mean ± k·σ with configurable k and sample guard). Run detection during dashboard summary retrieval. Make recurring tolerances configurable in `.env`. |
| **UC-06: Purchase Readiness & Wishlist** | Broken / Missing | `app/models/wishlist.py`, `app/services/intelligence_service.py`. `BudgetPlan` model is completely missing. `calculate_discretionary_budget` hardcodes a 20% savings reserve. Verdict string uses `"Not recommended currently"` instead of exact `"Not Recommended Currently"`. | Create `BudgetPlan` model, migration, schema, and API. Connect discretionary budget calculation to `spending_limit` and `savings_goal`. Standardize verdict strings and add boundary unit tests. |
| **UC-07: NL Query ("Ask Your Expenses")** | Broken | `app/services/nl_service.py` line 105 & 373: defaults unknown intent to `spending_total` instead of refusing. Month/year matching is limited; comparisons are unsupported. | Add honest refusal response ("I can't answer that yet...") for unsupported questions. Expand safe parameterized query handlers for comparisons and merchant periods. |
| **UC-08: Bank Statement Processing** | Broken / Incomplete | `app/services/bank_statement_service.py`, `app/routers/bank_statements.py`. No merge endpoint exists. Duplicate detection is completely missing. Running balance validation and column synonym mapping are rudimentary. | Add format detection, delimiter/encoding sniffing, column synonym mapping, running balance validation, duplicate detection against user transactions, and `POST /bank-statements/{id}/merge` endpoint. |
| **Data Model: BudgetPlan** | Missing | No `budget_plan.py` in `app/models/`. | Implement `BudgetPlan` model: `id`, `user_id`, `month`, `spending_limit`, `savings_goal`, with methods `update_limits()`, `available_budget()`. |
| **Data Model: ExpenseItem** | Partially working | Named `TransactionItem`, uses `Float` for `unit_price` and `total_price`. Missing `subtotal()` helper method. | Update columns to `Numeric(12, 2)`, provide semantic method `subtotal()`. |
| **Data Model: Decimal Money** | Broken | `Transaction.amount`, `TransactionItem.unit_price`, `TransactionItem.total_price`, `ExpenseSplit.total_amount`, `SplitParticipant.amount_owed`, `Settlement.amount`, `WishlistItem.expected_price` all use `Float`. | Convert all monetary columns in SQLAlchemy models, Pydantic schemas, and calculations to `Decimal` / `Numeric(12, 2)`. |
| **Config & Env** | Broken | `app/config.py` only has DB URL, JWT secrets, and upload dir. No `.env.example`. Hardcoded LAN IP in frontend. Hardcoded UUID in seed script. | Expand `Settings` with all thresholds, limits, currency, OCR settings. Add `.env.example`. Update Flutter `ApiService` to use configurable base URL via `String.fromEnvironment`. Remove hardcoded UUIDs. |
| **Data-Driven Rules** | Broken | `MERCHANT_CATEGORY_RULES` is hardcoded in `categorization_service.py`. Bank statement column synonyms are hardcoded. | Move default merchant category rules and statement column mappings into JSON configuration files loaded dynamically, with DB-backed user overrides taking precedence. |
| **User Data Isolation** | Partially working | Endpoints check `user_id`, but no explicit security test suite verifies cross-user isolation or attempts to access another user's documents, splits, or NLQ data. | Write dedicated integration tests verifying User A cannot read or modify User B's resources under any endpoint. |
| **Frontend Tests** | Broken / Incomplete | Only 1 smoke test in `test/widget_test.dart`. No widget tests for screens, states (loading, error, empty), or mock API integration. | Implement widget tests for Auth, Expenses, Analytics, Splits, Wishlist, and Bank Statements covering loading, empty, success, and error states. |
| **Test Fixtures & Generator** | Missing | Only 2 static JPEG images in `tests/`. No generator script, no bank statement PDF/CSV fixtures with expected parsed JSON. | Build `tests/generate_fixtures.py` to produce synthetic UPI receipts, multi-item supermarket bills, and multi-format bank statement CSVs/PDFs with ground truth JSON files. |

---

## 3. Existing Test Run Baseline

### Backend Tests
Command: `uv run pytest`  
Result: 19 passed, 4 warnings in 66.50s.  
Existing files:
- `tests/test_analytics.py`: 6 passed (basic monthly, category, merchant, trends).
- `tests/test_auth_and_expenses.py`: 4 passed (register, login, CRUD, details).
- `tests/test_intelligence_and_notifications.py`: 4 passed (verdicts, recurring, notifications).
- `tests/test_ocr.py`: 2 passed (static tests on `tes1.jpeg` and `test2.jpeg`).
- `tests/test_splits_and_friends.py`: 3 passed (split calculations, split creation, balance).

### Frontend Tests
Command: `flutter test`  
Result: 1 passed in 1s (`test/widget_test.dart` smoke test).

---

## 4. Remediation Plan by Phase

### Phase 1: Fix Root-Cause Issues
1. Convert monetary types in backend models (`Transaction`, `TransactionItem`, `ExpenseSplit`, `SplitParticipant`, `Settlement`, `WishlistItem`) from `Float` to `Numeric(12, 2)` / `Decimal`.
2. Extract hardcoded rules (`MERCHANT_CATEGORY_RULES`, bank statement synonyms) into data-driven JSON config files with hot reload/dynamic loading.
3. Fix NLQ unknown intent handling in `nl_service.py` to return honest refusal instead of total spending.
4. Fix `ocr_review_screen.dart` to submit `category_id` and `document_id`, and implement user category preference learning upon confirmation.
5. Fix Flutter `baseUrl` to use `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000')` and remove LAN IP.

### Phase 2: Build Missing Features
1. **BudgetPlan & Enhanced Wishlist:**
   - Add `BudgetPlan` model (`id`, `user_id`, `month`, `spending_limit`, `savings_goal`).
   - Add migrations and CRUD router `/budgets`.
   - Update `calculate_discretionary_budget` and `calculate_purchase_readiness` to use `BudgetPlan` metrics. Standardize verdict strings (`Comfortable`, `Possible`, `Not Recommended Currently`).
2. **Bank Statement Merge & Duplicate Detection:**
   - Implement delimiter/encoding detection and header heuristic in `bank_statement_service.py`.
   - Implement duplicate detection comparing date, amount, normalized merchant, and reference against existing user transactions and intra-file rows.
   - Implement `POST /bank-statements/{id}/merge` with verification and duplicate filtering.
3. **Drill-Down Analytics:**
   - Add `/analytics/drilldown` supporting category, merchant, and item drill-downs.
4. **Draft Discard & Idempotency:**
   - Add `DELETE /documents/{id}` discard endpoint that removes physical files and clears unconfirmed records.
5. **Config & Environment:**
   - Create `.env.example`. Add settings for recurring tolerances, statistical anomaly sensitivity (`k`), confidence cutoffs, and file upload limits.
6. **Frontend Integration:**
   - Update screens to connect to BudgetPlan, Bank Statement verification & merge, and analytics drill-down.

### Phase 3: Comprehensive Testing & Fixtures
1. Implement synthetic fixture generator `tests/generate_fixtures.py`.
2. Write unit tests for amount formats, date formats, split reconciliation, statistical anomalies, readiness boundaries, and duplicate detection.
3. Write integration tests for User A vs User B data isolation across all routers.
4. Write Flutter widget tests for screen states (loading, empty, error, success) against mocked HTTP responses.
5. Verify all tests pass with 100% genuine execution.

### Phase 4: Final Reporting & Documentation
1. Write `docs/COMPLETION_REPORT.md` documenting before/after status, test counts, coverage, and limitations.
2. Update README.md with comprehensive instructions.
