# Intelligent Expense Tracker

> **UCS503 Software Engineering Course Project**  
> *"A Smart Solution for Expense Tracking, Categorization, and Analysis"*

[![Backend Tests](https://img.shields.io/badge/Backend%20Tests-42%20passed-brightgreen.svg)]()
[![Frontend Tests](https://img.shields.io/badge/Frontend%20Tests-5%20passed-brightgreen.svg)]()
[![Python 3.12](https://img.shields.io/badge/Python-3.12-blue.svg)]()
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-teal.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)]()

---

## 1. Project Overview

The **Intelligent Expense Tracker** bridges the gap between fragmented financial data and actionable personal finance intelligence. Users generate financial transaction records through multiple sources: UPI payment screenshots, printed physical receipts, restaurant/supermarket bills, and monthly bank statements (PDF/CSV). 

This system provides automated optical extraction, machine-assisted categorization with continuous user-preference feedback learning, exact financial split arithmetic with zero rounding drift, dynamic budget tracking, and statistical anomaly detection.

### Supported Use Cases
- **UC-01: Document-Driven Expense Intake:** Multi-format intake from bills, receipts, and UPI screenshots (Google Pay, PhonePe, Paytm).
- **UC-02: Review & Verify Extraction:** OCR produces an unconfirmed draft with field confidences (`amount`, `merchant`, `date`, `taxes`, `items`). The user reviews, edits, and confirms before database persistence; discarding a draft leaves zero trace.
- **UC-03: Manual Expense Logging:** Fallback manual entry with category selection, payment method, date, and notes.
- **UC-04: Multi-Participant Split & Settlement:** Unequal, equal, and exact splits calculated using exact decimal precision with deterministic penny remainder distribution.
- **UC-05: Dynamic Categorization & User Feedback:** Categorization rules with user override precedence—user corrections immediately update preference maps for future transactions.
- **UC-06: Budget & Expense Planning:** Monthly spending limits, savings goals, target vs. actual spending tracking, available discretionary budget calculation, and purchase readiness evaluation for wishlist items.
- **UC-07: Financial Intelligence & Anomaly Detection:** Statistical unusual spending alerts ($mean \pm k \cdot \sigma$), overspend warnings, and conversational natural language querying with honest data-driven fallbacks.
- **UC-08: Bank Statement Processing:** Semicolon/comma/tab delimiter sniffing, Indian banking narration cleaning (UPI/POS/NEFT/IMPS/ACH), mathematical balance reconciliation, duplicate detection, and 1-click ledger merge.

---

## 2. System Architecture & Tech Stack

```
   ┌─────────────────────────────────────────────────────────────┐
   │                   Flutter Mobile App (Client)               │
   │   - Modern Dark-Themed UI with Curated HSL Palettes        │
   │   - Dynamic API_BASE_URL (--dart-define)                    │
   │   - Draft Verification & Confirmation Screens               │
   │   - Bank Statement Review & Merge Controls                  │
   └──────────────────────────────┬──────────────────────────────┘
                                  │ REST API (JSON)
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    FastAPI Backend Server                   │
   │   - Pydantic v2 Settings (Config & Secrets)                 │
   │   - Strict JWT Authentication & Multi-User Data Isolation   │
   │   - Decimal Financial Precision & MoneyAmount Arithmetic    │
   │   - Preprocessing Pipeline + PaddleOCR / Tesseract Fallback │
   │   - Statistical Spending Velocity & Anomaly Evaluators      │
   └──────────────────────────────┬──────────────────────────────┘
                                  │ SQLAlchemy 2.0 ORM
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │             Database (PostgreSQL / SQLite)                  │
   │   - Numeric(12, 2) Exact Amount Columns                     │
   │   - Tables: Users, Transactions, Documents, Categories,     │
   │     BankStatements, Splits, WishlistItems, BudgetPlans      │
   └─────────────────────────────────────────────────────────────┘
```

---

## 3. Quick Start & Setup Instructions

### Prerequisites
- **Python 3.12+**
- **uv** (recommended fast Python package manager)
- **Flutter 3.x+** with Dart SDK
- **Tesseract OCR** (optional, PaddleOCR included)

---

### Backend Setup (`code/backend`)

1. **Navigate to the backend directory:**
   ```bash
   cd code/backend
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   *(Update `JWT_SECRET_KEY` and database credentials in `.env` if using PostgreSQL. SQLite is used by default for zero-setup local execution).*

3. **Install dependencies with `uv`:**
   ```bash
   uv sync
   ```

4. **Initialize database & seed default categories:**
   ```bash
   uv run python migrate.py
   uv run python seed_mock.py
   ```

5. **Generate realistic synthetic test fixtures (optional):**
   ```bash
   uv run python tests/generate_fixtures.py
   ```

6. **Start the FastAPI backend server:**
   ```bash
   uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   Interactive OpenAPI / Swagger documentation will be available at: `http://localhost:8000/docs`.

---

### Frontend Setup (`code/frontend`)

1. **Navigate to the frontend directory:**
   ```bash
   cd code/frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the Flutter application:**
   - **For Web / Chrome:**
     ```bash
     flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
     ```
   - **For Android Emulator / Physical Device:**
     ```bash
     flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000
     ```
   - **For Linux Desktop:**
     ```bash
     flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8000
     ```

---

## 4. Running the Automated Test Suites

### Backend Tests
Execute the entire backend test suite across all 8 modules (42 tests):
```bash
cd code/backend
uv run pytest -v
```

Execute specific test suites:
- **Unit Normalization & Decimal Precision:** `uv run pytest tests/test_unit_normalization.py`
- **Integration API & Multi-User Isolation:** `uv run pytest tests/test_integration_api.py`
- **Bank Statement & OCR Robustness:** `uv run pytest tests/test_pipeline_and_robustness.py`
- **Splits & Friends Settlement:** `uv run pytest tests/test_splits_and_friends.py`

### Frontend Tests
Execute all Flutter unit and widget tests:
```bash
cd code/frontend
flutter test
```

---

## 5. Documentation & Project Reports

- **Audit & Architectural Gap Analysis:** [`docs/AUDIT.md`](docs/AUDIT.md)
- **Final Completion & Verification Report:** [`docs/COMPLETION_REPORT.md`](docs/COMPLETION_REPORT.md)
- **Selection Criteria:** [`docs/criteria-for-project-selection.md`](docs/criteria-for-project-selection.md)
- **Course Journals:** Located under `journals/`
- **Academic LaTeX Reports:** Located in `Project Proposal/`, `Project Report Prototype Stage/`, and `Project Report Final/`
