"""
Add camera_id column to attendance_logs table
"""
from sqlalchemy import text
from database import get_db

db = next(get_db())

try:
    # Add camera_id column if it doesn't exist (cameras.id is VARCHAR)
    db.execute(text("""
        ALTER TABLE attendance_logs
        ADD COLUMN IF NOT EXISTS camera_id VARCHAR REFERENCES cameras(id)
    """))

    db.commit()
    print("✅ Added camera_id column to attendance_logs table")

except Exception as e:
    db.rollback()
    print(f"❌ Error: {e}")

finally:
    db.close()
