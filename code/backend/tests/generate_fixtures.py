"""
Test Fixture Generator
======================
Generates synthetic, diverse test fixtures for the Intelligent Expense Tracker:
  - UPI screenshots in different app styles (Google Pay, PhonePe, Paytm)
  - Receipts in different layouts (Supermarket itemized, Restaurant with taxes)
  - Bank statements in different formats (HDFC CSV, SBI semicolon CSV, ICICI single-amount CSV, Axis PDF)
  - Edge cases (corrupt image, empty file, invalid format)
  - Associated ground-truth metadata in tests/fixtures/expected_fixtures.json
"""
import csv
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from fpdf import FPDF

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
FIXTURES_DIR.mkdir(parents=True, exist_ok=True)


def get_font(size: int = 20):
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except Exception:
        return ImageFont.load_default()


def create_upi_screenshot(filename: str, app_name: str, merchant: str, amount: str, date_str: str, utr: str):
    """Generate realistic UPI payment confirmation screenshot."""
    width, height = 400, 650
    # Background color per app
    bg_color = (255, 255, 255)
    header_color = (26, 115, 232) if app_name == "Google Pay" else ((95, 37, 159) if app_name == "PhonePe" else (0, 185, 245))

    img = Image.new("RGB", (width, height), bg_color)
    draw = ImageDraw.Draw(img)

    # Top header bar
    draw.rectangle([(0, 0), (width, 80)], fill=header_color)
    draw.text((20, 30), app_name, fill=(255, 255, 255), font=get_font(24))

    # Payment Status
    draw.text((120, 120), "Paid Successfully", fill=(46, 125, 50), font=get_font(20))

    # Amount
    draw.text((110, 170), f"Rs. {amount}", fill=(33, 33, 33), font=get_font(32))

    # Payee / Merchant
    draw.text((40, 240), f"Paid to", fill=(117, 117, 117), font=get_font(16))
    draw.text((40, 270), merchant, fill=(33, 33, 33), font=get_font(22))

    # Date and Time
    draw.text((40, 330), f"{date_str}, 02:45 PM", fill=(117, 117, 117), font=get_font(16))

    # Transaction Details box
    draw.rectangle([(30, 380), (370, 520)], outline=(224, 224, 224), width=1)
    draw.text((45, 400), "UPI Transaction ID", fill=(117, 117, 117), font=get_font(14))
    draw.text((45, 425), utr, fill=(33, 33, 33), font=get_font(16))

    draw.text((45, 465), "To Banking Name", fill=(117, 117, 117), font=get_font(14))
    draw.text((45, 485), merchant, fill=(33, 33, 33), font=get_font(16))

    out_path = FIXTURES_DIR / filename
    img.save(out_path, "PNG")
    return out_path


def create_receipt_image(filename: str, store_name: str, items: list[dict], tax_rate: float, date_str: str):
    """Generate realistic supermarket or restaurant receipt."""
    width, height = 450, 750
    img = Image.new("RGB", (width, height), (250, 250, 248))
    draw = ImageDraw.Draw(img)

    y = 30
    draw.text((100, y), store_name.upper(), fill=(20, 20, 20), font=get_font(22))
    y += 35
    draw.text((130, y), "Tax Invoice / Bill", fill=(90, 90, 90), font=get_font(16))
    y += 30
    draw.text((40, y), f"Date: {date_str}   Time: 19:42", fill=(60, 60, 60), font=get_font(14))
    y += 25
    draw.line([(30, y), (420, y)], fill=(180, 180, 180), width=1)
    y += 15

    # Table header
    draw.text((40, y), "Item Description", fill=(40, 40, 40), font=get_font(15))
    draw.text((270, y), "Qty", fill=(40, 40, 40), font=get_font(15))
    draw.text((340, y), "Price", fill=(40, 40, 40), font=get_font(15))
    y += 25
    draw.line([(30, y), (420, y)], fill=(200, 200, 200), width=1)
    y += 15

    subtotal = 0.0
    for itm in items:
        tot = round(itm["qty"] * itm["price"], 2)
        subtotal += tot
        draw.text((40, y), itm["name"][:20], fill=(30, 30, 30), font=get_font(15))
        draw.text((280, y), str(itm["qty"]), fill=(30, 30, 30), font=get_font(15))
        draw.text((340, y), f"{tot:.2f}", fill=(30, 30, 30), font=get_font(15))
        y += 28

    y += 10
    draw.line([(30, y), (420, y)], fill=(180, 180, 180), width=1)
    y += 15

    tax = round(subtotal * tax_rate, 2)
    grand_total = round(subtotal + tax, 2)

    draw.text((220, y), "Subtotal:", fill=(60, 60, 60), font=get_font(15))
    draw.text((340, y), f"{subtotal:.2f}", fill=(60, 60, 60), font=get_font(15))
    y += 25

    draw.text((220, y), f"GST ({int(tax_rate*100)}%):", fill=(60, 60, 60), font=get_font(15))
    draw.text((340, y), f"{tax:.2f}", fill=(60, 60, 60), font=get_font(15))
    y += 30

    draw.line([(200, y), (420, y)], fill=(100, 100, 100), width=2)
    y += 10

    draw.text((180, y), "TOTAL:", fill=(10, 10, 10), font=get_font(20))
    draw.text((320, y), f"Rs. {grand_total:.2f}", fill=(10, 10, 10), font=get_font(20))
    y += 45

    draw.text((110, y), "Thank you! Please visit again.", fill=(120, 120, 120), font=get_font(14))

    out_path = FIXTURES_DIR / filename
    img.save(out_path, "PNG")
    return out_path, {"subtotal": subtotal, "tax": tax, "grand_total": grand_total}


