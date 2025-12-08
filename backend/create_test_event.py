"""Create a test event for polling service"""
from database import get_db, Event, EventParticipant, Employee
from datetime import datetime, timedelta
import uuid

db = next(get_db())

try:
    # Get current time
    now = datetime.now()
    current_hour = now.hour
    current_minute = now.minute

    # Create event from now to 1 hour later
    start_time = f"{current_hour:02d}:{current_minute:02d}"
    end_hour = (current_hour + 1) % 24
    end_time = f"{end_hour:02d}:{current_minute:02d}"

    print(f"Creating event for today {now.date()} from {start_time} to {end_time}")

    # Create event
    event = Event(
        id=str(uuid.uuid4()),
        name="Polling Test Event",
        description="Test event for polling-based attendance",
        event_date=now.date(),
        start_time=start_time,
        end_time=end_time,
        location="Test Location",
        is_active=True,
        status="ongoing"
    )
    db.add(event)
    db.commit()

    print(f"✅ Event created: {event.id}")

    # Find employee "lry" (employee_id = "123Lry")
    employee = db.query(Employee).filter(Employee.employee_id == "123Lry").first()

    if employee:
        print(f"✅ Found employee: {employee.name} ({employee.employee_id})")

        # Add as participant
        participant = EventParticipant(
            id=str(uuid.uuid4()),
            event_id=event.id,
            employee_id=employee.id,
            is_required=True,
            status="invited"
        )
        db.add(participant)
        db.commit()

        print(f"✅ Added {employee.name} as participant")
    else:
        print("⚠️ Employee 'lry' not found")

    print("\n✅ Test event ready! Polling service should now take snapshots every 3 seconds.")
    print(f"   Event will be active until {end_time}")

except Exception as e:
    db.rollback()
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    db.close()
