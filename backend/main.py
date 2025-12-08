"""
Face Recognition Backend API
FastAPI application with face detection, recognition, and attendance tracking
"""
from fastapi import FastAPI, HTTPException, Depends, Header, UploadFile, File, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta, time as datetime_time
from database import get_ph_time
from sqlalchemy.orm import Session
import uuid
import csv
import io
import base64

from config import settings
from database import init_db, get_db, Employee, AttendanceLog, Event, EventParticipant, User, Location, Invitation, Camera, EventCamera
from face_processor import FaceProcessor
import secrets
from export_service import ExportService, EventExportService
from auth_service import AuthService
from geo_service import GeoService
from notification_service import NotificationService
from fastapi.responses import StreamingResponse
from camera_stream_service import stream_manager
from camera_monitoring_service import monitoring_service
from polling_attendance_service import PollingAttendanceService
import numpy as np
from email_service import email_service

# Initialize polling attendance service
polling_service = PollingAttendanceService(get_db)

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

# Utility Functions
def calculate_attendance_status(check_in_time: datetime) -> tuple[str, str]:
    """
    Calculate attendance status based on check-in time

    Args:
        check_in_time: DateTime when employee checked in

    Returns:
        tuple: (status, notes) where status is on_time/late/half_day
    """
    # Parse work start time
    work_start_hour, work_start_min = map(int, settings.WORK_START_TIME.split(':'))
    work_start = datetime_time(work_start_hour, work_start_min)

    # Parse half-day cutoff
    half_day_hour, half_day_min = map(int, settings.HALF_DAY_CUTOFF_TIME.split(':'))
    half_day_cutoff = datetime_time(half_day_hour, half_day_min)

    # Get check-in time as time object
    check_in_time_only = check_in_time.time()

    # Calculate grace period end time
    grace_period_end = (datetime.combine(datetime.today(), work_start) +
                       timedelta(minutes=settings.LATE_GRACE_PERIOD_MINUTES)).time()

    # Determine status
    if check_in_time_only <= grace_period_end:
        return "on_time", None
    elif check_in_time_only <= half_day_cutoff:
        # Late but before half-day cutoff
        # Calculate how late
        work_start_dt = datetime.combine(check_in_time.date(), work_start)
        check_in_dt = datetime.combine(check_in_time.date(), check_in_time_only)
        minutes_late = int((check_in_dt - work_start_dt).total_seconds() / 60)
        return "late", f"Late by {minutes_late} minutes"
    else:
        # After half-day cutoff
        work_start_dt = datetime.combine(check_in_time.date(), work_start)
        check_in_dt = datetime.combine(check_in_time.date(), check_in_time_only)
        hours_late = (check_in_dt - work_start_dt).total_seconds() / 3600
        return "half_day", f"Arrived {hours_late:.1f} hours late (Half-day)"

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
    invitation_token: Optional[str] = None  # Optional invitation token for event registration

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

class LoginRequest(BaseModel):
    """Request model for user login"""
    username: str
    password: str

class CreateUserRequest(BaseModel):
    """Request model for creating a new user"""
    username: str
    password: str
    email: str
    full_name: Optional[str] = None
    role: str = "viewer"  # admin, manager, viewer

class UpdateUserRequest(BaseModel):
    """Request model for updating a user"""
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None

class SendInvitationsRequest(BaseModel):
    """Request model for sending event invitations"""
    event_id: str
    emails: List[str]
    base_url: str = "http://localhost:8080"  # Frontend URL

class ValidateInvitationRequest(BaseModel):
    """Request model for validating an invitation token"""
    token: str

# API Endpoints

@app.on_event("startup")
async def startup_event():
    """Initialize database and camera monitoring on startup"""
    init_db()
    print("🚀 Face Recognition Backend Started")
    print(f"📍 API running at: http://{settings.API_HOST}:{settings.API_PORT}")
    print(f"🔍 Liveness detection: {'✅ Enabled' if settings.ENABLE_LIVENESS else '❌ Disabled'}")

    # Start event-based camera monitoring (if camera supports event push)
    db = next(get_db())
    try:
        monitoring_service.start_all_cameras(db)
    finally:
        db.close()

    # Start polling-based attendance monitoring (always works, doesn't rely on camera events)
    print("\n🔄 Starting polling-based attendance monitoring...")
    polling_service.start_all()
    print("✅ Polling service active - will check camera every 3 seconds during active events\n")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    print("🛑 Shutting down camera monitoring...")
    monitoring_service.stop_all_cameras()
    polling_service.stop_all()
    stream_manager.stop_all()
    print("👋 Face Recognition Backend Stopped")

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

# ========================================
# AUTHENTICATION & USER MANAGEMENT
# ========================================

async def get_current_user(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)) -> User:
    """
    Dependency to get current authenticated user from JWT token
    Usage: user = Depends(get_current_user)
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")

    try:
        # Extract token from "Bearer <token>"
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")

        # Verify token
        payload = AuthService.verify_token(token)
        if not payload:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        # Get user from database
        user_id = payload.get("sub")
        user = db.query(User).filter(User.id == user_id).first()

        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="User not found or inactive")

        return user

    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid authorization header format")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

async def get_current_user_from_token_or_query(
    authorization: Optional[str] = Header(None),
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency to get current authenticated user from JWT token (header or query param)
    This is useful for endpoints that need to work with img src tags which cannot send headers
    Usage: user = Depends(get_current_user_from_token_or_query)
    """
    jwt_token = None

    # Try to get token from Authorization header first
    if authorization:
        try:
            scheme, jwt_token = authorization.split()
            if scheme.lower() != "bearer":
                raise HTTPException(status_code=401, detail="Invalid authentication scheme")
        except ValueError:
            raise HTTPException(status_code=401, detail="Invalid authorization header format")
    # Fall back to query parameter
    elif token:
        jwt_token = token
    else:
        raise HTTPException(status_code=401, detail="Authorization token missing")

    try:
        # Verify token
        payload = AuthService.verify_token(jwt_token)
        if not payload:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        # Get user from database
        user_id = payload.get("sub")
        user = db.query(User).filter(User.id == user_id).first()

        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="User not found or inactive")

        return user

    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

def require_role(required_role: str):
    """
    Dependency factory to check if user has required role
    Usage: Depends(require_role("admin"))
    """
    async def role_checker(current_user: User = Depends(get_current_user)):
        if not AuthService.check_permission(current_user.role, required_role):
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient permissions. Required: {required_role}, Current: {current_user.role}"
            )
        return current_user
    return role_checker

@app.post("/api/auth/login")
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    User login endpoint
    Returns JWT access token
    """
    try:
        # Find user by username
        user = db.query(User).filter(User.username == request.username).first()

        if not user:
            raise HTTPException(status_code=401, detail="Invalid username or password")

        # Verify password
        if not AuthService.verify_password(request.password, user.hashed_password):
            raise HTTPException(status_code=401, detail="Invalid username or password")

        # Check if user is active
        if not user.is_active:
            raise HTTPException(status_code=403, detail="User account is inactive")

        # Update last login
        user.last_login = get_ph_time()
        db.commit()

        # Create access token
        access_token = AuthService.create_access_token(data={"sub": user.id})

        return {
            "success": True,
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "full_name": user.full_name,
                "role": user.role
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Login error: {e}")
        raise HTTPException(status_code=500, detail=f"Login failed: {str(e)}")

@app.post("/api/auth/register")
async def register_first_admin(request: CreateUserRequest, db: Session = Depends(get_db)):
    """
    Register first admin user (only works if no users exist)
    For creating additional users, use /api/users endpoint with admin role
    """
    try:
        # Check if any users exist
        existing_users = db.query(User).count()

        if existing_users > 0:
            raise HTTPException(
                status_code=403,
                detail="Registration disabled. First admin already exists. Use /api/users to create new users."
            )

        # Create first admin user
        user_id = str(uuid.uuid4())
        hashed_password = AuthService.get_password_hash(request.password)

        new_user = User(
            id=user_id,
            username=request.username,
            email=request.email,
            hashed_password=hashed_password,
            full_name=request.full_name,
            role="admin",  # First user is always admin
            is_active=True
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        # Create access token
        access_token = AuthService.create_access_token(data={"sub": new_user.id})

        return {
            "success": True,
            "message": "Admin user created successfully",
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": new_user.id,
                "username": new_user.username,
                "email": new_user.email,
                "full_name": new_user.full_name,
                "role": new_user.role
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Registration error: {e}")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.get("/api/auth/me")
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user information"""
    return {
        "success": True,
        "user": {
            "id": current_user.id,
            "username": current_user.username,
            "email": current_user.email,
            "full_name": current_user.full_name,
            "role": current_user.role,
            "is_active": current_user.is_active,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
            "last_login": current_user.last_login.isoformat() if current_user.last_login else None
        }
    }

