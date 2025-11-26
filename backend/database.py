"""
Database Configuration and Models
"""
from sqlalchemy import create_engine, Column, String, DateTime, JSON, Boolean, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
from config import settings

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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)

class AttendanceLog(Base):
    __tablename__ = "attendance_logs"

    id = Column(String(255), primary_key=True, index=True)
    employee_id = Column(String(255), nullable=False, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    confidence = Column(String(50))
    method = Column(String(50), default="face_recognition")  # face_recognition, manual, etc.
    event_id = Column(String(255), nullable=True, index=True)  # Link to event if attendance is for an event

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
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)

class EventParticipant(Base):
    __tablename__ = "event_participants"

    id = Column(String(255), primary_key=True, index=True)
    event_id = Column(String(255), ForeignKey('events.id'), nullable=False, index=True)
    employee_id = Column(String(255), ForeignKey('employees.employee_id'), nullable=False, index=True)
    is_required = Column(Boolean, default=True)  # Is attendance mandatory?
    status = Column(String(50), default="invited")  # invited, confirmed, attended, absent
    attended_at = Column(DateTime, nullable=True)  # When they checked in
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

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
