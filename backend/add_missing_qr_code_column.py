#!/usr/bin/env python3
"""
Migration script to add missing qr_code_token column to employees table
"""
from database import get_db
from sqlalchemy import text, inspect
import sys

def add_qr_code_column():
    print("=== Adding Missing qr_code_token Column ===\n")

    db = next(get_db())

    try:
        # Check if column already exists
        inspector = inspect(db.bind)
        columns = inspector.get_columns('employees')
        column_names = [col['name'] for col in columns]

        if 'qr_code_token' in column_names:
            print("✅ Column 'qr_code_token' already exists in employees table")
            print("   No migration needed.")
            return True

        print("📝 Column 'qr_code_token' not found. Adding it now...")

        # Add the missing column
        sql = text("""
            ALTER TABLE employees
            ADD COLUMN qr_code_token VARCHAR(255) UNIQUE;
        """)

        db.execute(sql)
        db.commit()

        print("✅ Successfully added 'qr_code_token' column to employees table")

        # Verify the column was added
        inspector = inspect(db.bind)
        columns = inspector.get_columns('employees')
        column_names = [col['name'] for col in columns]

        if 'qr_code_token' in column_names:
            print("✅ Verification: Column successfully added")
            return True
        else:
            print("❌ Verification failed: Column not found after addition")
            return False

    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    success = add_qr_code_column()
    sys.exit(0 if success else 1)
