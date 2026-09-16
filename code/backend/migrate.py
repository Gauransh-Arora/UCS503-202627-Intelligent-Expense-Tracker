from sqlalchemy import text
from app.database import engine

def migrate():
    print("Adding columns to transactions table...")
    for col_query in [
        "ALTER TABLE transactions ADD COLUMN verification_status VARCHAR(50) NOT NULL DEFAULT 'auto';",
        "ALTER TABLE transactions ADD COLUMN auto_categorized BOOLEAN NOT NULL DEFAULT false;",
        "ALTER TABLE transactions ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;"
    ]:
        try:
            with engine.begin() as conn:
                conn.execute(text(col_query))
            print(f"Executed: {col_query}")
        except Exception as e:
            print(f"Skipped (might exist): {col_query}")

if __name__ == "__main__":
    migrate()
