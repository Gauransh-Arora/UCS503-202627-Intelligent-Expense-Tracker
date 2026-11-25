# Divyansh Kumar — Student Journal

**Roll Number:** `1024170267`  
**Student Name:** Divyansh Kumar  
**Course:** UCS503 Software Engineering (Project)  
**Academic Year:** 2026–2027  
**Project Title:** Intelligent Expense Tracker  
**Specialization & Role:** Component Architecture, Bank Statement Ingestion, Natural Language Intelligence & Quality Assurance / Testing  

---

## 1. Executive Summary & Assigned Responsibilities

Within the software development lifecycle of the Intelligent Expense Tracker, my primary domains included **Component Architecture Modeling**, **Bank Statement Ingestion & Reconciliation**, **Conversational AI Query Processing**, and **Quality Assurance / Automated Testing Verification**.

### 1.1 Assigned Software Engineering Artifacts & Diagrams
1. **Component Diagram:** High-level structural architecture delineating the Presentation Component, API Gateway Router, Ingestion Component, Bank Statement Processing Component, Intelligence & Anomaly Component, and Database Persistence Component along with their port interfaces.
2. **Sequence Diagram (Bank Statement Processing & Merge):** Sequence flow illustrating statement upload, delimiter sniffing, column synonym mapping, Indian narration cleaning, balance reconciliation, duplicate flagging, and 1-click ledger merge.
3. **Received Testcases & Traceability Matrix (QA Suite):** Formal test suite specifications covering Unit Normalization, Decimal Precision, Multi-Tenant Isolation, Duplicate Detection, OCR Robustness, and Boundary Tests.

### 1.2 Assigned Code Modules & Technical Deliverables
- **Bank Statement Processing Pipeline:** `app/services/bank_statement_service.py`, `app/routers/bank_statements.py`, CSV/TSV/PDF ingestion, delimiter sniffing, Indian banking narration sanitizer, balance audit, and duplicate detection.
- **Natural Language Query Engine ("Ask Your Expenses"):** `app/services/nl_service.py`, `app/routers/ai.py`, parameterized SQL queries for spending questions, debt queries (`52de8a8`), and honest data fallbacks.
- **Automated Test Suite & QA Harness:** 42 automated tests in `tests/test_unit_normalization.py`, `tests/test_integration_api.py`, `tests/test_pipeline_and_robustness.py`, `tests/test_splits_and_friends.py`, synthetic test fixture generator (`tests/generate_fixtures.py`), and bulk transaction commit optimizations (`0c11a84`, `cf56e29`).

---

## 2. Software Engineering Artifacts & Diagrams

### 2.1 UML Component Diagram

```mermaid
graph TD
    subgraph ClientLayer [Presentation Component (Flutter)]
        UI_Screens[Screen Views & Dialogs]
        UI_State[State Providers & Notifiers]
        UI_Client[HTTP ApiService Client]
        UI_Screens --> UI_State --> UI_Client
    end

    subgraph GatewayLayer [API Gateway & Routing Component (FastAPI)]
        Router[FastAPI Route Handlers]
        AuthGuard[JWT Auth & Tenant Isolation Middleware]
        PydanticSchemas[Pydantic v2 Serialization & Validation]
        Router --> AuthGuard
        Router --> PydanticSchemas
    end

    subgraph ServiceLayer [Domain & Processing Components]
        OCRComp[OCR & Extraction Service<br/>• PIL Preprocessor<br/>• Tesseract / Vision Client]
        BankComp[Bank Statement Processor<br/>• Delimiter Sniffer<br/>• Narration Sanitizer<br/>• Balance Reconciler]
        SplitComp[Split & Ledger Service<br/>• Exact Decimal Engine<br/>• Penny Remainder Allocator]
        IntelComp[Intelligence & Analytics<br/>• Anomaly Detection<br/>• NLQ Assistant]
    end

    subgraph PersistenceLayer [Data Access & Persistence Component]
        SQLA[SQLAlchemy 2.0 ORM Engine]
        DB[(PostgreSQL / SQLite Database)]
        SQLA --> DB
    end

    UI_Client -- REST / JSON (HTTP) --> Router
    Router --> OCRComp
    Router --> BankComp
    Router --> SplitComp
    Router --> IntelComp
    OCRComp --> SQLA
    BankComp --> SQLA
    SplitComp --> SQLA
    IntelComp --> SQLA
```

