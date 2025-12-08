"""
Database Configuration and Models
"""
from sqlalchemy import create_engine, Column, String, DateTime, JSON, Boolean, Text, ForeignKey, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
from zoneinfo import ZoneInfo
from config import settings

# Helper function to get current time in Philippines timezone
def get_ph_time():
    """Get current datetime in Philippines timezone (UTC+8)"""
    return datetime.now(ZoneInfo(settings.TIMEZONE))

# Create database engine
engine = create_engine(settings.DATABASE_URL, echo=True)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

# Database Models
class Employee(Base):
    __tablename__ = "employees"

    id = Column(String(255), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    firstname = Column(String(255), nullable=False)
    lastname = Column(String(255), nullable=False)
    employee_id = Column(String(255), unique=True, nullable=False, index=True)
    department = Column(String(255))
    email = Column(String(255))
    embeddings = Column(JSON, nullable=False)  # Store face embeddings as JSON array
    qr_code_token = Column(String(255), unique=True, nullable=True)  # Unique QR code token
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)
    is_active = Column(Boolean, default=True)

class AttendanceLog(Base):
    __tablename__ = "attendance_logs"

    id = Column(String(255), primary_key=True, index=True)
    employee_id = Column(String(255), nullable=False, index=True)
    timestamp = Column(DateTime, default=get_ph_time, index=True)
    confidence = Column(String(50))
    method = Column(String(50), default="face_recognition")  # face_recognition, manual, etc.
    event_id = Column(String(255), nullable=True, index=True)  # Link to event if attendance is for an event
    status = Column(String(50), default="on_time")  # on_time, late, half_day, early_departure
    notes = Column(Text, nullable=True)  # Optional notes (e.g., "Late by 25 minutes")
    camera_id = Column(String, nullable=True)  # Camera that captured the attendance

class Event(Base):
    __tablename__ = "events"

    id = Column(String(255), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    event_date = Column(DateTime, nullable=False, index=True)
    start_time = Column(String(50), nullable=True)  # HH:MM format
    end_time = Column(String(50), nullable=True)    # HH:MM format
    location = Column(String(255), nullable=True)
    status = Column(String(50), default="upcoming")  # upcoming, ongoing, completed, cancelled
    created_by = Column(String(255), nullable=True)  # Employee ID of creator
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)
    is_active = Column(Boolean, default=True)

class EventParticipant(Base):
    __tablename__ = "event_participants"

    id = Column(String(255), primary_key=True, index=True)
    event_id = Column(String(255), ForeignKey('events.id'), nullable=False, index=True)
    employee_id = Column(String(255), ForeignKey('employees.employee_id'), nullable=False, index=True)
    is_required = Column(Boolean, default=True)  # Is attendance mandatory?
    status = Column(String(50), default="invited")  # invited, confirmed, attended, absent
    attended_at = Column(DateTime, nullable=True)  # When they checked in
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)

class User(Base):
    __tablename__ = "users"

    id = Column(String(255), primary_key=True, index=True)
    username = Column(String(255), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    role = Column(String(50), default="viewer")  # admin, manager, viewer
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)
    last_login = Column(DateTime, nullable=True)

class Location(Base):
    __tablename__ = "locations"

    id = Column(String(255), primary_key=True, index=True)
    name = Column(String(255), nullable=False)  # e.g., "Main Office", "Branch 1"
    address = Column(Text, nullable=True)
    latitude = Column(Float, nullable=False)  # GPS latitude
    longitude = Column(Float, nullable=False)  # GPS longitude
    radius_meters = Column(Float, default=100.0)  # Allowed radius in meters (default 100m)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)
    created_by = Column(String(255), nullable=True)  # User ID who created this location

class Invitation(Base):
    __tablename__ = "invitations"

    id = Column(String(255), primary_key=True, index=True)
    email = Column(String(255), nullable=False, index=True)
    token = Column(String(255), unique=True, nullable=False, index=True)  # Unique invitation token
    expires_at = Column(DateTime, nullable=False, index=True)  # Token expiration time
    is_used = Column(Boolean, default=False)  # Whether invitation has been used
    used_at = Column(DateTime, nullable=True)  # When invitation was used
    created_by = Column(String(255), nullable=True)  # User ID who created this invitation
    created_at = Column(DateTime, default=get_ph_time)
    employee_id = Column(String(255), nullable=True)  # Employee ID created from this invitation
    event_id = Column(String(255), nullable=True, index=True)  # Event ID if invitation is for an event

class Camera(Base):
    __tablename__ = "cameras"

    id = Column(String(255), primary_key=True, index=True)
    name = Column(String(255), nullable=False)  # Camera name/label
    camera_type = Column(String(50), nullable=False)  # 'rtsp', 'http', 'webcam'
    stream_url = Column(String(500), nullable=True)  # RTSP/HTTP URL
    username = Column(String(255), nullable=True)  # Camera auth username
    password = Column(String(255), nullable=True)  # Camera auth password
    location = Column(String(255), nullable=True)  # Physical location
    is_active = Column(Boolean, default=True)  # Active status
    status = Column(String(50), default='offline')  # 'online', 'offline', 'error'
    last_seen = Column(DateTime, nullable=True)  # Last successful connection
    created_at = Column(DateTime, default=get_ph_time)
    updated_at = Column(DateTime, default=get_ph_time, onupdate=get_ph_time)
    created_by = Column(String(255), nullable=True)  # User ID who added camera

class EventCamera(Base):
    __tablename__ = "event_cameras"

    id = Column(String(255), primary_key=True, index=True)
    event_id = Column(String(255), nullable=False, index=True)  # Foreign key to events
    camera_id = Column(String(255), nullable=False, index=True)  # Foreign key to cameras
    is_primary = Column(Boolean, default=False)  # Primary camera for event
    created_at = Column(DateTime, default=get_ph_time)
    created_by = Column(String(255), nullable=True)

# Create all tables
def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully")

# Dependency to get DB session
def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
