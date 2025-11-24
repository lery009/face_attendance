"""
Database Configuration and Models
"""
from sqlalchemy import create_engine, Column, String, DateTime, JSON, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
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
