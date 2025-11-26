"""
Configuration Settings for Face Recognition Backend
"""
import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    # API Settings
    API_HOST = os.getenv("API_HOST", "0.0.0.0")
    API_PORT = int(os.getenv("API_PORT", "3000"))

    # Database Settings
    DATABASE_URL = os.getenv(
        "DATABASE_URL",
        "postgresql://user:password@localhost:5432/face_recognition_db"
    )
    # For MySQL, use:
    # "mysql+pymysql://user:password@localhost:3306/face_recognition_db"

    # Face Recognition Settings
    FACE_RECOGNITION_TOLERANCE = float(os.getenv("FACE_TOLERANCE", "0.6"))  # Lower = stricter
    FACE_MATCH_THRESHOLD = float(os.getenv("FACE_MATCH_THRESHOLD", "0.6"))

    # Liveness Detection Settings
    ENABLE_LIVENESS = os.getenv("ENABLE_LIVENESS", "true").lower() == "true"
    LIVENESS_THRESHOLD = float(os.getenv("LIVENESS_THRESHOLD", "0.75"))  # Stricter threshold

    # Performance Settings
    FACE_DETECTION_MODEL = os.getenv("FACE_DETECTION_MODEL", "hog")  # "hog" or "cnn"
    MAX_FACES_PER_IMAGE = int(os.getenv("MAX_FACES_PER_IMAGE", "10"))

    # CORS Settings
    CORS_ORIGINS = [
        "http://localhost",
        "http://localhost:*",  # Allow all localhost ports
        "http://127.0.0.1",
        "http://127.0.0.1:*",  # Allow all 127.0.0.1 ports
        "http://localhost:3000",
        "http://localhost:8080",
        "http://10.22.0.231:3000",
        "*"  # Allow all for development (remove in production)
    ]

    # Security
    MAX_IMAGE_SIZE_MB = int(os.getenv("MAX_IMAGE_SIZE_MB", "10"))
    RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

    # Attendance Settings
    ATTENDANCE_COOLDOWN_MINUTES = int(os.getenv("ATTENDANCE_COOLDOWN_MINUTES", "5"))

settings = Settings()
