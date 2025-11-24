"""
Face Recognition Backend API
FastAPI application with face detection, recognition, and attendance tracking
"""
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
import uuid

from config import settings
from database import init_db, get_db, Employee, AttendanceLog
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
        "timestamp": datetime.utcnow().isoformat(),
        "liveness_enabled": settings.ENABLE_LIVENESS
    }

@app.post("/api/detect-recognize")
async def detect_and_recognize(
    request: DetectRecognizeRequest,
    db: Session = Depends(get_db)
):
    """
    Detect faces in image and recognize them

    Args:
        request: Contains base64 encoded image

    Returns:
        List of detected faces with recognition results
    """
    try:
        print("\n🔍 Processing detection request...")

        # Get all employees from database
        employees = db.query(Employee).filter(Employee.is_active == True).all()

        if not employees:
            print("⚠️ No employees in database")
            return {"faces": []}

        # Prepare employee embeddings
        employee_data = [
            (emp.employee_id, emp.name, emp.embeddings)
            for emp in employees
        ]

        # Process image
        results = face_processor.process_image_for_recognition(
            request.image,
            employee_data
        )

        # Mark attendance for recognized live faces
        for face in results:
            if face['name'] != 'Unknown' and face['isLive']:
                employee_id = face['employeeId']

                # Check if already marked attendance recently (cooldown)
                cooldown = timedelta(minutes=settings.ATTENDANCE_COOLDOWN_MINUTES)
                recent_attendance = db.query(AttendanceLog).filter(
                    AttendanceLog.employee_id == employee_id,
                    AttendanceLog.timestamp > datetime.utcnow() - cooldown
                ).first()

                if not recent_attendance:
                    # Mark new attendance
                    attendance = AttendanceLog(
                        id=str(uuid.uuid4()),
                        employee_id=employee_id,
                        confidence=f"{face['confidence']:.2f}",
                        method="face_recognition"
                    )
                    db.add(attendance)
                    db.commit()

                    print(f"✅ Attendance marked for: {face['name']} ({employee_id})")
                    face['attendanceMarked'] = True
                else:
                    print(f"ℹ️ Attendance already marked recently for: {face['name']}")
                    face['attendanceMarked'] = False

        print(f"✅ Processed {len(results)} face(s)")

        return {"faces": results}

    except Exception as e:
        print(f"❌ Error in detect-recognize: {e}")
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
