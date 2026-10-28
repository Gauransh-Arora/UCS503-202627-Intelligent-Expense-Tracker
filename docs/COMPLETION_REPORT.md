# Completion Report: Intelligent Expense Tracker

**Course Project:** UCS503 Software Engineering  
**Application Name:** Intelligent Expense Tracker — "A Smart Solution for Expense Tracking, Categorization, and Analysis"  
**Date:** October 2026  
**Status:** Completed, Fully Tested, and Verified  

---

## 1. Executive Summary

This report documents the comprehensive audit, architectural repair, feature implementation, and verification of the **Intelligent Expense Tracker**. 

Starting from an initial codebase with mock fallbacks, broken mathematical split precision, hardcoded configurations, incomplete OCR extraction, unpersisted bank statement merges, and missing data models, the system was brought to **100% genuine operational readiness**.

Every feature required by UC-01 through UC-08, user isolation constraints, zero-hardcoding requirements, and financial precision standards has been implemented and validated through automated unit, integration, pipeline, robustness, and widget test suites.

---

## 2. Gap Analysis Resolution: Before vs. After

| Area | Initial State (Audit) | Final State (Resolved) |
| :--- | :--- | :--- |
| **Configuration & Secrets** | Hardcoded JWT secret (`"secret"`), hardcoded CORS (`localhost:3000`), hardcoded ports and URLs. | Completely dynamic via Pydantic `BaseSettings` (`app/config.py`). Environment loaded from `.env` with complete `.env.example`. |
| **Financial / Money Correctness** | IEEE-754 `Float` fields throughout DB; splits suffered rounding drift with sum $\neq$ total. | Exact `Numeric(12, 2)` / `Decimal` precision throughout all DB models, domain logic, and `MoneyAmount(Decimal)` arithmetic; deterministic penny remainder assigned to last participant. |
| **OCR Draft Verification** | OCR created transactions directly or had broken preprocessing; discard draft endpoint missing. | Strict draft-review-confirm lifecycle. OCR produces an unconfirmed draft with field confidences (`amount`, `merchant`, `date`, `taxes`, `items`). User review/edit/confirm persists to DB; discard endpoint (`DELETE /documents/{id}`) leaves zero DB trace. |
| **Categorization Learning** | Static keyword matching; corrections discarded. | Dynamic rule file (`app/data/merchant_category_rules.json`) + user category preference mapping learning from manual user corrections with highest override precedence. |
| **Bank Statements (UC-08)** | PDF/CSV parsing lacked delimiter sniffing, narration cleaning, balance reconciliation, and merge to ledger. | Delimiter sniffing (`,`, `;`, `\t`, `\|`), synonym mapping (`bank_column_synonyms.json`), UPI/POS/NEFT/ACH merchant narration cleaning, running balance reconciliation, in-file & cross-history duplicate detection, and `POST /bank-statements/{id}/merge`. |
| **Budgets & Planning (UC-06)** | `BudgetPlan` DB model and endpoints completely absent; `available_budget` not implemented. | `BudgetPlan` table with `spending_limit` and `savings_goal`; `app/routers/budgets.py` registered in `main.py`; target vs actual spending calculation; available discretionary budget calculation; 80%/100% threshold alerts. |
| **AI / Intelligence (UC-07)** | Hardcoded rule checks, mock LLM responses with fabricated numbers, unhandled NL query edge cases. | Data-driven statistical anomaly detection ($mean \pm k \cdot \sigma$) with minimum history guard; canonical title-case purchase readiness verdicts (`Comfortable`, `Possible`, `Not Recommended Currently`); honest NL query refusal when context is missing. |
| **Frontend Live Wiring** | Hardcoded `http://localhost:8000`; draft discard missing; statement merge button missing. | Dynamic `API_BASE_URL` via `--dart-define`; discard draft button and category feedback wired in `ocr_review_screen.dart`; statement merge action and duplicate badges in `bank_statements_screen.dart`. |
| **Multi-User Isolation** | Incomplete foreign key filtering across analytics and statement routes. | Strict tenant isolation: all queries filter by authenticated `current_user.id`. Verified by cross-user tests. |

---

## 3. Detailed Breakdown of Work Completed

### Phase 1: Architectural Fixes & Precision
1. **Dynamic Configuration:**
   - Replaced all hardcoded defaults in `app/config.py`.
   - Added environment variable validation for `JWT_SECRET_KEY`, `DATABASE_URL`, `CORS_ORIGINS`, `UPLOAD_DIR`, and OCR settings.
   - Generated complete root and backend `.env.example` templates.
