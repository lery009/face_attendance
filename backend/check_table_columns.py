"""Check actual columns in attendance_logs table"""
from database import get_db, engine
from sqlalchemy import inspect

inspector = inspect(engine)
columns = inspector.get_columns('attendance_logs')

print("=== Columns in attendance_logs table ===")
for col in columns:
    print(f"  {col['name']}: {col['type']}")