---

### 2.2 Sequence Diagram: Bank Statement Processing & Ledger Merge

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Client)
    participant UI as Flutter App (Bank Statements Screen)
    participant API as FastAPI Gateway
    participant Parser as BankStatementService
    participant DB as PostgreSQL / SQLite Database

    User->>UI: Selects Bank Statement file (e.g. HDFC_Sept_2026.csv)
    UI->>API: POST /bank-statements/upload (Multipart File)
    API->>Parser: parse_bank_statement(file_bytes, filename)
    Parser->>Parser: Sniff Delimiter (',', ';', '\t') & Detect Column Synonyms
    Parser->>Parser: Clean Narration ("UPI/489120/Starbucks/HDFC" -> "Starbucks")
    Parser->>Parser: Verify Running Balance: Balance[n] == Balance[n-1] ± Amount[n]
    Parser->>DB: Check for duplicates against existing confirmed transactions
    DB-->>Parser: Duplicate flags & reasons returned
    Parser-->>API: Parsed Statement Draft with Audit Summary
    API-->>UI: 200 OK (Parsed Rows, Balance Audit: PASS, Duplicates: 2 detected)

    User->>UI: Reviews parsed rows & selects non-duplicate items
    User->>UI: Taps "Merge into Ledger"
    UI->>API: POST /bank-statements/{id}/merge {selected_row_ids: [...]}
    API->>Parser: execute_batch_ledger_merge(user_id, statement_id)
    Parser->>DB: Bulk INSERT INTO transactions (Single Commit)
    DB-->>Parser: Inserted N transactions
    Parser-->>API: Batch Merge Summary (Merged: N, Skipped: Duplicates)
    API-->>UI: 200 OK (Merge Complete)
    UI-->>User: Refreshes Transaction Ledger Screen
