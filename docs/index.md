![Tiet Logo](assets/tiet-logo.svg){ .tiet-logo }

**UCS503: Software Engineering (Project)**  
**TIET Patiala**

# Intelligent Expense Tracker

**Author(s)**:

`(RGB)` Gauransh Arora `<garora1_be24@thapar.edu>`

This project is an intelligent expense tracking application designed to help users monitor and manage their financial transactions efficiently.

## Project Structure

The project consists of two main components:
- **Backend**: FastAPI server running on Python providing REST APIs for expense management
- **Frontend**: Flutter application for mobile and web platforms

## Installation

### Backend Setup

``` shell
# Navigate to the backend directory
cd code/backend

# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r pyproject.toml

# Run the backend server
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Frontend Setup

``` shell
# Navigate to the frontend directory
cd code/frontend

# Install Flutter dependencies
dart pub get

# Run the application on different platforms:
# For Android:
flutter run --android

# For iOS:
flutter run --ios

# For web:
flutter run --web

# For desktop (Linux/Windows/macOS):
flutter run --desktop
```

## Basic Setup

1. **Backend Dependencies**: FastAPI, Uvicorn
2. **Frontend Dependencies**: Flutter SDK
3. **Database**: SQLite (for development)
4. **Environment Variables**: Configure API keys and database connections

## API Endpoints

The backend provides the following endpoints:

- `GET /ping` - Health check endpoint
- Additional endpoints will be added for:
  - Expense CRUD operations
  - User authentication
  - Expense analytics
  - Reports and summaries

## Usage

1. Start the backend server
2. Configure the frontend to connect to the backend
3. Use the Flutter app to track and manage expenses

The application supports cross-platform deployment for Android, iOS, Web, and desktop operating systems.
