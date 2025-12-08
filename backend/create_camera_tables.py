#!/usr/bin/env python3
"""
Migration script to create camera tables
"""
from database import init_db, get_db
from sqlalchemy import text, inspect
import sys

def create_camera_tables():
    print("=== Creating Camera Tables ===\n")

    # Initialize database (creates all tables including new ones)
    init_db()

    db = next(get_db())

    try:
        # Check if tables were created
        inspector = inspect(db.bind)
        tables = inspector.get_table_names()

        if 'cameras' in tables:
            print("✅ 'cameras' table created")

            # Show columns
            columns = inspector.get_columns('cameras')
            print("\nCamera table columns:")
            for col in columns:
                print(f"  - {col['name']}: {col['type']}")
        else:
            print("❌ 'cameras' table NOT created")

        if 'event_cameras' in tables:
            print("\n✅ 'event_cameras' table created")

            # Show columns
            columns = inspector.get_columns('event_cameras')
            print("\nEvent-Camera linking table columns:")
            for col in columns:
                print(f"  - {col['name']}: {col['type']}")
        else:
            print("❌ 'event_cameras' table NOT created")

        print("\n✅ Camera management system ready!")
        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        db.close()

if __name__ == "__main__":
    success = create_camera_tables()
    sys.exit(0 if success else 1)
