import uuid
import random
from datetime import datetime, timedelta, timezone
from app.database import SessionLocal
from app.models.transaction import Transaction, PaymentMethod, VerificationStatus
from app.models.category import Category

# The target user ID
USER_ID = uuid.UUID("4007bdc8-d148-416b-a03d-2ed3cf7e03f1")

def seed_data():
    db = SessionLocal()
    try:
        # Get all categories
        categories = db.query(Category).all()
        if not categories:
            print("No categories found. Make sure categories are seeded first.")
            return

        print(f"Generating mock transactions for user {USER_ID}...")

        # Mock merchants and their likely categories
        merchants = [
            ("Starbucks", "Food", 150.0, 500.0),
            ("Domino's Pizza", "Food", 300.0, 800.0),
            ("Amazon", "Shopping", 500.0, 5000.0),
            ("Flipkart", "Shopping", 300.0, 3000.0),
            ("Uber", "Transport", 100.0, 600.0),
            ("Ola", "Transport", 100.0, 500.0),
            ("D-Mart", "Groceries", 1000.0, 4000.0),
            ("BigBasket", "Groceries", 500.0, 2000.0),
            ("Netflix", "Subscriptions", 199.0, 649.0),
            ("Spotify", "Subscriptions", 119.0, 119.0),
            ("Jio", "Bills", 299.0, 799.0),
            ("Airtel", "Bills", 299.0, 799.0),
            ("Apollo Pharmacy", "Healthcare", 200.0, 1500.0),
            ("PVR Cinemas", "Entertainment", 400.0, 1200.0)
        ]

        payment_methods = list(PaymentMethod)
        verification_statuses = list(VerificationStatus)

        transactions = []
        now = datetime.now(timezone.utc)

        # Generate 30 mock transactions over the last 60 days
        for i in range(30):
            merchant_info = random.choice(merchants)
            merchant_name, category_name, min_amt, max_amt = merchant_info
            
            # Find matching category
            category = next((c for c in categories if c.name == category_name), categories[0])
            
            # Random amount
            amount = round(random.uniform(min_amt, max_amt), 2)
            
            # Random date within last 60 days
            days_ago = random.randint(0, 60)
            txn_date = now - timedelta(days=days_ago)

            txn = Transaction(
                user_id=USER_ID,
                category_id=category.id,
                merchant_name=merchant_name,
                amount=amount,
                currency="INR",
                transaction_date=txn_date.date(),
                payment_method=random.choice(payment_methods),
                description=f"Mock transaction for {merchant_name}",
                verification_status=random.choice(verification_statuses),
                auto_categorized=random.choice([True, False])
            )
            transactions.append(txn)

        db.add_all(transactions)
        db.commit()
        print(f"Successfully inserted {len(transactions)} mock transactions.")

    except Exception as e:
        db.rollback()
        print(f"Error seeding data: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()