```

---

### 2.3 Received Testcases & Verification Traceability Matrix

| Test Case ID | Test Category | Target Component | Input / Scenario | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Money Correctness | `split_service.py` | Split ₹100.00 among 3 users equally | Exact shares: ₹33.33, ₹33.33, ₹33.34; $\sum = 100.00$; zero rounding loss | **PASS** |
| **TC-02** | Normalization | `unit_normalization` | Narration: `"UPI/582910/Blue Tokai Coffee/HDFC"` | Extracted merchant: `"Blue Tokai Coffee"`; stripped ref & bank tags | **PASS** |
| **TC-03** | Tenant Isolation | `auth` & `transactions` | User A requests Transaction belonging to User B | HTTP `404 Not Found` or `403 Forbidden`; zero cross-user data leakage | **PASS** |
| **TC-04** | Bank Sniffing | `bank_statement_service` | Semicolon-delimited CSV with messy headers | Delimiter `;` correctly identified; columns mapped to standard schema | **PASS** |
| **TC-05** | Balance Audit | `bank_statement_service` | Statement rows with deliberate balance discrepancy | Discrepancy flagged with row index and expected vs. actual balance | **PASS** |
| **TC-06** | Duplicate Check | `bank_statement_service` | Duplicate row present in file and in database | Both marked as duplicates with explicit human-readable reasons | **PASS** |
| **TC-07** | Idempotent Merge | `bank_statements.py` | Tapping "Merge" twice consecutively | Second merge rejects already-merged items; zero duplicate insertions | **PASS** |
| **TC-08** | Preference Loop | `categorization_service` | User changes category from "Food" to "Work" | Subsequent transaction for merchant automatically resolves to "Work" | **PASS** |
| **TC-09** | Anomaly Detection| `intelligence_service` | Expense of ₹15,000 when normal category mean is ₹500 | Flagged as statistical anomaly ($> mean + 3\sigma$) | **PASS** |
| **TC-10** | Honest NLQ | `nl_service.py` | Query: *"Should I buy Tesla stock?"* | Refuses with *"I can't answer that yet..."*; zero fabricated numbers | **PASS** |

---

## 3. Weekly Engineering Logs & Commit Traceability

### Week 1–2: Test Planning & Component Boundary Definition
- **Focus:** Quality assurance strategy, test matrix design, and component decomposition.
- **Activities:**
  - Defined the UML Component Diagram establishing subsystem boundaries and port contracts.
  - Authored the initial Traceability Matrix connecting requirements UC-01 through UC-08 to verification testcases.
  - Configured backend test harness (`pytest`, `pytest-asyncio`, and in-memory SQLite fixtures).

### Week 3–4: Ingestion Service Architecture & Bank Reader Conception
- **Focus:** Designing the bank statement ingestion pipeline.
- **Activities:**
  - Researched Indian bank statement structures across SBI, HDFC, ICICI, and Axis banks.
  - Constructed the Sequence Diagram for bank statement parsing, narration cleaning, and reconciliation.
  - Initialized bank statement parser module (`294cb1d`).
- **Git Commit References:**
  - `45b2225`: *basic frontend and backend structure, journals and docs updated*
  - `294cb1d`: *Bank statement reader*

### Week 5–6: Bank Narration Cleaner & Column Sniffer Implementation
- **Focus:** Developing robust parsing routines for delimited statements.
- **Activities:**
  - Implemented CSV/TSV delimiter sniffing for commas, tabs, and semicolons.
  - Built regex cleaners for Indian UPI transaction IDs, IMPS/NEFT transfer strings, and POS merchant terminal strings.
  - Developed running balance mathematical validator.
- **Git Commit References:**
  - `b12da11`: *features updated*
  - `6ab9870`: *chore(backend): update uv.lock with upstream pdf dependencies*

### Week 7–8: Natural Language Query Engine & Bank Merging
- **Focus:** Parameterized natural language query answering and statement merging.
- **Activities:**
  - Developed `app/services/nl_service.py` handling queries on spending totals, category totals, and top merchants.
  - Extended NLQ assistant to answer friend debt and balance queries (`52de8a8`).
  - Added duplicate transaction detection and one-click ledger merge endpoint (`POST /bank-statements/{id}/merge`).
- **Git Commit References:**
  - `52de8a8`: *feat(ai): support debt and balance queries in natural language service*
  - `04ffd7d`: *ocr optimised and bank statement dynamic*
  - `16d2d19`: *feat(frontend): wire dynamic API baseUrl, draft discard, and statement merge*

### Week 9–10: Comprehensive Test Suite Development (42 Automated Tests)
- **Focus:** Writing end-to-end unit, integration, and pipeline test suites.
- **Activities:**
  - Authored test suites covering all 10 core verification areas:
    - `tests/test_unit_normalization.py` (Decimal precision, narration cleaning, date normalization)
    - `tests/test_integration_api.py` (Auth, CRUD, budget alerts, multi-tenant isolation)
    - `tests/test_pipeline_and_robustness.py` (Bank statement parsing, running balance checks, duplicate detection)
    - `tests/test_splits_and_friends.py` (Split calculations, remainder conservation, debt settlements)
  - Built synthetic fixture generator `tests/generate_fixtures.py` for realistic test data.
- **Git Commit References:**
  - `7c243a3`: *docs: complete Phase 0 audit and gap analysis*
  - `d185224`: *test(all): add comprehensive unit, integration, pipeline, and widget test suites*
  - `58328c1`: *docs: update root README and add comprehensive COMPLETION_REPORT*

### Week 11–12: Performance Optimization & Bulk Processing
- **Focus:** Eliminating database roundtrip bottlenecks during bank statement ingestion.
- **Activities:**
  - Refactored statement merge to use single-commit bulk database insertions (`0c11a84`), reducing ingestion time by over 80%.
  - Eliminated cascading UI notification calls on statement import (`cf56e29`).
  - Optimized Vision LLM prompt parsing to prevent HTTP timeouts under large statements (`fb85c09`).
- **Git Commit References:**
  - `cf56e29`: *perf(transactions): add bulk creation and eliminate cascading notify calls on bank statement import*
  - `0c11a84`: *perf(backend): single-commit bulk transaction creation with in-memory categorization*
  - `fb85c09`: *perf(ai): optimize vision LLM parsing and statement extraction to prevent timeouts*

### Week 13–14: Final System Audit, Docs & Deployment
- **Focus:** Final verification, test suite regression pass, and documentation.
- **Activities:**
  - Executed full test regression suite across backend and frontend targets.
  - Verified that all 42 backend automated test cases pass with zero regressions.
  - Contributed to GitHub Pages documentation deployment and student journals.
- **Git Commit References:**
  - `2097a67`: *docs: consolidate GitHub Pages documentation, update authors, and clean up audit reports*