def create_bank_statements():
    """Create CSV and PDF statements."""
    # 1. HDFC CSV (Comma separated, standard cols)
    hdfc_path = FIXTURES_DIR / "statement_hdfc.csv"
    with open(hdfc_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["HDFC BANK STATEMENT FOR ACCOUNT *******4819"])
        writer.writerow(["Date", "Narration", "Chq/Ref No", "Debit", "Credit", "Balance"])
        writer.writerow(["05/10/2026", "UPI/628711/SWIGGY/ICICI", "628711", "349.00", "", "24651.00"])
        writer.writerow(["08/10/2026", "POS 4819 RELIANCE FRESH MUMBAI", "994811", "1250.50", "", "23400.50"])
        writer.writerow(["10/10/2026", "NEFT CR-N1002491-SALARY ACME CORP", "N1002491", "", "65000.00", "88400.50"])
        writer.writerow(["12/10/2026", "ACH DR NETFLIX SUBSCRIPTION", "ACH4911", "649.00", "", "87751.50"])

    # 2. SBI CSV (Semicolon delimited, Transaction Date / Particulars / Withdrawal)
    sbi_path = FIXTURES_DIR / "statement_sbi.csv"
    with open(sbi_path, "w", newline="", encoding="utf-8") as f:
        f.write("State Bank of India - Account Statement\n")
        f.write("Txn Date;Particulars;Ref No;Withdrawal;Deposit;Closing Balance\n")
        f.write("14-10-2026;UPI/628994/UBER TRIP/SBI;628994;240.00;;15200.00\n")
        f.write("16-10-2026;POS 9182 CAFE COFFEE DAY;918201;380.00;;14820.00\n")
        f.write("18-10-2026;TRANSFER FROM JOHN;TXN8819;;1000.00;15820.00\n")

    # 3. ICICI CSV (Single Amount column with Type Dr/Cr)
    icici_path = FIXTURES_DIR / "statement_icici.csv"
    with open(icici_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Date", "Description", "Txn Amount", "Type", "Balance"])
        writer.writerow(["2026-10-20", "ZOMATO ORDER #49102", "540.00", "DR", "32100.00"])
        writer.writerow(["2026-10-21", "AMAZON PAY INDIA", "1499.00", "DR", "30601.00"])
        writer.writerow(["2026-10-22", "REFUND FROM AMAZON", "499.00", "CR", "31100.00"])

    # 4. Axis Bank PDF Statement using FPDF
    axis_pdf_path = FIXTURES_DIR / "statement_axis.pdf"
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "AXIS BANK LIMITED - STATEMENT OF ACCOUNT", ln=True, align="C")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 8, "Account Number: ********9012  |  Currency: INR", ln=True, align="C")
    pdf.cell(0, 8, "Period from 01/10/2026 to 25/10/2026", ln=True, align="C")
    pdf.ln(5)

    # Header
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(30, 8, "Date", 1)
    pdf.cell(80, 8, "Particulars", 1)
    pdf.cell(25, 8, "Debit", 1)
    pdf.cell(25, 8, "Credit", 1)
    pdf.cell(30, 8, "Balance", 1)
    pdf.ln()

    # Rows
    pdf.set_font("Helvetica", "", 9)
    rows = [
        ("02/10/2026", "UPI/120938/STARBUCKS/HDFC", "420.00", "-", "45000.00"),
        ("06/10/2026", "POS 4918 APOLLO PHARMACY", "850.00", "-", "44150.00"),
        ("15/10/2026", "SALARY CREDIT - TECH CORP", "-", "50000.00", "94150.00"),
        ("22/10/2026", "UPI/884910/AIRTEL FIBER/PAYTM", "1179.00", "-", "92971.00"),
    ]
    for r in rows:
        pdf.cell(30, 7, r[0], 1)
        pdf.cell(80, 7, r[1], 1)
        pdf.cell(25, 7, r[2], 1)
        pdf.cell(25, 7, r[3], 1)
        pdf.cell(30, 7, r[4], 1)
        pdf.ln()

    pdf.output(str(axis_pdf_path))


