"""
Database migration script to add event_id column to attendance_logs table
"""
import psycopg2
from config import settings

def migrate():
    try:
        # Connect to database
        conn = psycopg2.connect(settings.DATABASE_URL)
        cursor = conn.cursor()

        print("Adding event_id column to attendance_logs table...")

        # Add event_id column if it doesn't exist
        cursor.execute("""
            ALTER TABLE attendance_logs
            ADD COLUMN IF NOT EXISTS event_id VARCHAR(255);
        """)

        conn.commit()
        print("✅ Migration successful!")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Migration error: {e}")
        raise

if __name__ == "__main__":
    migrate()
