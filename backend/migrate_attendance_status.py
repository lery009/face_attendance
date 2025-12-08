"""
Migration script to add status and notes columns to attendance_logs table
Run this once to update your existing database
"""
from sqlalchemy import create_engine, text
from config import settings

def migrate():
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        print("🔄 Starting migration...")

        try:
            # Add status column
            conn.execute(text("""
                ALTER TABLE attendance_logs
                ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'on_time'
            """))
            print("✅ Added 'status' column")

            # Add notes column
            conn.execute(text("""
                ALTER TABLE attendance_logs
                ADD COLUMN IF NOT EXISTS notes TEXT
            """))
            print("✅ Added 'notes' column")

            # Update existing records to have on_time status
            conn.execute(text("""
                UPDATE attendance_logs
                SET status = 'on_time'
                WHERE status IS NULL
            """))
            print("✅ Updated existing records with default status")

            conn.commit()
            print("✅ Migration completed successfully!")

        except Exception as e:
            print(f"❌ Migration error: {e}")
            conn.rollback()
            raise

if __name__ == "__main__":
    migrate()
