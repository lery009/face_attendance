"""Add employee to event as participant"""
from database import get_db, Event, Employee, EventParticipant
import uuid

db = next(get_db())

try:
    # Get the Test1 event
    event = db.query(Event).filter(Event.name == "Test1").first()

    if not event:
        print("❌ Event 'Test1' not found")
        exit(1)

    print(f"✅ Found event: {event.name} ({event.id})")

    # Get employee Lery (12344)
    employee = db.query(Employee).filter(Employee.employee_id == "12344").first()

    if not employee:
        print("❌ Employee 12344 not found")
        exit(1)

    print(f"✅ Found employee: {employee.name} ({employee.employee_id})")

    # Check if already a participant
    existing = db.query(EventParticipant).filter(
        EventParticipant.event_id == event.id,
        EventParticipant.employee_id == employee.id
    ).first()

    if existing:
        print(f"✅ Employee already a participant (status: {existing.status})")
    else:
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

        print(f"✅ Added {employee.name} as participant to '{event.name}'")
        print(f"   Participant ID: {participant.id}")

finally:
    db.close()
