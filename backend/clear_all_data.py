"""Clear all data from database tables"""
from database import get_db, Employee, AttendanceLog, Event, EventParticipant, User, Location, Invitation, Camera, EventCamera

db = next(get_db())

try:
    print("🗑️  Clearing all data from database...\n")

    # Delete in order to respect foreign key constraints

    # 1. Delete attendance logs
    count = db.query(AttendanceLog).delete()
    print(f"✅ Deleted {count} attendance logs")

    # 2. Delete event participants
    count = db.query(EventParticipant).delete()
    print(f"✅ Deleted {count} event participants")

    # 3. Delete event cameras
    count = db.query(EventCamera).delete()
    print(f"✅ Deleted {count} event cameras")

    # 4. Delete events
    count = db.query(Event).delete()
    print(f"✅ Deleted {count} events")

    # 5. Delete employees
    count = db.query(Employee).delete()
    print(f"✅ Deleted {count} employees")

    # 6. Delete invitations
    count = db.query(Invitation).delete()
    print(f"✅ Deleted {count} invitations")

    # 7. Delete cameras
    count = db.query(Camera).delete()
    print(f"✅ Deleted {count} cameras")

    # 8. Delete locations
    count = db.query(Location).delete()
    print(f"✅ Deleted {count} locations")

    # 9. Delete users (keep if you want to preserve admin accounts)
    # Uncomment the next 2 lines if you want to delete users too
    # count = db.query(User).delete()
    # print(f"✅ Deleted {count} users")

    db.commit()

    print("\n🎉 All data cleared successfully!")
    print("📝 Database is now empty and ready for new registrations")

except Exception as e:
    db.rollback()
    print(f"\n❌ Error clearing data: {e}")
    import traceback
    traceback.print_exc()

finally:
    db.close()