@app.get("/api/users")
async def get_all_users(
    current_user: User = Depends(require_role("manager")),
    db: Session = Depends(get_db)
):
    """
    Get all users (requires manager or admin role)
    """
    try:
        users = db.query(User).all()

        users_data = [{
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role,
            "is_active": user.is_active,
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "last_login": user.last_login.isoformat() if user.last_login else None
        } for user in users]

        return {
            "success": True,
            "users": users_data,
            "count": len(users_data)
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching users: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch users: {str(e)}")

@app.post("/api/users")
async def create_user(
    request: CreateUserRequest,
    current_user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db)
):
    """
    Create a new user (requires admin role)
    """
    try:
        # Check if username already exists
        existing_user = db.query(User).filter(User.username == request.username).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Username already exists")

        # Check if email already exists
        existing_email = db.query(User).filter(User.email == request.email).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email already exists")

        # Validate role
        if request.role not in ["admin", "manager", "viewer"]:
            raise HTTPException(status_code=400, detail="Invalid role. Must be: admin, manager, or viewer")

        # Create new user
        user_id = str(uuid.uuid4())
        hashed_password = AuthService.get_password_hash(request.password)

        new_user = User(
            id=user_id,
            username=request.username,
            email=request.email,
            hashed_password=hashed_password,
            full_name=request.full_name,
            role=request.role,
            is_active=True
        )

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return {
            "success": True,
            "message": "User created successfully",
            "user": {
                "id": new_user.id,
                "username": new_user.username,
                "email": new_user.email,
                "full_name": new_user.full_name,
                "role": new_user.role
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Error creating user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create user: {str(e)}")

@app.put("/api/users/{user_id}")
async def update_user(
    user_id: str,
    request: UpdateUserRequest,
    current_user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db)
):
    """
    Update a user (requires admin role)
    """
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Update fields if provided
        if request.email is not None:
            # Check if email is already taken by another user
            existing_email = db.query(User).filter(
                User.email == request.email,
                User.id != user_id
            ).first()
            if existing_email:
                raise HTTPException(status_code=400, detail="Email already exists")
            user.email = request.email

        if request.full_name is not None:
            user.full_name = request.full_name

        if request.role is not None:
            if request.role not in ["admin", "manager", "viewer"]:
                raise HTTPException(status_code=400, detail="Invalid role")
            user.role = request.role

        if request.is_active is not None:
            user.is_active = request.is_active

        if request.password is not None:
            user.hashed_password = AuthService.get_password_hash(request.password)

        user.updated_at = get_ph_time()
        db.commit()
        db.refresh(user)

        return {
            "success": True,
            "message": "User updated successfully",
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "full_name": user.full_name,
                "role": user.role,
                "is_active": user.is_active
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Error updating user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update user: {str(e)}")

@app.delete("/api/users/{user_id}")
async def delete_user(
    user_id: str,
    current_user: User = Depends(require_role("admin")),
    db: Session = Depends(get_db)
):
    """
    Delete a user (requires admin role)
    Cannot delete yourself
    """
    try:
        # Prevent self-deletion
        if user_id == current_user.id:
            raise HTTPException(status_code=400, detail="Cannot delete yourself")

        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        db.delete(user)
        db.commit()

        return {
            "success": True,
            "message": "User deleted successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Error deleting user: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")

# ========================================
# FACE DETECTION & RECOGNITION
# ========================================

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
                    # Calculate attendance status (on_time, late, half_day)
                    current_time = get_ph_time()
                    status, notes = calculate_attendance_status(current_time)

                    # Mark new attendance
                    attendance = AttendanceLog(
                        id=str(uuid.uuid4()),
                        employee_id=employee_id,
                        confidence=f"{face['confidence']:.2f}",
                        method="face_recognition",
                        event_id=event_id if event_id else None,
                        status=status,
                        notes=notes
                    )
                    db.add(attendance)
                    db.commit()

                    status_emoji = "✅" if status == "on_time" else "⚠️" if status == "late" else "🕐"
                    status_msg = f" [{status.upper()}" + (f": {notes}" if notes else "") + "]"
                    print(f"{status_emoji} Attendance marked for: {face['name']} ({employee_id}){status_msg}" + (f" - Event: {event_id}" if event_id else ""))
                    face['attendanceMarked'] = True
                    face['attendanceStatus'] = status
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

        # Create new employee with QR code token
        employee = Employee(
            id=str(uuid.uuid4()),
            name=request.name,
            firstname=request.firstname,
            lastname=request.lastname,
            employee_id=request.employeeId,
            department=request.department,
            email=request.email,
            embeddings=embedding,
            qr_code_token=str(uuid.uuid4()),  # Generate QR code token for attendance
            is_active=True
        )

        db.add(employee)
        db.commit()
        db.refresh(employee)

        print(f"✅ Employee registered successfully: {request.name} ({request.employeeId})")

        # Reload faces for camera monitoring
        monitoring_service.reload_all_faces()
        print(f"🔄 Face encodings reloaded for monitored cameras")

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
async def get_all_employees(
    search: Optional[str] = None,
    department: Optional[str] = None,
    limit: Optional[int] = 1000,
    db: Session = Depends(get_db)
):
    """
    Get all registered employees with optional search and filters

    Args:
        search: Search by name, employee ID, or email
        department: Filter by department
        limit: Maximum number of records to return (default: 1000)

    Returns:
        List of employees
    """
    try:
        query = db.query(Employee).filter(Employee.is_active == True)

        # Filter by department
        if department:
            query = query.filter(Employee.department == department)

        employees = query.limit(limit).all()

        # Build response
        employees_data = [
            {
                "id": emp.id,
                "name": emp.name,
                "firstname": emp.firstname,
                "lastname": emp.lastname,
                "employeeId": emp.employee_id,
                "department": emp.department or "",
                "email": emp.email or "",
                "createdAt": emp.created_at.isoformat()
            }
            for emp in employees
        ]

        # Apply search filter
        if search:
            search_lower = search.lower()
            employees_data = [
                emp for emp in employees_data
                if (search_lower in emp['name'].lower() or
                    search_lower in emp['employeeId'].lower() or
                    search_lower in emp['email'].lower() or
                    search_lower in (emp['department'] or '').lower())
            ]

        return {
            "success": True,
            "count": len(employees_data),
            "employees": employees_data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/attendance")
async def get_attendance_logs(
    date: Optional[str] = None,
    employee_id: Optional[str] = None,
    search: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    method: Optional[str] = None,
    limit: Optional[int] = 1000,
    db: Session = Depends(get_db)
):
    """
    Get attendance logs with optional filters and search

    Args:
        date: Filter by specific date (YYYY-MM-DD format)
        employee_id: Filter by employee ID
        search: Search by employee name or ID
        status: Filter by status (on_time, late, half_day)
        start_date: Start date for range filter (YYYY-MM-DD)
        end_date: End date for range filter (YYYY-MM-DD)
        method: Filter by method (face_recognition, manual, etc.)
        limit: Maximum number of records to return (default: 1000)

    Returns:
        List of attendance logs
    """
    try:
        query = db.query(AttendanceLog)

        # Apply date filters
        if date:
            target_date = datetime.strptime(date, "%Y-%m-%d")
            next_date = target_date + timedelta(days=1)
            query = query.filter(
                AttendanceLog.timestamp >= target_date,
                AttendanceLog.timestamp < next_date
            )
        elif start_date and end_date:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            end = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
            query = query.filter(
                AttendanceLog.timestamp >= start,
                AttendanceLog.timestamp < end
            )

        # Filter by employee ID
        if employee_id:
            query = query.filter(AttendanceLog.employee_id == employee_id)

        # Filter by status
        if status:
            query = query.filter(AttendanceLog.status == status)

        # Filter by method
        if method:
            query = query.filter(AttendanceLog.method == method)

        # Get logs
        logs = query.order_by(AttendanceLog.timestamp.desc()).limit(limit).all()

        # Get employee details
        employee_ids = list(set([log.employee_id for log in logs]))
        employees = db.query(Employee).filter(
            Employee.employee_id.in_(employee_ids)
        ).all()
        employee_map = {emp.employee_id: emp for emp in employees}

        # Build response with all details
        logs_data = [
            {
                "id": log.id,
                "employeeId": log.employee_id,
                "employeeName": employee_map.get(log.employee_id).name if log.employee_id in employee_map else "Unknown",
                "timestamp": log.timestamp.isoformat(),
                "confidence": log.confidence,
                "method": log.method,
                "status": log.status or "on_time",
                "notes": log.notes or ""
            }
            for log in logs
        ]

        # Apply search filter on employee name or ID
        if search:
            search_lower = search.lower()
            logs_data = [
                log for log in logs_data
                if search_lower in log['employeeName'].lower() or search_lower in log['employeeId'].lower()
            ]

        return {
            "success": True,
            "count": len(logs_data),
            "logs": logs_data
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

# ========================================
# BULK OPERATIONS & MULTI-FACE REGISTRATION
# ========================================

@app.get("/api/employees/bulk-import/template")
async def download_bulk_import_template():
    """
    Download CSV template for bulk employee import

    Returns a CSV file with required columns for importing employees
    """
    try:
        # Create CSV template in memory
        output = io.StringIO()
        writer = csv.writer(output)

        # Write header row
        writer.writerow([
            'employee_id',
            'name',
            'email',
            'department',
            'position',
            'phone',
            'address'
        ])

        # Write example row
        writer.writerow([
            'EMP001',
            'John Doe',
            'john.doe@company.com',
            'Engineering',
            'Software Engineer',
            '+1234567890',
            '123 Main St, City, Country'
        ])

        # Write another example
        writer.writerow([
            'EMP002',
            'Jane Smith',
            'jane.smith@company.com',
            'Marketing',
            'Marketing Manager',
            '+0987654321',
            '456 Oak Ave, City, Country'
        ])

        # Get CSV content
        output.seek(0)

        return StreamingResponse(
            io.BytesIO(output.getvalue().encode()),
            media_type="text/csv",
            headers={
                "Content-Disposition": "attachment; filename=employee_import_template.csv"
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate template: {str(e)}")


class BulkImportRequest(BaseModel):
    csv_data: str  # Base64 encoded CSV content


@app.post("/api/employees/bulk-import")
async def bulk_import_employees(
    request: BulkImportRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Bulk import employees from CSV data

    Expects Base64-encoded CSV with columns: employee_id, name, email, department, position, phone, address
    Note: Face images must be added separately for each employee
    """
    try:
        # Check admin/manager permission
        if not AuthService.check_permission(current_user.role, "manager"):
            raise HTTPException(status_code=403, detail="Manager or Admin access required")

        # Decode CSV data
        try:
            csv_content = base64.b64decode(request.csv_data).decode('utf-8')
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid CSV data encoding: {str(e)}")

        # Parse CSV
        csv_file = io.StringIO(csv_content)
        reader = csv.DictReader(csv_file)

        # Validate required columns
        required_columns = ['employee_id', 'name', 'email']
        if not all(col in reader.fieldnames for col in required_columns):
            raise HTTPException(
                status_code=400,
                detail=f"CSV must contain columns: {', '.join(required_columns)}"
            )

        imported_count = 0
        skipped_count = 0
        errors = []

        for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is row 1)
            try:
                employee_id = row.get('employee_id', '').strip()
                name = row.get('name', '').strip()
                email = row.get('email', '').strip()

                # Validate required fields
                if not employee_id or not name:
                    errors.append(f"Row {row_num}: Missing employee_id or name")
                    skipped_count += 1
                    continue

                # Check if employee already exists
                existing = db.query(Employee).filter(
                    Employee.employee_id == employee_id
                ).first()

                if existing:
                    errors.append(f"Row {row_num}: Employee ID '{employee_id}' already exists")
                    skipped_count += 1
                    continue

                # Create new employee (without face encoding - must be added later)
                new_employee = Employee(
                    employee_id=employee_id,
                    name=name,
                    email=email or None,
                    department=row.get('department', '').strip() or None,
                    position=row.get('position', '').strip() or None,
                    phone=row.get('phone', '').strip() or None,
                    address=row.get('address', '').strip() or None,
                    is_active=True,
                    created_at=get_ph_time()
                )

                db.add(new_employee)
                imported_count += 1

            except Exception as e:
                errors.append(f"Row {row_num}: {str(e)}")
                skipped_count += 1
                continue

        # Commit all successful imports
        try:
            db.commit()
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

        return {
            "success": True,
            "message": f"Bulk import completed",
            "imported_count": imported_count,
            "skipped_count": skipped_count,
            "errors": errors[:20],  # Limit to first 20 errors
            "note": "Face images must be added separately for each employee via registration"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Bulk import failed: {str(e)}")


class BulkDeleteRequest(BaseModel):
    employee_ids: List[str]


@app.post("/api/employees/bulk-delete")
async def bulk_delete_employees(
    request: BulkDeleteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Bulk delete (deactivate) multiple employees
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        if not request.employee_ids:
            raise HTTPException(status_code=400, detail="No employee IDs provided")

        deleted_count = 0
        not_found = []

        for employee_id in request.employee_ids:
            employee = db.query(Employee).filter(
                Employee.employee_id == employee_id
            ).first()

            if employee:
                employee.is_active = False
                deleted_count += 1
            else:
                not_found.append(employee_id)

        db.commit()

        return {
            "success": True,
            "message": f"Bulk delete completed",
            "deleted_count": deleted_count,
            "not_found": not_found
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Bulk delete failed: {str(e)}")


class AddFaceRequest(BaseModel):
    image: str  # Base64 encoded image


@app.post("/api/employees/{employee_id}/add-face")
async def add_face_to_employee(
    employee_id: str,
    request: AddFaceRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Add additional face encoding to an existing employee (Multi-face registration)

    This allows registering multiple photos of the same person for better recognition accuracy.
    The new encoding is merged with existing encodings.
    """
    try:
        # Check manager permission
        if not AuthService.check_permission(current_user.role, "manager"):
            raise HTTPException(status_code=403, detail="Manager or Admin access required")

        # Find employee
        employee = db.query(Employee).filter(
            Employee.employee_id == employee_id,
            Employee.is_active == True
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Employee not found")

        # Process face from image
        try:
            # Remove data URL prefix if present
            image_data = request.image
            if ',' in image_data:
                image_data = image_data.split(',')[1]

            # Decode base64 image
            image_bytes = base64.b64decode(image_data)

            # Process face and get encoding
            result = face_processor.process_face_from_bytes(image_bytes)

            if not result['success']:
                raise HTTPException(
                    status_code=400,
                    detail=result.get('message', 'Face processing failed')
                )

            new_encoding = result['encoding']

            # Merge with existing encodings
            if employee.face_encoding:
                try:
                    # Parse existing encoding
                    import json
                    existing_encodings = json.loads(employee.face_encoding)

                    # If it's a single encoding (old format), convert to array
                    if isinstance(existing_encodings, list) and len(existing_encodings) == 128:
                        existing_encodings = [existing_encodings]

                    # Add new encoding
                    existing_encodings.append(new_encoding)

                    # Limit to 5 encodings per person
                    if len(existing_encodings) > 5:
                        existing_encodings = existing_encodings[-5:]

                    # Save updated encodings
                    employee.face_encoding = json.dumps(existing_encodings)

                except Exception as e:
                    # If parsing fails, replace with new encoding
                    employee.face_encoding = json.dumps([new_encoding])
            else:
                # No existing encoding, save as array
                import json
                employee.face_encoding = json.dumps([new_encoding])

            employee.updated_at = get_ph_time()
            db.commit()

            # Count total encodings
            import json
            encodings = json.loads(employee.face_encoding)
            face_count = len(encodings) if isinstance(encodings[0], list) else 1

            return {
                "success": True,
                "message": f"Face added successfully to {employee.name}",
                "employee_id": employee_id,
                "total_faces": face_count
            }

        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"Face processing failed: {str(e)}"
            )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/employees/{employee_id}/face-count")
async def get_employee_face_count(
    employee_id: str,
    db: Session = Depends(get_db)
):
    """
    Get the number of face encodings registered for an employee
    """
    try:
        employee = db.query(Employee).filter(
            Employee.employee_id == employee_id,
            Employee.is_active == True
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Employee not found")

        if not employee.face_encoding:
            return {
                "success": True,
                "employee_id": employee_id,
                "face_count": 0,
                "has_faces": False
            }

        try:
            import json
            encodings = json.loads(employee.face_encoding)

            # Check if it's multiple encodings or single encoding
            if isinstance(encodings, list):
                if len(encodings) > 0 and isinstance(encodings[0], list):
                    # Multiple encodings (array of arrays)
                    face_count = len(encodings)
                else:
                    # Single encoding (flat array)
                    face_count = 1
            else:
                face_count = 1

            return {
                "success": True,
                "employee_id": employee_id,
                "face_count": face_count,
                "has_faces": face_count > 0
            }

        except Exception:
            return {
                "success": True,
                "employee_id": employee_id,
                "face_count": 1,
                "has_faces": True
            }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ========================================
# QR CODE ATTENDANCE
# ========================================

@app.get("/api/employees/{employee_id}/qr-code")
async def get_employee_qr_code(employee_id: str, db: Session = Depends(get_db)):
    """
    Get or generate QR code token for an employee

    Returns a unique token that can be encoded in a QR code
    """
    try:
        employee = db.query(Employee).filter(
            Employee.employee_id == employee_id,
            Employee.is_active == True
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Employee not found")

        # Generate QR code token if it doesn't exist
        if not employee.qr_code_token:
            employee.qr_code_token = str(uuid.uuid4())
            db.commit()
            db.refresh(employee)

        return {
            "success": True,
            "employee_id": employee.employee_id,
            "employee_name": employee.name,
            "qr_token": employee.qr_code_token,
            "qr_data": f"ATTENDANCE:{employee.qr_code_token}"  # Format for QR code
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/attendance/qr-check-in")
async def qr_code_check_in(
    qr_token: str,
    event_id: Optional[str] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    db: Session = Depends(get_db)
):
    """
    Mark attendance using QR code token

    Args:
        qr_token: The QR code token from the scanned QR code
        event_id: Optional event ID for event attendance
        latitude: Optional GPS latitude for location verification
        longitude: Optional GPS longitude for location verification
    """
    try:
        # Find employee by QR token
        employee = db.query(Employee).filter(
            Employee.qr_code_token == qr_token,
            Employee.is_active == True
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Invalid QR code or employee not found")

        # Check cooldown period (prevent duplicate check-ins)
        cooldown_minutes = settings.ATTENDANCE_COOLDOWN_MINUTES
        cooldown_time = get_ph_time() - timedelta(minutes=cooldown_minutes)

        recent_log = db.query(AttendanceLog).filter(
            AttendanceLog.employee_id == employee.employee_id,
            AttendanceLog.timestamp >= cooldown_time
        ).first()

        if recent_log and not event_id:
            raise HTTPException(
                status_code=400,
                detail=f"Attendance already recorded. Please wait {cooldown_minutes} minutes before checking in again."
            )

        # Verify GPS location if coordinates provided
        location_verified = False
        distance_from_office = None

        if latitude is not None and longitude is not None:
            # Validate coordinates
            if not GeoService.validate_coordinates(latitude, longitude):
                raise HTTPException(status_code=400, detail="Invalid GPS coordinates")

            # Get all active locations
            allowed_locations = db.query(Location).filter(Location.is_active == True).all()

            # Verify location
            location_verified, distance_from_office, nearest_location = GeoService.verify_location(
                latitude, longitude, allowed_locations
            )

            print(f"📍 GPS Verification: verified={location_verified}, distance={distance_from_office}m, nearest={nearest_location}")

        # Calculate attendance status
        check_in_time = get_ph_time()
        status, notes = calculate_attendance_status(check_in_time)

        # Create attendance log
        log_id = str(uuid.uuid4())
        new_log = AttendanceLog(
            id=log_id,
            employee_id=employee.employee_id,
            timestamp=check_in_time,
            confidence="100.0",  # QR code is 100% confident
            method="qr_code",
            event_id=event_id,
            status=status,
            notes=notes,
            latitude=latitude,
            longitude=longitude,
            location_verified=location_verified,
            distance_from_office=distance_from_office
        )

        db.add(new_log)

        # Update event participant if event_id provided
        if event_id:
            participant = db.query(EventParticipant).filter(
                EventParticipant.event_id == event_id,
                EventParticipant.employee_id == employee.employee_id
            ).first()

            if participant:
                participant.status = "attended"
                participant.attended_at = check_in_time

        db.commit()

        # Send email notifications (non-blocking - won't fail check-in if email fails)
        if employee.email:
            try:
                # Send late arrival notification if late
                if status == "late" and notes:
                    # Extract minutes late from notes
                    import re
                    match = re.search(r'(\d+) minutes', notes)
                    minutes_late = int(match.group(1)) if match else 0

                    if minutes_late > 0:
                        NotificationService.send_late_arrival_notification(
                            employee_name=employee.name,
                            employee_email=employee.email,
                            check_in_time=check_in_time,
                            minutes_late=minutes_late
                        )

                # Optionally send check-in confirmation for all (can be disabled in settings)
                # NotificationService.send_check_in_confirmation(
                #     employee_name=employee.name,
                #     employee_email=employee.email,
                #     check_in_time=check_in_time,
                #     status=status,
                #     method="qr_code"
                # )
            except Exception as email_error:
                print(f"⚠️ Email notification failed (non-critical): {email_error}")

        return {
            "success": True,
            "message": f"Attendance recorded successfully for {employee.name}",
            "employee": {
                "id": employee.employee_id,
                "name": employee.name,
                "department": employee.department
            },
            "attendance": {
                "timestamp": check_in_time.isoformat(),
                "method": "qr_code",
                "status": status,
                "notes": notes,
                "location_verified": location_verified,
                "distance_from_office": distance_from_office
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"QR check-in error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/employees/{employee_id}/regenerate-qr")
async def regenerate_qr_code(employee_id: str, db: Session = Depends(get_db)):
    """
    Regenerate QR code token for an employee (useful if compromised)
    """
    try:
        employee = db.query(Employee).filter(
            Employee.employee_id == employee_id,
            Employee.is_active == True
        ).first()

        if not employee:
            raise HTTPException(status_code=404, detail="Employee not found")

        # Generate new token
        employee.qr_code_token = str(uuid.uuid4())
        db.commit()
        db.refresh(employee)

        return {
            "success": True,
            "message": "QR code regenerated successfully",
            "qr_token": employee.qr_code_token,
            "qr_data": f"ATTENDANCE:{employee.qr_code_token}"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# ========================================
# ONLINE REGISTRATION
# ========================================

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

        # Create new employee record with QR code token
        employee = Employee(
            id=str(uuid.uuid4()),
            name=full_name,
            firstname=request.firstname,
            lastname=request.lastname,
            employee_id=request.employeeId,
            department=request.department,
            email=request.email,
            embeddings=embedding,
            qr_code_token=str(uuid.uuid4()),  # Generate QR code token for attendance
            is_active=True
        )

        db.add(employee)
        db.commit()
        db.refresh(employee)

        print(f"✅ Online registration successful: {full_name} ({request.employeeId})")

        # Handle invitation token if provided
        event_info = None
        if request.invitation_token:
            try:
                invitation = db.query(Invitation).filter(
                    Invitation.token == request.invitation_token
                ).first()

                if invitation and not invitation.is_used and invitation.expires_at > get_ph_time():
                    # Mark invitation as used
                    invitation.is_used = True
                    invitation.used_at = get_ph_time()
                    invitation.employee_id = employee.employee_id

                    # Add employee as participant to the event if invitation is for an event
                    if invitation.event_id:
                        # Check if participant already exists
                        existing_participant = db.query(EventParticipant).filter(
                            EventParticipant.event_id == invitation.event_id,
                            EventParticipant.employee_id == employee.employee_id
                        ).first()

                        if not existing_participant:
                            participant = EventParticipant(
                                id=str(uuid.uuid4()),
                                event_id=invitation.event_id,
                                employee_id=employee.employee_id,
                                is_required=True,
                                status="confirmed"
                            )
                            db.add(participant)

                        # Get event details for response
                        event = db.query(Event).filter(Event.id == invitation.event_id).first()
                        if event:
                            event_info = {
                                "id": event.id,
                                "name": event.name,
                                "event_date": event.event_date.isoformat(),
                                "location": event.location
                            }

                    db.commit()
                    print(f"✅ Invitation processed for {request.email}")

            except Exception as e:
                print(f"⚠️ Failed to process invitation: {str(e)}")
                # Don't fail the registration if invitation processing fails

        response_message = "Registration successful! You can now use face recognition to mark attendance."
        if event_info:
            response_message += f" You have been registered for the event: {event_info['name']}."

        return {
            "success": True,
            "message": response_message,
            "data": {
                "id": employee.id,
                "name": full_name,
                "employeeId": employee.employee_id,
                "email": employee.email,
                "department": employee.department,
                "registrationDate": employee.created_at.isoformat()
            },
            "event": event_info
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

    try:
        # Get current datetime in local timezone
        now = datetime.now()
        current_date = now.date()
        current_time = now.time()

        # Handle both time objects and strings
        if isinstance(start_time, datetime_time):
            start_time_obj = start_time
        elif isinstance(start_time, str):
            parts = start_time.split(':')
            start_hour = int(parts[0])
            start_minute = int(parts[1]) if len(parts) > 1 else 0
            # Validate hour
            if start_hour < 0 or start_hour > 23:
                print(f"⚠️ Invalid start_time hour: {start_hour}, defaulting to 0")
                start_hour = 0
            start_time_obj = datetime_time(start_hour, start_minute)
        else:
            # Default to start of day
            start_time_obj = datetime_time(0, 0)

        if isinstance(end_time, datetime_time):
            end_time_obj = end_time
        elif isinstance(end_time, str):
            parts = end_time.split(':')
            end_hour = int(parts[0])
            end_minute = int(parts[1]) if len(parts) > 1 else 0
            # Validate hour
            if end_hour < 0 or end_hour > 23:
                print(f"⚠️ Invalid end_time hour: {end_hour}, defaulting to 23")
                end_hour = 23
            end_time_obj = datetime_time(end_hour, end_minute)
        else:
            # Default to end of day
            end_time_obj = datetime_time(23, 59)

        # Convert event_date to date if it's datetime
        if hasattr(event_date, 'date'):
            event_date_obj = event_date.date()
        else:
            event_date_obj = event_date

        # Compare dates
        if event_date_obj > current_date:
            return "upcoming"
        elif event_date_obj < current_date:
            return "completed"
        else:
            # Same day - check time
            if current_time < start_time_obj:
                return "upcoming"
            elif current_time > end_time_obj:
                return "completed"
            else:
                return "ongoing"

    except Exception as e:
        print(f"⚠️ Error calculating event status: {e}")
        # Default to upcoming if we can't determine
        return "upcoming"

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

            # Convert times to strings if they're time objects
            start_time_str = event.start_time if isinstance(event.start_time, str) else event.start_time.strftime("%H:%M") if event.start_time else "00:00"
            end_time_str = event.end_time if isinstance(event.end_time, str) else event.end_time.strftime("%H:%M") if event.end_time else "23:59"

            event_data.append({
                "id": event.id,
                "name": event.name,
                "description": event.description,
                "event_date": event.event_date.isoformat(),
                "start_time": start_time_str,
                "end_time": end_time_str,
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

# Event Invitation Endpoints

@app.post("/api/events/send-invitations")
async def send_event_invitations(
    request: SendInvitationsRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Send invitations for an event
    """
    try:
        print(f"\n📧 === SENDING EVENT INVITATIONS ===")
        print(f"Event ID: {request.event_id}")
        print(f"Emails to invite: {request.emails}")
        print(f"Base URL: {request.base_url}")
        print(f"User: {current_user.username}")

        # Verify event exists
        event = db.query(Event).filter(Event.id == request.event_id).first()
        if not event:
            print(f"❌ Event not found: {request.event_id}")
            raise HTTPException(status_code=404, detail="Event not found")

        print(f"✅ Found event: {event.name}")

        successful_sends = []
        failed_sends = []

        for email in request.emails:
            print(f"\n📨 Processing invitation for: {email}")
            try:
                # Check if invitation already exists for this email and event
                existing = db.query(Invitation).filter(
                    Invitation.email == email,
                    Invitation.event_id == request.event_id,
                    Invitation.is_used == False
                ).first()

                if existing:
                    # Update expiration if invitation exists
                    existing.expires_at = get_ph_time() + timedelta(days=7)
                    invitation_token = existing.token
                else:
                    # Create new invitation
                    invitation_token = secrets.token_urlsafe(32)
                    invitation = Invitation(
                        id=str(uuid.uuid4()),
                        email=email,
                        token=invitation_token,
                        expires_at=get_ph_time() + timedelta(days=7),  # 7 days to register
                        event_id=request.event_id,
                        created_by=current_user.id,
                        is_used=False
                    )
                    db.add(invitation)

                db.commit()
                print(f"✅ Invitation record saved to database")

                # Send email
                print(f"📤 Attempting to send email to: {email}")
                success = email_service.send_event_invitation(
                    to_email=email,
                    event_name=event.name,
                    event_date=event.event_date,
                    event_location=event.location or "To be announced",
                    invitation_token=invitation_token,
                    base_url=request.base_url
                )

                if success:
                    print(f"✅ Email sent successfully to: {email}")
                    successful_sends.append(email)
                else:
                    print(f"❌ Email failed to send to: {email}")
                    failed_sends.append(email)

            except Exception as e:
                print(f"❌ Exception while processing {email}: {str(e)}")
                import traceback
                traceback.print_exc()
                failed_sends.append(email)

        print(f"\n📊 === INVITATION SUMMARY ===")
        print(f"✅ Successful: {len(successful_sends)} - {successful_sends}")
        print(f"❌ Failed: {len(failed_sends)} - {failed_sends}")

        return {
            "success": True,
            "message": f"Invitations processed: {len(successful_sends)} sent, {len(failed_sends)} failed",
            "successful": successful_sends,
            "failed": failed_sends
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/events/{event_id}/invitations")
async def get_event_invitations(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get all invitations for an event
    """
    try:
        invitations = db.query(Invitation).filter(
            Invitation.event_id == event_id
        ).all()

        return {
            "success": True,
            "invitations": [
                {
                    "id": inv.id,
                    "email": inv.email,
                    "is_used": inv.is_used,
                    "used_at": inv.used_at.isoformat() if inv.used_at else None,
                    "expires_at": inv.expires_at.isoformat(),
                    "created_at": inv.created_at.isoformat(),
                    "employee_id": inv.employee_id
                }
                for inv in invitations
            ]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/invitations/validate")
async def validate_invitation(
    request: ValidateInvitationRequest,
    db: Session = Depends(get_db)
):
    """
    Validate an invitation token (public endpoint - no auth required)
    """
    try:
        invitation = db.query(Invitation).filter(
            Invitation.token == request.token
        ).first()

        if not invitation:
            return {
                "success": False,
                "valid": False,
                "message": "Invalid invitation token"
            }

        # Check if already used
        if invitation.is_used:
            return {
                "success": False,
                "valid": False,
                "message": "This invitation has already been used"
            }

        # Check if expired
        if invitation.expires_at < get_ph_time():
            return {
                "success": False,
                "valid": False,
                "message": "This invitation has expired"
            }

        # Get event details if invitation is for an event
        event_details = None
        if invitation.event_id:
            event = db.query(Event).filter(Event.id == invitation.event_id).first()
            if event:
                event_details = {
                    "id": event.id,
                    "name": event.name,
                    "description": event.description,
                    "event_date": event.event_date.isoformat(),
                    "location": event.location
                }

        return {
            "success": True,
            "valid": True,
            "invitation": {
                "email": invitation.email,
                "event_id": invitation.event_id,
                "event": event_details
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/invitations/{invitation_id}/resend")
async def resend_invitation(
    invitation_id: str,
    base_url: str = "http://localhost:8080",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Resend an invitation email
    """
    try:
        invitation = db.query(Invitation).filter(Invitation.id == invitation_id).first()

        if not invitation:
            raise HTTPException(status_code=404, detail="Invitation not found")

        if invitation.is_used:
            raise HTTPException(status_code=400, detail="Cannot resend used invitation")

        # Update expiration
        invitation.expires_at = get_ph_time() + timedelta(days=7)
        db.commit()

        # Get event details
        event = db.query(Event).filter(Event.id == invitation.event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Send email
        success = email_service.send_event_invitation(
            to_email=invitation.email,
            event_name=event.name,
            event_date=event.event_date,
            event_location=event.location or "To be announced",
            invitation_token=invitation.token,
            base_url=base_url
        )

        if success:
            return {
                "success": True,
                "message": f"Invitation resent to {invitation.email}"
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to send email")

    except HTTPException:
        raise
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
        current_time = get_ph_time()
        participant.attended_at = current_time

        # Calculate attendance status
        status, notes = calculate_attendance_status(current_time)

        # Also create attendance log linked to event
        attendance_log = AttendanceLog(
            id=str(uuid.uuid4()),
            employee_id=request.employee_id,
            timestamp=current_time,
            method="event_checkin",
            event_id=event_id,
            status=status,
            notes=notes
        )
        db.add(attendance_log)

        db.commit()

        status_indicator = f" [{status.upper()}" + (f": {notes}" if notes else "") + "]"
        print(f"✅ Event attendance marked: {request.employee_id} for event {event.name}{status_indicator}")

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

# ============================================
# EXPORT ENDPOINTS
# ============================================

@app.get("/api/attendance/export")
async def export_attendance(
    format: str = "csv",  # csv, excel, pdf
    date: Optional[str] = None,
    employee_id: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Export attendance logs in various formats (CSV, Excel, PDF)

    Args:
        format: Export format (csv, excel, pdf)
        date: Filter by specific date (YYYY-MM-DD)
        employee_id: Filter by employee ID
        start_date: Start date range (YYYY-MM-DD)
        end_date: End date range (YYYY-MM-DD)

    Returns:
        Downloadable file in specified format
    """
    try:
        print(f"\n📊 Exporting attendance data as {format.upper()}")

        # Build query
        query = db.query(AttendanceLog)

        # Apply filters
        if date:
            target_date = datetime.strptime(date, "%Y-%m-%d")
            next_date = target_date + timedelta(days=1)
            query = query.filter(
                AttendanceLog.timestamp >= target_date,
                AttendanceLog.timestamp < next_date
            )
        elif start_date and end_date:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            end = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
            query = query.filter(
                AttendanceLog.timestamp >= start,
                AttendanceLog.timestamp < end
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

        # Prepare data for export
        export_data = []
        for log in logs:
            emp = employee_map.get(log.employee_id)
            export_data.append({
                'employee_id': log.employee_id,
                'employee_name': emp.name if emp else 'Unknown',
                'timestamp': log.timestamp,
                'confidence': log.confidence,
                'status': log.status or 'N/A',
                'notes': log.notes or '',
                'method': log.method
            })

        # Generate export based on format
        if format.lower() == 'csv':
            buffer = ExportService.export_to_csv(export_data)
            media_type = "text/csv"
            filename = f"attendance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"

        elif format.lower() == 'excel':
            buffer = ExportService.export_to_excel(export_data)
            media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            filename = f"attendance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

        elif format.lower() == 'pdf':
            buffer = ExportService.export_to_pdf(export_data, "Attendance Report")
            media_type = "application/pdf"
            filename = f"attendance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"

        else:
            raise HTTPException(status_code=400, detail="Invalid format. Use: csv, excel, or pdf")

        print(f"✅ Exported {len(export_data)} records as {format.upper()}")

        return StreamingResponse(
            buffer,
            media_type=media_type,
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Export error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")


@app.get("/api/events/{event_id}/export")
async def export_event_attendance(
    event_id: str,
    format: str = "pdf",  # csv, excel, pdf
    db: Session = Depends(get_db)
):
    """
    Export event attendance report

    Args:
        event_id: Event ID
        format: Export format (csv, excel, pdf)

    Returns:
        Downloadable event attendance report
    """
    try:
        print(f"\n📊 Exporting event attendance for {event_id} as {format.upper()}")

        # Get event
        event = db.query(Event).filter(Event.id == event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Get participants
        participants = db.query(EventParticipant).filter(
            EventParticipant.event_id == event_id
        ).all()

        # Get employee details
        employee_ids = [p.employee_id for p in participants]
        employees = db.query(Employee).filter(
            Employee.employee_id.in_(employee_ids)
        ).all()
        employee_map = {emp.employee_id: emp for emp in employees}

        # Prepare participant data
        participant_data = []
        for p in participants:
            emp = employee_map.get(p.employee_id)
            participant_data.append({
                'employee_id': p.employee_id,
                'employee_name': emp.name if emp else 'Unknown',
                'status': p.status,
                'attended_at': p.attended_at.strftime('%Y-%m-%d %I:%M %p') if p.attended_at else 'N/A',
                'is_required': 'Yes' if p.is_required else 'No'
            })

        # Event data
        event_data = {
            'name': event.name,
            'event_date': event.event_date.strftime('%Y-%m-%d'),
            'location': event.location or 'N/A',
            'status': event.status
        }

        # Generate export
        buffer = EventExportService.export_event_attendance(
            event_data,
            participant_data,
            format.lower()
        )

        # Set media type and filename
        if format.lower() == 'csv':
            media_type = "text/csv"
            extension = "csv"
        elif format.lower() == 'excel':
            media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            extension = "xlsx"
        else:
            media_type = "application/pdf"
            extension = "pdf"

        filename = f"{event.name.replace(' ', '_')}_attendance.{extension}"

        print(f"✅ Exported event attendance with {len(participant_data)} participants")

        return StreamingResponse(
            buffer,
            media_type=media_type,
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Event export error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")

# ============================================
# ANALYTICS ENDPOINTS
# ============================================

@app.get("/api/analytics/overview")
async def get_analytics_overview(db: Session = Depends(get_db)):
    """
    Get comprehensive analytics overview

    Returns: Dashboard metrics, trends, and statistics
    """
    try:
        from datetime import timedelta
        from sqlalchemy import func, extract

        print("\n📊 Generating analytics overview...")

        today = get_ph_time().date()
        yesterday = today - timedelta(days=1)
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)

        # Today's attendance
        today_start = datetime.combine(today, datetime.min.time())
        today_end = datetime.combine(today, datetime.max.time())

        today_attendance = db.query(AttendanceLog).filter(
            AttendanceLog.timestamp >= today_start,
            AttendanceLog.timestamp <= today_end
        ).count()

        # Yesterday's attendance
        yesterday_start = datetime.combine(yesterday, datetime.min.time())
        yesterday_end = datetime.combine(yesterday, datetime.max.time())

        yesterday_attendance = db.query(AttendanceLog).filter(
            AttendanceLog.timestamp >= yesterday_start,
            AttendanceLog.timestamp <= yesterday_end
        ).count()

        # Total employees
        total_employees = db.query(Employee).filter(Employee.is_active == True).count()

        # Unique employees today
        today_logs = db.query(AttendanceLog).filter(
            AttendanceLog.timestamp >= today_start,
            AttendanceLog.timestamp <= today_end
        ).all()
        unique_today = len(set([log.employee_id for log in today_logs]))

        # Attendance rate
        attendance_rate = (unique_today / total_employees * 100) if total_employees > 0 else 0

        # Status breakdown (today)
        status_counts = {
            'on_time': 0,
            'late': 0,
            'half_day': 0
        }

        for log in today_logs:
            status = log.status or 'on_time'
            if status in status_counts:
                status_counts[status] += 1

        # Last 7 days trend
        daily_trend = []
        for i in range(6, -1, -1):
            day = today - timedelta(days=i)
            day_start = datetime.combine(day, datetime.min.time())
            day_end = datetime.combine(day, datetime.max.time())

            day_count = db.query(AttendanceLog).filter(
                AttendanceLog.timestamp >= day_start,
                AttendanceLog.timestamp <= day_end
            ).count()

            daily_trend.append({
                'date': day.strftime('%Y-%m-%d'),
                'day_name': day.strftime('%a'),
                'count': day_count
            })

        # Hourly distribution (today)
        hourly_distribution = {}
        for log in today_logs:
            hour = log.timestamp.hour
            hourly_distribution[hour] = hourly_distribution.get(hour, 0) + 1

        hourly_data = [
            {'hour': hour, 'count': hourly_distribution.get(hour, 0)}
            for hour in range(24)
        ]

        # Top employees (by check-ins this month)
        month_start = datetime.combine(month_ago, datetime.min.time())
        month_logs = db.query(
            AttendanceLog.employee_id,
            func.count(AttendanceLog.id).label('count')
        ).filter(
            AttendanceLog.timestamp >= month_start
        ).group_by(AttendanceLog.employee_id).order_by(func.count(AttendanceLog.id).desc()).limit(5).all()

        top_employees = []
        for emp_id, count in month_logs:
            emp = db.query(Employee).filter(Employee.employee_id == emp_id).first()
            if emp:
                top_employees.append({
                    'employee_id': emp_id,
                    'name': emp.name,
                    'check_ins': count
                })

        return {
            "success": True,
            "data": {
                "today": {
                    "total_check_ins": today_attendance,
                    "unique_employees": unique_today,
                    "attendance_rate": round(attendance_rate, 1),
                    "on_time": status_counts['on_time'],
                    "late": status_counts['late'],
                    "half_day": status_counts['half_day']
                },
                "comparison": {
                    "yesterday": yesterday_attendance,
                    "change": today_attendance - yesterday_attendance,
                    "change_percentage": round(
                        ((today_attendance - yesterday_attendance) / yesterday_attendance * 100)
                        if yesterday_attendance > 0 else 0, 1
                    )
                },
                "trends": {
                    "daily": daily_trend,
                    "hourly": hourly_data
                },
                "top_employees": top_employees,
                "total_employees": total_employees
            }
        }

    except Exception as e:
        print(f"❌ Analytics error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/attendance-trends")
async def get_attendance_trends(
    days: int = 30,
    db: Session = Depends(get_db)
):
    """
    Get attendance trends over specified days

    Args:
        days: Number of days to analyze (default: 30)

    Returns: Daily attendance data with status breakdown
    """
    try:
        from datetime import timedelta

        print(f"\n📈 Generating {days}-day attendance trends...")

        today = get_ph_time().date()
        start_date = today - timedelta(days=days)

        trends = []
        for i in range(days, -1, -1):
            day = today - timedelta(days=i)
            day_start = datetime.combine(day, datetime.min.time())
            day_end = datetime.combine(day, datetime.max.time())

            logs = db.query(AttendanceLog).filter(
                AttendanceLog.timestamp >= day_start,
                AttendanceLog.timestamp <= day_end
            ).all()

            status_breakdown = {
                'on_time': sum(1 for log in logs if (log.status or 'on_time') == 'on_time'),
                'late': sum(1 for log in logs if (log.status or 'on_time') == 'late'),
                'half_day': sum(1 for log in logs if (log.status or 'on_time') == 'half_day')
            }

            unique_employees = len(set([log.employee_id for log in logs]))

            trends.append({
                'date': day.strftime('%Y-%m-%d'),
                'day_name': day.strftime('%a'),
                'total': len(logs),
                'unique_employees': unique_employees,
                'on_time': status_breakdown['on_time'],
                'late': status_breakdown['late'],
                'half_day': status_breakdown['half_day']
            })

        return {
            "success": True,
            "days": days,
            "trends": trends
        }

    except Exception as e:
        print(f"❌ Trends error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/department-stats")
async def get_department_statistics(db: Session = Depends(get_db)):
    """
    Get attendance statistics by department

    Returns: Department-wise attendance rates and counts
    """
    try:
        from datetime import timedelta

        print("\n🏢 Generating department statistics...")

        today = get_ph_time().date()
        today_start = datetime.combine(today, datetime.min.time())
        today_end = datetime.combine(today, datetime.max.time())

        # Get all departments
        employees = db.query(Employee).filter(Employee.is_active == True).all()
        departments = {}

        for emp in employees:
            dept = emp.department or 'Unknown'
            if dept not in departments:
                departments[dept] = {
                    'total_employees': 0,
                    'present_today': set(),
                    'total_check_ins': 0
                }
            departments[dept]['total_employees'] += 1

        # Get today's attendance
        today_logs = db.query(AttendanceLog).filter(
            AttendanceLog.timestamp >= today_start,
            AttendanceLog.timestamp <= today_end
        ).all()

        for log in today_logs:
            emp = db.query(Employee).filter(Employee.employee_id == log.employee_id).first()
            if emp:
                dept = emp.department or 'Unknown'
                if dept in departments:
                    departments[dept]['present_today'].add(log.employee_id)
                    departments[dept]['total_check_ins'] += 1

        # Calculate statistics
        dept_stats = []
        for dept_name, data in departments.items():
            present_count = len(data['present_today'])
            attendance_rate = (present_count / data['total_employees'] * 100) if data['total_employees'] > 0 else 0

            dept_stats.append({
                'department': dept_name,
                'total_employees': data['total_employees'],
                'present_today': present_count,
                'total_check_ins': data['total_check_ins'],
                'attendance_rate': round(attendance_rate, 1)
            })

        # Sort by attendance rate
        dept_stats.sort(key=lambda x: x['attendance_rate'], reverse=True)

        return {
            "success": True,
            "departments": dept_stats
        }

    except Exception as e:
        print(f"❌ Department stats error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/employee-performance")
async def get_employee_performance(
    days: int = 30,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """
    Get employee attendance performance metrics

    Args:
        days: Number of days to analyze
        limit: Number of top employees to return

    Returns: Employee performance rankings
    """
    try:
        from datetime import timedelta
        from sqlalchemy import func

        print(f"\n🏆 Generating employee performance (last {days} days)...")

        today = get_ph_time().date()
        start_date = today - timedelta(days=days)
        start_datetime = datetime.combine(start_date, datetime.min.time())

        # Get attendance counts per employee
        attendance_counts = db.query(
            AttendanceLog.employee_id,
            func.count(AttendanceLog.id).label('total_check_ins'),
            func.count(func.distinct(func.date(AttendanceLog.timestamp))).label('days_present')
        ).filter(
            AttendanceLog.timestamp >= start_datetime
        ).group_by(AttendanceLog.employee_id).all()

        performance = []
        for emp_id, total_check_ins, days_present in attendance_counts:
            emp = db.query(Employee).filter(Employee.employee_id == emp_id).first()
            if emp:
                # Get status breakdown
                logs = db.query(AttendanceLog).filter(
                    AttendanceLog.employee_id == emp_id,
                    AttendanceLog.timestamp >= start_datetime
                ).all()

                on_time = sum(1 for log in logs if (log.status or 'on_time') == 'on_time')
                late = sum(1 for log in logs if (log.status or 'on_time') == 'late')

                performance.append({
                    'employee_id': emp_id,
                    'name': emp.name,
                    'department': emp.department,
                    'total_check_ins': total_check_ins,
                    'days_present': days_present,
                    'on_time_count': on_time,
                    'late_count': late,
                    'punctuality_rate': round((on_time / total_check_ins * 100) if total_check_ins > 0 else 0, 1)
                })

        # Sort by days present and punctuality
        performance.sort(key=lambda x: (x['days_present'], x['punctuality_rate']), reverse=True)

        return {
            "success": True,
            "period_days": days,
            "top_performers": performance[:limit],
            "all_employees": performance
        }

    except Exception as e:
        print(f"❌ Performance error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ===================================
# LOCATION MANAGEMENT (GEOFENCING)
# ===================================

@app.get("/api/locations")
async def get_locations(
    include_inactive: bool = False,
    db: Session = Depends(get_db)
):
    """
    Get all locations

    Args:
        include_inactive: Include inactive locations (default: False)

    Returns: List of locations with GPS coordinates
    """
    try:
        print(f"\n📍 Fetching locations (include_inactive={include_inactive})...")

        query = db.query(Location)
        if not include_inactive:
            query = query.filter(Location.is_active == True)

        locations = query.all()

        result = [{
            "id": loc.id,
            "name": loc.name,
            "address": loc.address,
            "latitude": loc.latitude,
            "longitude": loc.longitude,
            "radius_meters": loc.radius_meters,
            "is_active": loc.is_active,
            "created_at": loc.created_at.isoformat() if loc.created_at else None
        } for loc in locations]

        print(f"✅ Found {len(result)} location(s)")
        return {
            "success": True,
            "count": len(result),
            "locations": result
        }

    except Exception as e:
        print(f"❌ Error fetching locations: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/locations")
async def create_location(
    name: str,
    latitude: float,
    longitude: float,
    radius_meters: float = 100.0,
    address: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new allowed location (Admin only)

    Args:
        name: Location name (e.g., "Main Office")
        latitude: GPS latitude
        longitude: GPS longitude
        radius_meters: Allowed radius in meters (default: 100m)
        address: Optional address

    Returns: Created location
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        print(f"\n📍 Creating new location: {name}")

        # Validate coordinates
        if not GeoService.validate_coordinates(latitude, longitude):
            raise HTTPException(status_code=400, detail="Invalid GPS coordinates")

        # Create location
        new_location = Location(
            id=str(uuid.uuid4()),
            name=name,
            address=address,
            latitude=latitude,
            longitude=longitude,
            radius_meters=radius_meters,
            created_by=current_user.id,
            is_active=True
        )

        db.add(new_location)
        db.commit()
        db.refresh(new_location)

        print(f"✅ Location created: {new_location.name} at ({latitude}, {longitude})")

        return {
            "success": True,
            "message": "Location created successfully",
            "location": {
                "id": new_location.id,
                "name": new_location.name,
                "address": new_location.address,
                "latitude": new_location.latitude,
                "longitude": new_location.longitude,
                "radius_meters": new_location.radius_meters,
                "is_active": new_location.is_active
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error creating location: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/api/locations/{location_id}")
async def update_location(
    location_id: str,
    name: Optional[str] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_meters: Optional[float] = None,
    address: Optional[str] = None,
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a location (Admin only)

    Returns: Updated location
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        print(f"\n📍 Updating location: {location_id}")

        location = db.query(Location).filter(Location.id == location_id).first()
        if not location:
            raise HTTPException(status_code=404, detail="Location not found")

        # Update fields
        if name is not None:
            location.name = name
        if address is not None:
            location.address = address
        if latitude is not None:
            if not GeoService.validate_coordinates(latitude, location.longitude):
                raise HTTPException(status_code=400, detail="Invalid latitude")
            location.latitude = latitude
        if longitude is not None:
            if not GeoService.validate_coordinates(location.latitude, longitude):
                raise HTTPException(status_code=400, detail="Invalid longitude")
            location.longitude = longitude
        if radius_meters is not None:
            if radius_meters < 0:
                raise HTTPException(status_code=400, detail="Radius must be positive")
            location.radius_meters = radius_meters
        if is_active is not None:
            location.is_active = is_active

        db.commit()
        db.refresh(location)

        print(f"✅ Location updated: {location.name}")

        return {
            "success": True,
            "message": "Location updated successfully",
            "location": {
                "id": location.id,
                "name": location.name,
                "address": location.address,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "radius_meters": location.radius_meters,
                "is_active": location.is_active
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error updating location: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/locations/{location_id}")
async def delete_location(
    location_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a location (Admin only)

    Returns: Success message
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        print(f"\n📍 Deleting location: {location_id}")

        location = db.query(Location).filter(Location.id == location_id).first()
        if not location:
            raise HTTPException(status_code=404, detail="Location not found")

        location_name = location.name
        db.delete(location)
        db.commit()

        print(f"✅ Location deleted: {location_name}")

        return {
            "success": True,
            "message": f"Location '{location_name}' deleted successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error deleting location: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


# ===================================
# NOTIFICATION MANAGEMENT
# ===================================

@app.get("/api/notifications/status")
async def get_notification_status(current_user: User = Depends(get_current_user)):
    """
    Get notification system status and settings (Admin only)

    Returns: Current notification configuration
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        return {
            "success": True,
            "email_enabled": NotificationService.is_enabled(),
            "settings": {
                "smtp_host": settings.SMTP_HOST,
                "smtp_port": settings.SMTP_PORT,
                "smtp_username": settings.SMTP_USERNAME[:3] + "***" if settings.SMTP_USERNAME else "",
                "from_email": settings.SMTP_FROM_EMAIL,
                "from_name": settings.SMTP_FROM_NAME,
                "notify_on_late": settings.NOTIFY_ON_LATE,
                "notify_on_absent": settings.NOTIFY_ON_ABSENT,
                "daily_summary_enabled": settings.DAILY_SUMMARY_ENABLED,
                "daily_summary_time": settings.DAILY_SUMMARY_TIME,
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error getting notification status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/notifications/test")
async def send_test_email(
    test_email: str,
    current_user: User = Depends(get_current_user)
):
    """
    Send a test email notification (Admin only)

    Args:
        test_email: Email address to send test to

    Returns: Success status
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        if not NotificationService.is_enabled():
            raise HTTPException(
                status_code=400,
                detail="Email notifications are not enabled. Please configure SMTP settings."
            )

        # Send test email
        success = NotificationService.send_check_in_confirmation(
            employee_name="Test User",
            employee_email=test_email,
            check_in_time=get_ph_time(),
            status="on_time",
            method="manual"
        )

        if success:
            return {
                "success": True,
                "message": f"Test email sent successfully to {test_email}"
            }
        else:
            raise HTTPException(
                status_code=500,
                detail="Failed to send test email. Check SMTP configuration."
            )

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error sending test email: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/notifications/daily-summary")
async def send_daily_summary_now(
    admin_email: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Manually trigger daily summary email (Admin only)

    Args:
        admin_email: Email to send to (defaults to current user's email)

    Returns: Success status
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        if not NotificationService.is_enabled():
            raise HTTPException(
                status_code=400,
                detail="Email notifications are not enabled"
            )

        # Use current user's email if not provided
        recipient_email = admin_email or current_user.email
        if not recipient_email:
            raise HTTPException(status_code=400, detail="No email address provided")

        # Get today's statistics
        today = get_ph_time().date()
        start_of_day = datetime.combine(today, datetime.min.time())

        # Get total employees
        total_employees = db.query(Employee).filter(Employee.is_active == True).count()

        # Get today's attendance
        today_logs = db.query(AttendanceLog).filter(
            AttendanceLog.timestamp >= start_of_day
        ).all()

        # Calculate statistics
        employee_ids_present = set(log.employee_id for log in today_logs)
        present_count = len(employee_ids_present)
        late_count = sum(1 for log in today_logs if log.status == "late")
        absent_count = total_employees - present_count

        # Get late employees with details
        late_employees = []
        for log in today_logs:
            if log.status == "late" and log.notes:
                import re
                match = re.search(r'(\d+) minutes', log.notes)
                minutes_late = int(match.group(1)) if match else 0

                emp = db.query(Employee).filter(Employee.employee_id == log.employee_id).first()
                if emp:
                    late_employees.append({
                        'name': emp.name,
                        'time': log.timestamp.strftime('%I:%M %p'),
                        'minutes_late': minutes_late
                    })

        # Send summary
        success = NotificationService.send_daily_summary(
            admin_email=recipient_email,
            date=get_ph_time(),
            total_employees=total_employees,
            present_count=present_count,
            late_count=late_count,
            absent_count=absent_count,
            late_employees=late_employees
        )

        if success:
            return {
                "success": True,
                "message": f"Daily summary sent to {recipient_email}",
                "stats": {
                    "total_employees": total_employees,
                    "present": present_count,
                    "late": late_count,
                    "absent": absent_count
                }
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to send summary email")

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error sending daily summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ===========================
# INVITATION ENDPOINTS
# ===========================

class InvitationRequest(BaseModel):
    email: str
    event_id: Optional[str] = None  # Optional event ID if invitation is for an event

@app.post("/api/invitations/send")
async def send_invitation(
    request: InvitationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Send registration invitation to email address (Admin only)

    Args:
        request: Invitation request with email

    Returns: Success status and invitation details
    """
    try:
        # Check admin permission
        if not AuthService.check_permission(current_user.role, "admin"):
            raise HTTPException(status_code=403, detail="Admin access required")

        # Validate email format
        email = request.email.strip().lower()
        if not email or '@' not in email:
            raise HTTPException(status_code=400, detail="Invalid email address")

        # Check if email already has an active invitation
        existing_invitation = db.query(Invitation).filter(
            Invitation.email == email,
            Invitation.is_used == False,
            Invitation.expires_at > get_ph_time()
        ).first()

        if existing_invitation:
            raise HTTPException(
                status_code=400,
                detail="An active invitation already exists for this email"
            )

        # Check if employee with this email already exists
        existing_employee = db.query(Employee).filter(Employee.email == email).first()
        if existing_employee:
            raise HTTPException(
                status_code=400,
                detail="An employee with this email already exists"
            )

        # If event_id is provided, validate it exists
        event = None
        if request.event_id:
            event = db.query(Event).filter(Event.id == request.event_id).first()
            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

        # Generate unique token
        token = secrets.token_urlsafe(32)

        # Create invitation (expires in 7 days)
        invitation = Invitation(
            id=str(uuid.uuid4()),
            email=email,
            token=token,
            expires_at=get_ph_time() + timedelta(days=7),
            is_used=False,
            created_by=current_user.id,
            event_id=request.event_id  # Link to event if provided
        )

        db.add(invitation)
        db.commit()

        # Send invitation email
        email_sent = False
        frontend_url = settings.FRONTEND_URL if hasattr(settings, 'FRONTEND_URL') else "http://localhost"

        if event:
            # Use new email service for event invitations with better templates
            email_sent = email_service.send_event_invitation(
                to_email=email,
                event_name=event.name,
                event_date=event.event_date,
                event_location=event.location or "To be announced",
                invitation_token=token,
                base_url=frontend_url
            )
        elif NotificationService.is_enabled():
            # Use notification service for general invitations
            email_sent = NotificationService.send_registration_invitation(
                recipient_email=email,
                invitation_token=token,
                frontend_url=frontend_url,
                event=None
            )

        if not email_sent:
            print(f"⚠️ Warning: Failed to send invitation email to {email}")

        return {
            "success": True,
            "message": f"Invitation sent to {email}",
            "invitation": {
                "id": invitation.id,
                "email": email,
                "token": token,
                "expires_at": invitation.expires_at.isoformat(),
                "registration_link": f"{settings.FRONTEND_URL if hasattr(settings, 'FRONTEND_URL') else 'http://localhost'}/#/register?token={token}"
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error sending invitation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/invitations/validate/{token}")
async def validate_invitation(
    token: str,
    db: Session = Depends(get_db)
):
    """
    Validate invitation token

    Args:
        token: Invitation token to validate

    Returns: Validation status and email if valid
    """
    try:
        # Find invitation by token
        invitation = db.query(Invitation).filter(Invitation.token == token).first()

        if not invitation:
            return {
                "valid": False,
                "message": "Invalid invitation token"
            }

        # Check if already used
        if invitation.is_used:
            return {
                "valid": False,
                "message": "This invitation has already been used"
            }

        # Check if expired
        if invitation.expires_at < get_ph_time():
            return {
                "valid": False,
                "message": "This invitation has expired"
            }

        # Get event details if invitation is linked to an event
        event_info = None
        if invitation.event_id:
            event = db.query(Event).filter(Event.id == invitation.event_id).first()
            if event:
                event_info = {
                    "id": event.id,
                    "name": event.name,
                    "description": event.description,
                    "start_date": event.start_date.isoformat() if event.start_date else None,
                    "end_date": event.end_date.isoformat() if event.end_date else None
                }

        # Valid invitation
        return {
            "valid": True,
            "email": invitation.email,
            "event": event_info,
            "message": "Invitation is valid"
        }

    except Exception as e:
        print(f"❌ Error validating invitation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/invitations/mark-used/{token}")
async def mark_invitation_used(
    token: str,
    employee_id: str,
    db: Session = Depends(get_db)
):
    """
    Mark invitation as used after successful registration

    Args:
        token: Invitation token
        employee_id: Created employee ID

    Returns: Success status
    """
    try:
        invitation = db.query(Invitation).filter(Invitation.token == token).first()

        if not invitation:
            raise HTTPException(status_code=404, detail="Invitation not found")

        invitation.is_used = True
        invitation.used_at = get_ph_time()
        invitation.employee_id = employee_id

        # If invitation was for an event, automatically add employee as participant
        if invitation.event_id:
            # Check if participant already exists
            existing_participant = db.query(EventParticipant).filter(
                EventParticipant.event_id == invitation.event_id,
                EventParticipant.employee_id == employee_id
            ).first()

            if not existing_participant:
                participant = EventParticipant(
                    id=str(uuid.uuid4()),
                    event_id=invitation.event_id,
                    employee_id=employee_id,
                    status="registered",  # Automatically set to registered since they completed registration
                    created_at=get_ph_time()
                )
                db.add(participant)
                print(f"✅ Auto-added employee {employee_id} to event {invitation.event_id}")

        db.commit()

        return {
            "success": True,
            "message": "Invitation marked as used",
            "auto_added_to_event": bool(invitation.event_id)
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error marking invitation as used: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==========================================
# CAMERA MANAGEMENT ENDPOINTS
# ==========================================

class CameraCreate(BaseModel):
    name: str
    camera_type: str  # 'rtsp', 'http', 'webcam'
    stream_url: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    location: Optional[str] = None

class CameraUpdate(BaseModel):
    name: Optional[str] = None
    camera_type: Optional[str] = None
    stream_url: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    location: Optional[str] = None
    is_active: Optional[bool] = None
    status: Optional[str] = None

class EventCameraLink(BaseModel):
    camera_id: str
    is_primary: Optional[bool] = False

@app.post("/api/cameras")
async def create_camera(
    request: CameraCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new camera with auto-configuration for Dahua cameras"""
    try:
        import re
        import urllib.parse

        # Validate camera type
        if request.camera_type not in ['rtsp', 'http', 'webcam']:
            raise HTTPException(
                status_code=400,
                detail="Camera type must be 'rtsp', 'http', or 'webcam'"
            )

        stream_url = request.stream_url

        # AUTO-CONFIGURE DAHUA CAMERAS
        if request.camera_type == 'rtsp':
            # Check if stream_url is just an IP address
            ip_pattern = r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'

            if stream_url and re.match(ip_pattern, stream_url):
                # Just an IP - build Dahua RTSP URL automatically
                username = request.username or "admin"
                password = request.password or "admin"

                # URL-encode password if it contains special characters
                password_encoded = urllib.parse.quote(password)

                # Build standard Dahua RTSP URL
                stream_url = f"rtsp://{username}:{password_encoded}@{stream_url}:554/cam/realmonitor?channel=1&subtype=0"

                print(f"🔧 Auto-configured Dahua camera URL for IP: {request.stream_url}")

                # Clear username/password since they're in URL
                request.username = None
                request.password = None

            elif stream_url and not stream_url.startswith('rtsp://'):
                # User provided partial URL, try to fix it
                if request.username and request.password:
                    password_encoded = urllib.parse.quote(request.password)
                    stream_url = f"rtsp://{request.username}:{password_encoded}@{stream_url}"
                    request.username = None
                    request.password = None

        # For RTSP/HTTP cameras, stream_url is required
        if request.camera_type in ['rtsp', 'http'] and not stream_url:
            raise HTTPException(
                status_code=400,
                detail=f"stream_url is required for {request.camera_type} cameras"
            )

        # Create camera
        camera = Camera(
            id=str(uuid.uuid4()),
            name=request.name,
            camera_type=request.camera_type,
            stream_url=stream_url,
            username=request.username,
            password=request.password,
            location=request.location,
            is_active=True,
            status='offline',
            created_at=get_ph_time(),
            updated_at=get_ph_time(),
            created_by=current_user.id
        )

        db.add(camera)
        db.commit()
        db.refresh(camera)

        print(f"✅ Camera created: {camera.name} ({camera.camera_type})")
        print(f"   Stream URL: {stream_url}")

        return {
            "success": True,
            "message": "Camera created successfully",
            "camera": {
                "id": camera.id,
                "name": camera.name,
                "camera_type": camera.camera_type,
                "stream_url": camera.stream_url,
                "location": camera.location,
                "is_active": camera.is_active,
                "status": camera.status,
                "created_at": camera.created_at.isoformat() if camera.created_at else None
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating camera: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/cameras")
async def get_cameras(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all cameras"""
    try:
        cameras = db.query(Camera).filter(Camera.is_active == True).all()

        return {
            "success": True,
            "cameras": [
                {
                    "id": camera.id,
                    "name": camera.name,
                    "camera_type": camera.camera_type,
                    "stream_url": camera.stream_url,
                    "location": camera.location,
                    "is_active": camera.is_active,
                    "status": camera.status,
                    "last_seen": camera.last_seen.isoformat() if camera.last_seen else None,
                    "created_at": camera.created_at.isoformat() if camera.created_at else None
                }
                for camera in cameras
            ]
        }

    except Exception as e:
        print(f"❌ Error fetching cameras: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/cameras/{camera_id}")
async def get_camera(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get camera details"""
    try:
        camera = db.query(Camera).filter(Camera.id == camera_id).first()

        if not camera:
            raise HTTPException(status_code=404, detail="Camera not found")

        # Get linked events
        event_links = db.query(EventCamera).filter(
            EventCamera.camera_id == camera_id
        ).all()

        linked_events = []
        for link in event_links:
            event = db.query(Event).filter(Event.id == link.event_id).first()
            if event:
                linked_events.append({
                    "id": event.id,
                    "name": event.name,
                    "event_date": event.event_date.isoformat() if event.event_date else None,
                    "is_primary": link.is_primary
                })

        return {
            "success": True,
            "camera": {
                "id": camera.id,
                "name": camera.name,
                "camera_type": camera.camera_type,
                "stream_url": camera.stream_url,
                "username": camera.username,
                "location": camera.location,
                "is_active": camera.is_active,
                "status": camera.status,
                "last_seen": camera.last_seen.isoformat() if camera.last_seen else None,
                "created_at": camera.created_at.isoformat() if camera.created_at else None,
                "linked_events": linked_events
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching camera: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/cameras/{camera_id}")
async def update_camera(
    camera_id: str,
    request: CameraUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update camera details"""
    try:
        camera = db.query(Camera).filter(Camera.id == camera_id).first()

        if not camera:
            raise HTTPException(status_code=404, detail="Camera not found")

        # Update fields if provided
        if request.name is not None:
            camera.name = request.name
        if request.camera_type is not None:
            camera.camera_type = request.camera_type
        if request.stream_url is not None:
            camera.stream_url = request.stream_url
        if request.username is not None:
            camera.username = request.username
        if request.password is not None:
            camera.password = request.password
        if request.location is not None:
            camera.location = request.location
        if request.is_active is not None:
            camera.is_active = request.is_active
        if request.status is not None:
            camera.status = request.status

        camera.updated_at = get_ph_time()

        db.commit()
        db.refresh(camera)

        print(f"✅ Camera updated: {camera.name}")

        return {
            "success": True,
            "message": "Camera updated successfully",
            "camera": {
                "id": camera.id,
                "name": camera.name,
                "camera_type": camera.camera_type,
                "stream_url": camera.stream_url,
                "location": camera.location,
                "is_active": camera.is_active,
                "status": camera.status
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating camera: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/cameras/{camera_id}")
async def delete_camera(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete camera (soft delete)"""
    try:
        camera = db.query(Camera).filter(Camera.id == camera_id).first()

        if not camera:
            raise HTTPException(status_code=404, detail="Camera not found")

        # Soft delete
        camera.is_active = False
        camera.updated_at = get_ph_time()

        db.commit()

        print(f"✅ Camera deleted: {camera.name}")

        return {
            "success": True,
            "message": "Camera deleted successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting camera: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/cameras/{camera_id}/test")
async def test_camera_connection(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Test camera connection (placeholder - will be implemented with actual streaming)"""
    try:
        camera = db.query(Camera).filter(Camera.id == camera_id).first()

        if not camera:
            raise HTTPException(status_code=404, detail="Camera not found")

        # For now, just return success
        # In Option 2, this will actually test the stream
        return {
            "success": True,
            "message": "Camera connection test endpoint ready (full implementation in Option 2)",
            "camera_id": camera.id,
            "camera_type": camera.camera_type
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error testing camera: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# EVENT-CAMERA LINKING ENDPOINTS
# ==========================================

@app.post("/events/{event_id}/cameras")
async def link_camera_to_event(
    event_id: str,
    request: EventCameraLink,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Link a camera to an event"""
    try:
        # Validate event exists
        event = db.query(Event).filter(Event.id == event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Validate camera exists
        camera = db.query(Camera).filter(Camera.id == request.camera_id).first()
        if not camera:
            raise HTTPException(status_code=404, detail="Camera not found")

        # Check if already linked
        existing_link = db.query(EventCamera).filter(
            EventCamera.event_id == event_id,
            EventCamera.camera_id == request.camera_id
        ).first()

        if existing_link:
            raise HTTPException(
                status_code=400,
                detail="Camera is already linked to this event"
            )

        # If setting as primary, unset other primary cameras for this event
        if request.is_primary:
            db.query(EventCamera).filter(
                EventCamera.event_id == event_id,
                EventCamera.is_primary == True
            ).update({"is_primary": False})

        # Create link
        link = EventCamera(
            id=str(uuid.uuid4()),
            event_id=event_id,
            camera_id=request.camera_id,
            is_primary=request.is_primary,
            created_at=get_ph_time(),
            created_by=current_user.id
        )

        db.add(link)
        db.commit()

        print(f"✅ Camera '{camera.name}' linked to event '{event.name}'")

        return {
            "success": True,
            "message": "Camera linked to event successfully",
            "link": {
                "id": link.id,
                "event_id": event_id,
                "camera_id": request.camera_id,
                "is_primary": link.is_primary
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error linking camera to event: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/events/{event_id}/cameras")
async def get_event_cameras(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all cameras linked to an event"""
    try:
        # Validate event exists
        event = db.query(Event).filter(Event.id == event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")

        # Get camera links
        links = db.query(EventCamera).filter(
            EventCamera.event_id == event_id
        ).all()

        cameras = []
        for link in links:
            camera = db.query(Camera).filter(Camera.id == link.camera_id).first()
            if camera:
                cameras.append({
                    "id": camera.id,
                    "name": camera.name,
                    "camera_type": camera.camera_type,
                    "stream_url": camera.stream_url,
                    "location": camera.location,
                    "is_active": camera.is_active,
                    "status": camera.status,
                    "is_primary": link.is_primary,
                    "linked_at": link.created_at.isoformat() if link.created_at else None
                })

        return {
            "success": True,
            "event_id": event_id,
            "event_name": event.name,
            "cameras": cameras
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching event cameras: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/events/{event_id}/cameras/{camera_id}")
async def unlink_camera_from_event(
    event_id: str,
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Unlink a camera from an event"""
    try:
        link = db.query(EventCamera).filter(
            EventCamera.event_id == event_id,
            EventCamera.camera_id == camera_id
        ).first()

        if not link:
            raise HTTPException(
                status_code=404,
                detail="Camera link not found for this event"
            )

        db.delete(link)
        db.commit()

        print(f"✅ Camera unlinked from event")

        return {
            "success": True,
            "message": "Camera unlinked from event successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error unlinking camera from event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
# ========================================
# CAMERA STREAMING ENDPOINTS
# ========================================

def generate_frames(camera_id: str, with_recognition: bool = False):
    """Generator function for video streaming"""
    stream = stream_manager.get_stream(camera_id)
    if not stream:
        yield b''
        return

    # Load all employee faces if recognition is enabled
    known_faces = {}
    if with_recognition:
        db = next(get_db())
        try:
            employees = db.query(Employee).filter(Employee.is_active == True).all()
            for emp in employees:
                if emp.embeddings and len(emp.embeddings) > 0:
                    # Use the first embedding
                    known_faces[emp.name] = np.array(emp.embeddings[0])
        finally:
            db.close()

    while True:
        try:
            if with_recognition and known_faces:
                frame_bytes = stream.get_frame_with_faces(known_faces)
            else:
                frame_bytes = stream.get_jpeg_frame(quality=85)

            if frame_bytes is None:
                # Stream ended or no frame available
                break

            # Yield frame in multipart format
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        except Exception as e:
            print(f"Error generating frame: {e}")
            break


@app.get("/api/cameras/{camera_id}/stream")
async def stream_camera(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_token_or_query)
):
    """Stream live video from a camera (no face recognition, supports token via query param)"""
    # Verify camera exists
    camera = db.query(Camera).filter(
        Camera.id == camera_id,
        Camera.is_active == True
    ).first()

    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    return StreamingResponse(
        generate_frames(camera_id, with_recognition=False),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


@app.get("/api/cameras/{camera_id}/stream/recognition")
async def stream_camera_with_recognition(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_token_or_query)
):
    """Stream live video from a camera with face recognition overlay (supports token via query param)"""
    # Verify camera exists
    camera = db.query(Camera).filter(
        Camera.id == camera_id,
        Camera.is_active == True
    ).first()

    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    return StreamingResponse(
        generate_frames(camera_id, with_recognition=True),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


@app.get("/api/cameras/{camera_id}/snapshot")
async def get_camera_snapshot(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a single frame snapshot from the camera"""
    # Verify camera exists
    camera = db.query(Camera).filter(
        Camera.id == camera_id,
        Camera.is_active == True
    ).first()

    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    stream = stream_manager.get_stream(camera_id)
    if not stream:
        raise HTTPException(status_code=500, detail="Failed to start camera stream")

    frame_bytes = stream.get_jpeg_frame(quality=95)
    if frame_bytes is None:
        raise HTTPException(status_code=500, detail="Failed to capture frame")

    return StreamingResponse(
        io.BytesIO(frame_bytes),
        media_type="image/jpeg"
    )


@app.post("/api/cameras/{camera_id}/stop-stream")
async def stop_camera_stream(
    camera_id: str,
    current_user: User = Depends(get_current_user)
):
    """Stop a camera stream to free resources"""
    stream_manager.stop_stream(camera_id)
    return {"success": True, "message": "Camera stream stopped"}


# Camera Monitoring Endpoints (Auto Attendance Logging)

@app.post("/api/cameras/{camera_id}/start-monitoring")
async def start_camera_monitoring(
    camera_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Start automatic face detection monitoring and attendance logging for a camera"""
    # Get camera from database
    camera = db.query(Camera).filter(Camera.id == camera_id).first()
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    # Start monitoring
    success = monitoring_service.start_camera_monitoring(camera)

    if success:
        return {
            "success": True,
            "message": f"Camera monitoring started for {camera.name}",
            "camera_id": camera_id
        }
    else:
        raise HTTPException(
            status_code=500,
            detail="Failed to start camera monitoring. Check camera connection and face analysis settings."
        )


@app.post("/api/cameras/{camera_id}/stop-monitoring")
async def stop_camera_monitoring(
    camera_id: str,
    current_user: User = Depends(get_current_user)
):
    """Stop automatic face detection monitoring for a camera"""
    monitoring_service.stop_camera_monitoring(camera_id)
    return {
        "success": True,
        "message": "Camera monitoring stopped",
        "camera_id": camera_id
    }


@app.get("/api/cameras/monitoring/status")
async def get_monitoring_status(
    current_user: User = Depends(get_current_user)
):
    """Get status of all camera monitoring"""
    status = monitoring_service.get_monitoring_status()
    return {
        "success": True,
        "monitoring_count": len(status),
        "cameras": status
    }


@app.post("/api/cameras/monitoring/reload-faces")
async def reload_monitoring_faces(
    current_user: User = Depends(get_current_user)
):
    """Reload face encodings for all monitored cameras (call after registering new employees)"""
    monitoring_service.reload_all_faces()
    return {
        "success": True,
        "message": "Face encodings reloaded for all monitored cameras"
    }


@app.get("/events/{event_id}/stream")
async def stream_event_cameras(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all camera streams for an event"""
    # Get cameras linked to this event
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    # Get linked cameras
    event_cameras = db.query(EventCamera).filter(
        EventCamera.event_id == event_id
    ).all()

    camera_ids = [ec.camera_id for ec in event_cameras]

    # Get camera details
    cameras = db.query(Camera).filter(
        Camera.id.in_(camera_ids),
        Camera.is_active == True
    ).all()

    camera_data = []
    for camera in cameras:
        event_camera = next((ec for ec in event_cameras if ec.camera_id == camera.id), None)
        camera_data.append({
            "id": camera.id,
            "name": camera.name,
            "location": camera.location,
            "is_primary": event_camera.is_primary if event_camera else False,
            "stream_url": f"/cameras/{camera.id}/stream/recognition",
            "snapshot_url": f"/cameras/{camera.id}/snapshot"
        })

    return {
        "success": True,
        "event_id": event_id,
        "event_name": event.name,
        "cameras": camera_data
    }


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
