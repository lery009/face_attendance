"""Check active events and participants"""
from database import get_db, Event, EventParticipant, Employee
from datetime import datetime

db = next(get_db())

try:
    print("=== All Events ===")
    events = db.query(Event).all()

    for event in events:
        print(f"\n📅 Event: {event.name}")
        print(f"   ID: {event.id}")
        print(f"   Date: {event.event_date}")
        print(f"   Time: {event.start_time} - {event.end_time}")
        print(f"   Active: {event.is_active}")
        print(f"   Status: {event.status}")

        # Check participants
        participants = db.query(EventParticipant).filter(
            EventParticipant.event_id == event.id
        ).all()

        print(f"   Participants ({len(participants)}):")
        for p in participants:
            emp = db.query(Employee).filter(Employee.id == p.employee_id).first()
            if emp:
                print(f"      - {emp.name} ({emp.employee_id}) - Status: {p.status}")

    print("\n\n=== Current Time ===")
    now = datetime.now()
    print(f"Date: {now.date()}")
    print(f"Time: {now.time()}")

    print("\n\n=== Active Events Right Now ===")
    active = db.query(Event).filter(
        Event.is_active == True,
        Event.event_date == now.date()
    ).all()

    print(f"Found {len(active)} active events today")

    for event in active:
        # Check time range
        if isinstance(event.start_time, str):
            parts = event.start_time.split(':')
            start_hour = int(parts[0]) if parts[0] else 0
            start_minute = int(parts[1]) if len(parts) > 1 else 0
            from datetime import time as datetime_time
            start_time = datetime_time(start_hour, start_minute)
        else:
            start_time = event.start_time

        if isinstance(event.end_time, str):
            parts = event.end_time.split(':')
            end_hour = int(parts[0]) if parts[0] else 23
            end_minute = int(parts[1]) if len(parts) > 1 else 59
            from datetime import time as datetime_time
            end_time = datetime_time(end_hour, end_minute)
        else:
            end_time = event.end_time

        current_time = now.time()
        is_ongoing = start_time <= current_time <= end_time

        print(f"\n📍 {event.name}")
        print(f"   Start: {start_time}")
        print(f"   End: {end_time}")
        print(f"   Current: {current_time}")
        print(f"   Is Ongoing: {is_ongoing}")

finally:
    db.close()
