from sqlalchemy import text
from app.database import engine, Base
import app.models  # ensure all models are imported

def migrate():
    print("Creating any missing tables...")
    Base.metadata.create_all(bind=engine)

    print("Adding columns to transactions table if needed...")
    for col_query in [
        "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS verification_status VARCHAR(50) NOT NULL DEFAULT 'auto';",
        "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS auto_categorized BOOLEAN NOT NULL DEFAULT false;",
        "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;"
    ]:
        try:
            with engine.begin() as conn:
                conn.execute(text(col_query))
            print(f"Executed: {col_query}")
        except Exception as e:
            print(f"Skipped: {col_query} ({e})")

if __name__ == "__main__":
    migrate()

