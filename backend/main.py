"""
Face Recognition Backend API
FastAPI application with face detection, recognition, and attendance tracking
"""
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
from database import get_ph_time
from sqlalchemy.orm import Session
import uuid

from config import settings
from database import init_db, get_db, Employee, AttendanceLog, Event, EventParticipant
from face_processor import FaceProcessor

# Initialize FastAPI app
app = FastAPI(
    title="Face Recognition API",
    description="Backend API for web-based face recognition attendance system",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize face processor
face_processor = FaceProcessor()

# Pydantic Models for API
class DetectRecognizeRequest(BaseModel):
    image: str  # Base64 encoded image

class RegisterEmployeeRequest(BaseModel):
    name: str
    firstname: str
    lastname: str
    employeeId: str
    department: str
    email: str
    image: str  # Base64 encoded image

class MatchEmployeeRequest(BaseModel):
    embedding: List[float]

class OnlineRegistrationRequest(BaseModel):
    """Request model for online self-registration"""
    firstname: str
    lastname: str
    employeeId: str
    department: str
    email: str
    phone: Optional[str] = None
    image: str  # Base64 encoded image

class CreateEventRequest(BaseModel):
    """Request model for creating an event"""
    name: str
    description: Optional[str] = None
    event_date: str  # ISO format: YYYY-MM-DD
    start_time: Optional[str] = None  # HH:MM format
    end_time: Optional[str] = None    # HH:MM format
    location: Optional[str] = None
    participant_ids: List[str]  # List of employee IDs

class UpdateEventRequest(BaseModel):
    """Request model for updating an event"""
    name: Optional[str] = None
    description: Optional[str] = None
    event_date: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = None
    participant_ids: Optional[List[str]] = None

class MarkEventAttendanceRequest(BaseModel):
    """Request model for marking event attendance"""
    employee_id: str

# API Endpoints

@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    init_db()
    print("🚀 Face Recognition Backend Started")
    print(f"📍 API running at: http://{settings.API_HOST}:{settings.API_PORT}")
    print(f"🔍 Liveness detection: {'✅ Enabled' if settings.ENABLE_LIVENESS else '❌ Disabled'}")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Face Recognition API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "detect_recognize": "/api/detect-recognize",
            "register": "/api/employees/register-with-image",
            "match": "/api/employees/match",
            "employees": "/api/employees",
            "attendance": "/api/attendance"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": get_ph_time().isoformat(),
        "liveness_enabled": settings.ENABLE_LIVENESS
    }