def create_edge_case_files():
    """Create corrupt, empty, and invalid test files."""
    # Corrupt image
    corrupt_path = FIXTURES_DIR / "corrupted_file.png"
    corrupt_path.write_bytes(b"\x89PNG\r\n\x1a\nCORRUPTED_DATA_HEADER_NOT_AN_IMAGE_BODY")

    # Empty file
    empty_path = FIXTURES_DIR / "empty_statement.csv"
    empty_path.write_text("", encoding="utf-8")

    # Unsupported format
    unsupported_path = FIXTURES_DIR / "invalid_document.xyz"
    unsupported_path.write_text("Hello binary junk format", encoding="utf-8")


def generate_all_fixtures():
    """Generate all test fixtures and the expected_fixtures.json mapping."""
    expected = {}

    # 1. UPI GPay
    create_upi_screenshot("upi_gpay.png", "Google Pay", "Blue Tokai Coffee", "450.00", "15 Oct 2026", "628994819201")
    expected["upi_gpay.png"] = {
        "type": "upi_screenshot",
        "merchant": "Blue Tokai Coffee",
        "amount": 450.0,
        "date": "2026-10-15",
        "status": "success",
        "reference": "628994819201",
    }

    # 2. UPI PhonePe
    create_upi_screenshot("upi_phonepe.png", "PhonePe", "Zomato Limited", "349.00", "12 Oct 2026", "TXN9928419204")
    expected["upi_phonepe.png"] = {
        "type": "upi_screenshot",
        "merchant": "Zomato Limited",
        "amount": 349.0,
        "date": "2026-10-12",
        "status": "success",
        "reference": "TXN9928419204",
    }

    # 3. Supermarket Receipt
    supermarket_items = [
        {"name": "Whole Milk 1L", "qty": 2, "price": 35.0},
        {"name": "Brown Bread 400g", "qty": 1, "price": 45.0},
        {"name": "Eggs 12-pack", "qty": 1, "price": 95.0},
        {"name": "Butter 200g", "qty": 1, "price": 110.0},
    ]
    _, sm_totals = create_receipt_image("receipt_supermarket.png", "Fresh Choice Mart", supermarket_items, 0.05, "18 Oct 2026")
    expected["receipt_supermarket.png"] = {
        "type": "receipt",
        "merchant": "Fresh Choice Mart",
        "amount": sm_totals["grand_total"],
        "tax_amount": sm_totals["tax"],
        "date": "2026-10-18",
        "item_count": len(supermarket_items),
    }

    # 4. Restaurant Receipt
    rest_items = [
        {"name": "Margherita Pizza", "qty": 1, "price": 380.0},
        {"name": "Pasta Alfredo", "qty": 1, "price": 320.0},
        {"name": "Lemon Iced Tea", "qty": 2, "price": 90.0},
    ]
    _, rest_totals = create_receipt_image("receipt_restaurant.png", "Bella Italia Cafe", rest_items, 0.05, "20 Oct 2026")
    expected["receipt_restaurant.png"] = {
        "type": "receipt",
        "merchant": "Bella Italia Cafe",
        "amount": rest_totals["grand_total"],
        "tax_amount": rest_totals["tax"],
        "date": "2026-10-20",
        "item_count": len(rest_items),
    }

    # 5. Statements
    create_bank_statements()
    expected["statement_hdfc.csv"] = {
        "type": "bank_statement_csv",
        "total_debits": 2248.50,
        "total_credits": 65000.0,
        "transaction_count": 4,
    }
    expected["statement_sbi.csv"] = {
        "type": "bank_statement_csv",
        "total_debits": 620.0,
        "total_credits": 1000.0,
        "transaction_count": 3,
    }
    expected["statement_icici.csv"] = {
        "type": "bank_statement_csv",
        "total_debits": 2039.0,
        "total_credits": 499.0,
        "transaction_count": 3,
    }
    expected["statement_axis.pdf"] = {
        "type": "bank_statement_pdf",
        "total_debits": 2449.0,
        "total_credits": 50000.0,
        "transaction_count": 4,
    }

    # 6. Edge cases
    create_edge_case_files()

    meta_path = FIXTURES_DIR / "expected_fixtures.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(expected, f, indent=2)

    print(f"✅ Generated fixtures in {FIXTURES_DIR} with expected metadata.")


if __name__ == "__main__":
    generate_all_fixtures()
