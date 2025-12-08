#!/usr/bin/env python3
"""
Verify qr_code_token column exists in employees table
"""
from database import get_db
from sqlalchemy import inspect

def verify_column():
    print("=== Verifying qr_code_token Column ===\n")

    db = next(get_db())

    try:
        inspector = inspect(db.bind)
        columns = inspector.get_columns('employees')

        print("Employees table columns:")
        print("-" * 60)

        qr_code_found = False
        for col in columns:
            marker = "✅" if col['name'] == 'qr_code_token' else "  "
            print(f"{marker} {col['name']:<25} {col['type']}")
            if col['name'] == 'qr_code_token':
                qr_code_found = True

        print("-" * 60)

        if qr_code_found:
            print("\n✅ SUCCESS: qr_code_token column exists")
            print("   Database schema is now up to date!")
            return True
        else:
            print("\n❌ ERROR: qr_code_token column NOT found")
            return False

    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        db.close()

if __name__ == "__main__":
    verify_column()