@app.post("/api/detect-recognize")
async def detect_and_recognize(
    request: DetectRecognizeRequest,
    event_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Detect faces in image and recognize them

    Args:
        request: Contains base64 encoded image
        event_id: Optional event ID for attendance tracking

    Returns:
        List of detected faces with recognition results
    """
    try:
        print("\n" + "="*60)
        print("🔍 Processing detection request...")
        print(f"📊 Image length: {len(request.image)} characters")
        print(f"📊 Image preview: {request.image[:100]}...")

        # DEBUG: Test image decoding
        try:
            test_decode = face_processor.decode_base64_image(request.image)
            print(f"✅ Image decoded successfully: shape={test_decode.shape}, dtype={test_decode.dtype}")
        except Exception as decode_error:
            print(f"❌ Image decoding failed: {decode_error}")
            return {"faces": []}

        # Get all employees from database
        employees = db.query(Employee).filter(Employee.is_active == True).all()

        if not employees:
            print("⚠️ No employees in database")
            print("="*60 + "\n")
            return {"faces": []}

        # Prepare employee embeddings
        employee_data = [
            (emp.employee_id, emp.name, emp.embeddings)
            for emp in employees
        ]

        print(f"📋 Found {len(employee_data)} employee(s) in database")

        # Process image
        print("🔄 Starting face detection and recognition...")
        results = face_processor.process_image_for_recognition(
            request.image,
            employee_data
        )

        print(f"📊 Detection results: {len(results)} face(s) found")
        if results:
            for idx, face in enumerate(results):
                print(f"   Face {idx+1}: {face['name']} (Live: {face['isLive']})")

        # Mark attendance for recognized live faces
        for face in results:
            if face['name'] != 'Unknown' and face['isLive']:
                employee_id = face['employeeId']

                # Check if already marked attendance recently (cooldown)
                cooldown = timedelta(minutes=settings.ATTENDANCE_COOLDOWN_MINUTES)
                recent_attendance = db.query(AttendanceLog).filter(
                    AttendanceLog.employee_id == employee_id,
                    AttendanceLog.timestamp > get_ph_time() - cooldown
                ).first()

                if not recent_attendance:
                    # Mark new attendance
                    attendance = AttendanceLog(
                        id=str(uuid.uuid4()),
                        employee_id=employee_id,
                        confidence=f"{face['confidence']:.2f}",
                        method="face_recognition",
                        event_id=event_id if event_id else None
                    )
                    db.add(attendance)
                    db.commit()

                    print(f"✅ Attendance marked for: {face['name']} ({employee_id})" + (f" - Event: {event_id}" if event_id else ""))
                    face['attendanceMarked'] = True
                else:
                    print(f"ℹ️ Attendance already marked recently for: {face['name']}")
                    face['attendanceMarked'] = False
            else:
                face['attendanceMarked'] = False

        print(f"✅ Processed {len(results)} face(s)")
        print("="*60 + "\n")

        return {"faces": results}

    except Exception as e:
        print(f"❌ Error in detect-recognize: {e}")
        import traceback
        traceback.print_exc()
        print("="*60 + "\n")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/employees/register-with-image")
async def register_employee_with_image(
    request: RegisterEmployeeRequest,
    db: Session = Depends(get_db)
):
    """
    Register new employee with face image

    Args:
        request: Employee data and base64 image

    Returns:
        Registration result
    """
    try:
        print(f"\n📝 Registering employee: {request.name}")

        # Check if employee ID already exists
        existing = db.query(Employee).filter(
            Employee.employee_id == request.employeeId
        ).first()

        if existing:
            raise HTTPException(
                status_code=400,
                detail=f"Employee ID {request.employeeId} already exists"
            )

        # Generate face embedding
        embedding, face_location = face_processor.generate_face_embedding(request.image)

        if embedding is None:
            raise HTTPException(
                status_code=400,
                detail="No face detected in image. Please provide a clear face photo."
            )

        # SECURITY: Check liveness to prevent photo registration
        # Decode image for liveness check
        image = face_processor.decode_base64_image(request.image)
        face_crop = face_processor.extract_face_crop(image, face_location)
        is_live, liveness_confidence, liveness_method = face_processor.liveness_detector.check_liveness(face_crop)

        if not is_live:
            print(f"❌ Registration rejected: Photo/screen detected (confidence: {liveness_confidence:.3f})")
            raise HTTPException(
                status_code=400,
                detail=f"Liveness check failed. Please use a live camera, not a photo or screen. (Score: {liveness_confidence:.2f})"
            )

        print(f"✅ Liveness check passed (confidence: {liveness_confidence:.3f})")

        # Create new employee
        employee = Employee(
            id=str(uuid.uuid4()),
            name=request.name,
            firstname=request.firstname,
            lastname=request.lastname,
            employee_id=request.employeeId,
            department=request.department,
            email=request.email,
            embeddings=embedding,
            is_active=True
        )

        db.add(employee)
        db.commit()
        db.refresh(employee)

        print(f"✅ Employee registered successfully: {request.name} ({request.employeeId})")

        return {
            "success": True,
            "message": "Employee registered successfully",
            "data": {
                "id": employee.id,
                "employeeId": employee.employee_id,
                "name": employee.name,
                "faceDetected": True
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Registration error: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/employees/match")
async def match_employee(
    request: MatchEmployeeRequest,
    db: Session = Depends(get_db)
):
    """
    Match face embedding against database (legacy endpoint)

    Args:
        request: Face embedding

    Returns:
        Match result
    """
    try:
        # Get all employees
        employees = db.query(Employee).filter(Employee.is_active == True).all()

        if not employees:
            return {
                "match": {
                    "isMatch": False,
                    "name": "Unknown",
                    "score": 0.0
                }
            }

        # Prepare embeddings
        employee_embeddings = [
            (emp.employee_id, emp.embeddings)
            for emp in employees
        ]

        # Match face
        import numpy as np
        face_encoding = np.array(request.embedding)
        match_result = face_processor.match_face(face_encoding, employee_embeddings)

        if match_result:
            employee_id, confidence = match_result
            employee = db.query(Employee).filter(
                Employee.employee_id == employee_id
            ).first()

            return {
                "match": {
                    "isMatch": True,
                    "name": employee.name,
                    "employeeId": employee.employee_id,
                    "score": confidence
                }
            }

        return {
            "match": {
                "isMatch": False,
                "name": "Unknown",
                "score": 0.0
            }
        }

    except Exception as e:
        print(f"❌ Match error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/employees")
async def get_all_employees(db: Session = Depends(get_db)):
    """Get all registered employees"""
    try:
        employees = db.query(Employee).filter(Employee.is_active == True).all()

        return {
            "success": True,
            "count": len(employees),
            "employees": [
                {
                    "id": emp.id,
                    "name": emp.name,
                    "employeeId": emp.employee_id,
                    "department": emp.department,
                    "email": emp.email,
                    "createdAt": emp.created_at.isoformat()
                }
                for emp in employees
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/attendance")
async def get_attendance_logs(
    date: Optional[str] = None,
    employee_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Get attendance logs with optional filters

    Args:
        date: Filter by date (YYYY-MM-DD format)
        employee_id: Filter by employee ID

    Returns:
        List of attendance logs
    """
    try:
        query = db.query(AttendanceLog)

        # Apply filters
        if date:
            target_date = datetime.strptime(date, "%Y-%m-%d")
            next_date = target_date + timedelta(days=1)
            query = query.filter(
                AttendanceLog.timestamp >= target_date,
                AttendanceLog.timestamp < next_date
            )

        if employee_id:
            query = query.filter(AttendanceLog.employee_id == employee_id)

        # Get logs
        logs = query.order_by(AttendanceLog.timestamp.desc()).all()

        # Get employee details
        employee_ids = list(set([log.employee_id for log in logs]))
        employees = db.query(Employee).filter(
            Employee.employee_id.in_(employee_ids)
        ).all()
        employee_map = {emp.employee_id: emp for emp in employees}

        return {
            "success": True,
            "count": len(logs),
            "logs": [
                {
                    "id": log.id,
                    "employeeId": log.employee_id,
                    "employeeName": employee_map.get(log.employee_id).name if log.employee_id in employee_map else "Unknown",
                    "timestamp": log.timestamp.isoformat(),
                    "confidence": log.confidence,
                    "method": log.method
                }
                for log in logs
            ]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/employees/{employee_id}")
async def delete_employee(employee_id: str, db: Session = Depends(get_db)):
    """Delete (deactivate) employee"""
    try:
        employee = db.query(Employee).filter(
            Employee.employee_id == employee_id
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Employee not found")

        # Soft delete
        employee.is_active = False
        db.commit()

        return {
            "success": True,
            "message": f"Employee {employee_id} deactivated"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/register/online")
async def online_registration(
    request: OnlineRegistrationRequest,
    db: Session = Depends(get_db)
):
    """
    Public online self-registration endpoint
    Allows employees to register themselves online with their photo

    Args:
        request: Employee data and base64 image

    Returns:
        Registration result with success message
    """
    try:
        print(f"\n🌐 Online registration request: {request.firstname} {request.lastname}")

        # Validate required fields
        if not request.firstname or not request.lastname:
            raise HTTPException(
                status_code=400,
                detail="First name and last name are required"
            )

        if not request.employeeId:
            raise HTTPException(
                status_code=400,
                detail="Employee ID is required"
            )

        if not request.email:
            raise HTTPException(
                status_code=400,
                detail="Email is required"
            )

        # Check if employee ID already exists
        existing = db.query(Employee).filter(
            Employee.employee_id == request.employeeId
        ).first()

        if existing:
            raise HTTPException(
                status_code=409,
                detail="This Employee ID is already registered. Please contact HR if this is an error."
            )

        # Check if email already exists
        existing_email = db.query(Employee).filter(
            Employee.email == request.email
        ).first()

        if existing_email:
            raise HTTPException(
                status_code=409,
                detail="This email is already registered. Please use a different email."
            )

        # Generate face embedding from image
        print("🔍 Detecting face in uploaded image...")
        embedding, face_location = face_processor.generate_face_embedding(request.image)

        if embedding is None:
            raise HTTPException(
                status_code=400,
                detail="No face detected in the image. Please upload a clear photo of your face with good lighting."
            )

        # SECURITY: Check liveness to prevent photo registration
        # Decode image for liveness check
        image = face_processor.decode_base64_image(request.image)
        face_crop = face_processor.extract_face_crop(image, face_location)
        is_live, liveness_confidence, liveness_method = face_processor.liveness_detector.check_liveness(face_crop)

        if not is_live:
            print(f"❌ Online registration rejected: Photo/screen detected (confidence: {liveness_confidence:.3f})")
            raise HTTPException(
                status_code=400,
                detail=f"Registration rejected: Please use a live camera to take your photo, not a picture or screenshot. Anti-spoofing score: {liveness_confidence:.2f}"
            )

        print(f"✅ Liveness check passed for online registration (confidence: {liveness_confidence:.3f})")

        # Create full name
        full_name = f"{request.firstname} {request.lastname}"

        # Create new employee record
        employee = Employee(
            id=str(uuid.uuid4()),
            name=full_name,
            firstname=request.firstname,
            lastname=request.lastname,
            employee_id=request.employeeId,
            department=request.department,
            email=request.email,
            embeddings=embedding,
            is_active=True
        )

        db.add(employee)
        db.commit()
        db.refresh(employee)

        print(f"✅ Online registration successful: {full_name} ({request.employeeId})")

        return {
            "success": True,
            "message": "Registration successful! You can now use face recognition to mark attendance.",
            "data": {
                "id": employee.id,
                "name": full_name,
                "employeeId": employee.employee_id,
                "email": employee.email,
                "department": employee.department,
                "registrationDate": employee.created_at.isoformat()
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Online registration error: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Registration failed: {str(e)}"
        )

# ============================================
# EVENT MANAGEMENT ENDPOINTS
# ============================================

def calculate_event_status(event_date, start_time, end_time):
    """
    Calculate real-time event status based on current datetime

    Returns: 'upcoming', 'ongoing', or 'completed'
    """
    from datetime import datetime, time as datetime_time

    # Get current datetime in local timezone
    now = datetime.now()
    current_date = now.date()
    current_time = now.time()

    # Parse start and end times
    start_hour, start_minute = map(int, start_time.split(':'))
    end_hour, end_minute = map(int, end_time.split(':'))

    start_time_obj = datetime_time(start_hour, start_minute)
    end_time_obj = datetime_time(end_hour, end_minute)

    # Compare dates
    if event_date.date() > current_date:
        return "upcoming"
    elif event_date.date() < current_date:
        return "completed"
    else:
        # Same day - check time
        if current_time < start_time_obj:
            return "upcoming"
        elif current_time > end_time_obj:
            return "completed"
        else:
            return "ongoing"

@app.post("/api/events")
async def create_event(
    request: CreateEventRequest,
    db: Session = Depends(get_db)
):
    """Create a new event with participants"""
    try:
        print(f"\n📅 Creating event: {request.name}")

        # Parse event date
        event_date = datetime.strptime(request.event_date, "%Y-%m-%d")

        # Create event
        event = Event(
            id=str(uuid.uuid4()),
            name=request.name,
            description=request.description,
            event_date=event_date,
            start_time=request.start_time,
            end_time=request.end_time,
            location=request.location,
            status="upcoming"
        )

        db.add(event)
        db.commit()
        db.refresh(event)

        # Add participants
        participants_added = []
        for emp_id in request.participant_ids:
            # Verify employee exists
            employee = db.query(Employee).filter(
                Employee.employee_id == emp_id,
                Employee.is_active == True
            ).first()

            if employee:
                participant = EventParticipant(
                    id=str(uuid.uuid4()),
                    event_id=event.id,
                    employee_id=emp_id,
                    is_required=True,
                    status="invited"
                )
                db.add(participant)
                participants_added.append(emp_id)

        db.commit()

        print(f"✅ Event created: {event.name} with {len(participants_added)} participants")

        return {
            "success": True,
            "message": "Event created successfully",
            "data": {
                "id": event.id,
                "name": event.name,
                "event_date": event.event_date.isoformat(),
                "location": event.location,
                "participants_count": len(participants_added)
            }
        }

    except Exception as e:
        print(f"❌ Error creating event: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/events")
async def get_all_events(
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Get all events with optional status filter (calculates real-time status)"""
    try:
        query = db.query(Event).filter(Event.is_active == True)
        events = query.order_by(Event.event_date.desc()).all()

        # Get participant counts and calculate real-time status
        event_data = []
        for event in events:
            # Calculate real-time status based on current datetime
            real_time_status = calculate_event_status(
                event.event_date,
                event.start_time,
                event.end_time
            )

            # Skip if status filter doesn't match
            if status and real_time_status != status:
                continue

            participants = db.query(EventParticipant).filter(
                EventParticipant.event_id == event.id
            ).all()

            attended_count = sum(1 for p in participants if p.status == "attended")

            event_data.append({
                "id": event.id,
                "name": event.name,
                "description": event.description,
                "event_date": event.event_date.isoformat(),
                "start_time": event.start_time,
                "end_time": event.end_time,
                "location": event.location,
                "status": real_time_status,  # Use calculated status
                "total_participants": len(participants),
                "attended_count": attended_count,
                "created_at": event.created_at.isoformat()
            })

        print(f"📅 Found {len(event_data)} events" + (f" with status '{status}'" if status else ""))

        return {
            "success": True,
            "count": len(event_data),
            "events": event_data
        }

    except Exception as e:
        print(f"❌ Error fetching events: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/events/{event_id}")
async def get_event_details(event_id: str, db: Session = Depends(get_db)):
    """Get detailed information about a specific event"""
    try:
        event = db.query(Event).filter(
            Event.id == event_id,
            Event.is_active == True
        ).first()

        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Calculate real-time status
        real_time_status = calculate_event_status(
            event.event_date,
            event.start_time,
            event.end_time
        )

        # Get participants with employee details
        participants = db.query(EventParticipant).filter(
            EventParticipant.event_id == event_id
        ).all()

        participant_data = []
        for participant in participants:
            employee = db.query(Employee).filter(
                Employee.employee_id == participant.employee_id
            ).first()

            if employee:
                participant_data.append({
                    "id": participant.id,
                    "employee_id": participant.employee_id,
                    "employee_name": employee.name,
                    "department": employee.department,
                    "status": participant.status,
                    "attended_at": participant.attended_at.isoformat() if participant.attended_at else None,
                    "is_required": participant.is_required
                })

        return {
            "success": True,
            "event": {
                "id": event.id,
                "name": event.name,
                "description": event.description,
                "event_date": event.event_date.isoformat(),
                "start_time": event.start_time,
                "end_time": event.end_time,
                "location": event.location,
                "status": real_time_status,  # Use calculated status
                "created_at": event.created_at.isoformat()
            },
            "participants": participant_data
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/events/{event_id}")
async def update_event(
    event_id: str,
    request: UpdateEventRequest,
    db: Session = Depends(get_db)
):
    """Update an event"""
    try:
        event = db.query(Event).filter(
            Event.id == event_id,
            Event.is_active == True
        ).first()

        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Update fields
        if request.name:
            event.name = request.name
        if request.description is not None:
            event.description = request.description
        if request.event_date:
            event.event_date = datetime.strptime(request.event_date, "%Y-%m-%d")
        if request.start_time is not None:
            event.start_time = request.start_time
        if request.end_time is not None:
            event.end_time = request.end_time
        if request.location is not None:
            event.location = request.location
        if request.status:
            event.status = request.status

        # Update participants if provided
        if request.participant_ids is not None:
            # Remove existing participants
            db.query(EventParticipant).filter(
                EventParticipant.event_id == event_id
            ).delete()

            # Add new participants
            for emp_id in request.participant_ids:
                participant = EventParticipant(
                    id=str(uuid.uuid4()),
                    event_id=event_id,
                    employee_id=emp_id,
                    is_required=True,
                    status="invited"
                )
                db.add(participant)

        event.updated_at = get_ph_time()
        db.commit()

        return {
            "success": True,
            "message": "Event updated successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/events/{event_id}")
async def delete_event(event_id: str, db: Session = Depends(get_db)):
    """Delete (deactivate) an event"""
    try:
        event = db.query(Event).filter(
            Event.id == event_id
        ).first()

        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Soft delete
        event.is_active = False
        event.status = "cancelled"
        db.commit()

        return {
            "success": True,
            "message": "Event deleted successfully"
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/events/{event_id}/attendance")
async def mark_event_attendance(
    event_id: str,
    request: MarkEventAttendanceRequest,
    db: Session = Depends(get_db)
):
    """Mark attendance for an event participant"""
    try:
        # Verify event exists
        event = db.query(Event).filter(
            Event.id == event_id,
            Event.is_active == True
        ).first()

        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Find participant record
        participant = db.query(EventParticipant).filter(
            EventParticipant.event_id == event_id,
            EventParticipant.employee_id == request.employee_id
        ).first()

        if not participant:
            raise HTTPException(status_code=404, detail="Participant not found for this event")

        # Mark as attended
        participant.status = "attended"
        participant.attended_at = get_ph_time()

        # Also create attendance log linked to event
        attendance_log = AttendanceLog(
            id=str(uuid.uuid4()),
            employee_id=request.employee_id,
            timestamp=get_ph_time(),
            method="event_checkin",
            event_id=event_id
        )
        db.add(attendance_log)

        db.commit()

        print(f"✅ Event attendance marked: {request.employee_id} for event {event.name}")

        return {
            "success": True,
            "message": "Attendance marked successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/events/stats/summary")
async def get_event_stats(db: Session = Depends(get_db)):
    """Get event statistics for reports"""
    try:
        # Total events
        total_events = db.query(Event).filter(Event.is_active == True).count()

        # Upcoming events
        upcoming_events = db.query(Event).filter(
            Event.is_active == True,
            Event.status == "upcoming",
            Event.event_date >= get_ph_time()
        ).count()

        # Completed events
        completed_events = db.query(Event).filter(
            Event.is_active == True,
            Event.status == "completed"
        ).count()

        # Average attendance rate
        events = db.query(Event).filter(Event.is_active == True).all()
        total_attendance_rate = 0
        event_count = 0

        for event in events:
            participants = db.query(EventParticipant).filter(
                EventParticipant.event_id == event.id
            ).all()

            if len(participants) > 0:
                attended = sum(1 for p in participants if p.status == "attended")
                rate = (attended / len(participants)) * 100
                total_attendance_rate += rate
                event_count += 1

        avg_attendance_rate = total_attendance_rate / event_count if event_count > 0 else 0

        return {
            "success": True,
            "stats": {
                "total_events": total_events,
                "upcoming_events": upcoming_events,
                "completed_events": completed_events,
                "average_attendance_rate": round(avg_attendance_rate, 1)
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Run the application
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=True,  # Enable auto-reload during development
        log_level="info"
    )
