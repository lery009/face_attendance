#!/usr/bin/env python3
"""
Migration script to add event_id column to invitations table
"""
from database import get_db
from sqlalchemy import text, inspect
import sys

def add_event_id_column():
    print("=== Adding event_id Column to Invitations Table ===\n")

    db = next(get_db())

    try:
        # Check if column already exists
        inspector = inspect(db.bind)
        columns = inspector.get_columns('invitations')
        column_names = [col['name'] for col in columns]

        if 'event_id' in column_names:
            print("✅ Column 'event_id' already exists in invitations table")
            print("   No migration needed.")
            return True

        print("📝 Column 'event_id' not found. Adding it now...")

        # Add the missing column
        sql = text("""
            ALTER TABLE invitations
            ADD COLUMN event_id VARCHAR(255);
        """)

        db.execute(sql)

        # Add index for better performance
        sql_index = text("""
            CREATE INDEX IF NOT EXISTS idx_invitations_event_id
            ON invitations(event_id);
        """)

        db.execute(sql_index)
        db.commit()

        print("✅ Successfully added 'event_id' column to invitations table")
        print("✅ Successfully created index on 'event_id' column")

        # Verify the column was added
        inspector = inspect(db.bind)
        columns = inspector.get_columns('invitations')
        column_names = [col['name'] for col in columns]

        if 'event_id' in column_names:
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
    success = add_event_id_column()
    sys.exit(0 if success else 1)