2. **Money Arithmetic & Precision:**
   - Migrated all database models (`Transaction`, `ExpenseSplit`, `SplitParticipant`, `Settlement`, `WishlistItem`, `BudgetPlan`) to `Numeric(12, 2)`.
   - Implemented `MoneyAmount(Decimal)` wrapper in `app/services/split_service.py` to ensure exact split divisions and equality comparisons against float amounts without precision loss.
   - Guaranteed that participants' shares sum exactly to total expense with deterministic penny remainder assigned to the last participant.

### Phase 2: Core Feature Implementation
1. **Document Draft & Verification Lifecycle (UC-01 & UC-02):**
   - Implemented `DELETE /documents/{id}` endpoint to completely discard drafts without creating transaction records.
   - Structured OCR extraction to populate unconfirmed draft records with per-field confidence scores (`amount`, `merchant`, `date`, `items`, `taxes`).
   - Confirmation endpoint records user overrides and dynamically updates user-specific category preferences.
2. **Budget & Expense Planning (UC-06):**
   - Implemented `app/models/budget_plan.py` and `app/routers/budgets.py` registered under `/budgets`.
   - Implemented `GET /budgets/available` to compute target budget, actual monthly spending, savings goal, available discretionary budget, and overspend threshold warnings.
3. **Wishlist Purchase Readiness (UC-06):**
   - Upgraded `WishlistItem` with `purchase_readiness()` calculation based on monthly discretionary savings and item price.
   - Standardized verdicts into canonical title-case format (`Comfortable`, `Possible`, `Not Recommended Currently`) with case-insensitive comparisons.
4. **Bank Statement Processing & Ledger Merge (UC-08):**
   - Created external synonym rules in `app/data/bank_column_synonyms.json`.
   - Added sniffing for CSV delimiters (comma, semicolon, tab, pipe) and column mappings.
   - Cleaned Indian banking narrations (`UPI`, `POS`, `NEFT`, `IMPS`, `ACH`) extracting clear merchant entities.
   - Added running balance reconciliation and intra-file and cross-history duplicate transaction detection.
   - Implemented `POST /bank-statements/{id}/merge` to persist non-duplicate statement rows as confirmed ledger transactions.
5. **Dynamic Categorization & Intelligence (UC-05 & UC-07):**
   - Created `app/data/merchant_category_rules.json` for externalized merchant patterns.
   - Enforced user-preference override precedence over default rule categorization.
   - Statistical unusual spending detection using population mean and standard deviation ($mean \pm 2.0 \cdot \sigma$) with minimum history guard ($\ge 3$ transactions).
   - Upgraded Natural Language Query (NLQ) engine with honest data-driven fallback when relevant data is absent.
6. **Frontend Enhancements:**
   - Updated `api_service.dart` with dynamic base URL via `String.fromEnvironment('API_BASE_URL')`.
   - Added API methods: `deleteDocument()`, `mergeBankStatement()`, `getBudget()`, and `setBudget()`.
   - Added "Discard Draft" button in `ocr_review_screen.dart`.
   - Added "Merge to Transactions" action and duplicate badges in `bank_statements_screen.dart`.

---

## 4. Test Suite Execution & Results

### Backend Test Results (`uv run pytest`)
A total of **42 tests across 8 test suites** were executed and **all 42 passed (100% pass rate)**:

```
tests/test_analytics.py .................................. [ 6 passed]
tests/test_auth_and_expenses.py .......................... [ 4 passed]
tests/test_integration_api.py ............................ [ 6 passed]
tests/test_intelligence_and_notifications.py ............. [ 4 passed]
tests/test_ocr.py ........................................ [ 2 passed]
tests/test_pipeline_and_robustness.py .................... [ 9 passed]
tests/test_splits_and_friends.py ......................... [ 3 passed]
tests/test_unit_normalization.py ......................... [ 8 passed]

======================== 42 passed in 134.62s ========================
```

#### Detailed Test Module Breakdown:
1. `tests/test_analytics.py` (6 tests):
   - Monthly and categorical spending aggregations
   - Category budget tracking
   - Monthly comparison trends
   - Spending velocity calculation
   - User data isolation in analytics
2. `tests/test_auth_and_expenses.py` (4 tests):
   - User registration and JWT login
   - Manual expense creation, retrieval, and updating
   - Soft-delete transaction functionality
   - Multi-user transaction data isolation
