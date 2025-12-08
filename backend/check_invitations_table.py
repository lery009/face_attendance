#!/usr/bin/env python3
"""
Check and create invitations table if needed
"""
from database import init_db, get_db, Invitation
from sqlalchemy import inspect

def check_invitations_table():
    print("=== Checking Invitations Table ===\n")

    # Initialize database (creates all tables)
    init_db()

    db = next(get_db())

    try:
        # Check if table exists
        inspector = inspect(db.bind)
        tables = inspector.get_table_names()

        if 'invitations' in tables:
            print("✅ Invitations table exists")

            # Show columns
            columns = inspector.get_columns('invitations')
            print("\nColumns:")
            for col in columns:
                print(f"  - {col['name']}: {col['type']}")

            # Count existing invitations
            count = db.query(Invitation).count()
            print(f"\nTotal invitations: {count}")

            # Show recent invitations
            if count > 0:
                recent = db.query(Invitation).order_by(Invitation.created_at.desc()).limit(5).all()
                print("\nRecent invitations:")
                for inv in recent:
                    status = "✓ Used" if inv.is_used else ("✗ Expired" if inv.expires_at < datetime.now() else "○ Active")
                    print(f"  {status} - {inv.email} - Created: {inv.created_at.strftime('%Y-%m-%d %H:%M')}")
        else:
            print("❌ Invitations table does NOT exist")
            print("Run: python3 -c 'from database import init_db; init_db()' to create it")

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    from datetime import datetime
    check_invitations_table()