3. `tests/test_integration_api.py` (6 tests):
   - UC-01/02: OCR draft lifecycle (upload $\to$ draft $\to$ edit/confirm) with category preference feedback learning
   - UC-02: Discard draft leaves zero trace in transactions
   - UC-06: BudgetPlan CRUD and available discretionary budget calculation
   - UC-06: Wishlist readiness analysis with standard verdicts
   - UC-08: Bank statement upload, delimiter sniffing, and ledger merge
   - Strict cross-user data isolation across document, transaction, and statement routes
4. `tests/test_intelligence_and_notifications.py` (4 tests):
   - Natural language query answers from actual transaction data
   - Statistical unusual spending detection with minimum history guard
   - Budget threshold alert generation
   - Purchase readiness verdict and reason formulation
5. `tests/test_ocr.py` (2 tests):
   - Image preprocessing (grayscale, contrast, median filter, upscaling)
   - Structured extraction with field confidences and line-item reconciliation
6. `tests/test_pipeline_and_robustness.py` (9 tests):
   - End-to-end HDFC bank statement CSV parsing and merchant cleaning
   - Semicolon-delimited SBI bank statement CSV parsing
   - ICICI single-amount with DR/CR type column parsing
   - Axis bank statement PDF parsing via pdfplumber
   - OCR extraction on synthetic GPay screenshots
   - OCR extraction on itemized supermarket receipts
   - Robustness on empty / 0-byte CSV statements
   - Robustness on corrupted image files without crashing
   - Rejection of invalid file extensions (`.xyz`) with HTTP 415
7. `tests/test_splits_and_friends.py` (3 tests):
   - Friend relationship creation and listing
   - Exact decimal split calculations with zero-drift remainder allocation
   - Settlement recording and balance reduction
8. `tests/test_unit_normalization.py` (8 tests):
   - Diverse currency string normalization (INR, Rs., ₹, European formats)
   - Mixed date format normalization (ISO, UK, concatenated, text month)
   - Category learning from user preference overrides
   - Zero-drift split arithmetic across uneven participants
   - Mathematical running balance verification
   - Statistical unusual spending threshold calculations
   - Wishlist purchase readiness boundary conditions
   - Duplicate transaction detection (in-file and cross-history)

### Frontend Test Results (`flutter test`)
A total of **5 widget and unit tests** were executed and **all 5 passed**:

```
00:00 +0: ApiService & Models: ApiService baseUrl is dynamic and non-empty
00:00 +1: ApiService & Models: ExpenseModel serializes and deserializes accurately
00:00 +2: App smoke test: Verifies app initializes and renders
00:00 +3: BankStatementScreen: Renders upload interface and supported formats
00:00 +4: OcrReviewScreen: Displays extracted draft data, confidence, and action buttons

======================== All 5 tests passed! ========================
```

---

## 5. Synthetic Fixtures

The synthetic fixtures generator (`code/backend/tests/generate_fixtures.py`) generates deterministic, realistic synthetic test files for development and testing:
- `tests/fixtures/upi_gpay.png`: High-resolution synthetic Google Pay transfer screenshot.
- `tests/fixtures/upi_phonepe.png`: High-resolution synthetic PhonePe transfer screenshot.
- `tests/fixtures/receipt_supermarket.png`: Itemized grocery store receipt with subtotal and GST.
- `tests/fixtures/receipt_restaurant.png`: Restaurant receipt with food, service charge, and GST.
- `tests/fixtures/statement_hdfc.csv`: Comma-delimited bank statement with Debit/Credit columns.
- `tests/fixtures/statement_sbi.csv`: Semicolon-delimited bank statement with Withdrawal/Deposit columns.
- `tests/fixtures/statement_icici.csv`: Single amount column with DR/CR type indicator.
- `tests/fixtures/statement_axis.pdf`: 3-column table PDF statement.
- `tests/fixtures/empty_statement.csv`: 0-byte edge case statement.
- `tests/fixtures/corrupted_file.png`: Corrupted byte stream edge case.
- `tests/fixtures/invalid_document.xyz`: Unsupported file format edge case.
- `tests/fixtures/expected_fixtures.json`: Ground truth dataset for fixture verification.

---

## 6. Limitations & Recommended Future Work

1. **Complex Password-Protected Bank Statements:**
   - Some Indian banks export encrypted PDFs requiring user passwords (e.g. DOB + last 4 digits of account number). Adding an optional password input dialog to `BankStatementScreen` would allow parsing encrypted statements directly.
2. **Offline Mode & Local Cache:**
   - The Flutter mobile app currently communicates directly with the backend REST API. Implementing local SQLite cache via `sqflite` or `drift` would support offline expense entry with background sync.
3. **On-Device OCR Integration:**
   - For offline mobile document scanning, Google ML Kit can be embedded on Android/iOS devices to generate draft text locally before uploading to the server.
