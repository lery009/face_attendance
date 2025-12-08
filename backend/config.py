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

    # JWT Authentication
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-CHANGE-THIS-in-production-use-openssl-rand-hex-32")
    JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24 hours

    # Attendance Settings
    ATTENDANCE_COOLDOWN_MINUTES = int(os.getenv("ATTENDANCE_COOLDOWN_MINUTES", "5"))

    # Work Hours Settings (for Late/Absent tracking)
    WORK_START_TIME = os.getenv("WORK_START_TIME", "08:00")  # HH:MM format
    WORK_END_TIME = os.getenv("WORK_END_TIME", "17:00")  # HH:MM format
    LATE_GRACE_PERIOD_MINUTES = int(os.getenv("LATE_GRACE_PERIOD_MINUTES", "15"))  # 15 min grace
    HALF_DAY_CUTOFF_TIME = os.getenv("HALF_DAY_CUTOFF_TIME", "12:00")  # After this = half day

    # Timezone Settings
    TIMEZONE = os.getenv("TIMEZONE", "Asia/Manila")  # Philippines Standard Time (UTC+8)

    # Email Notification Settings
    EMAIL_ENABLED = os.getenv("EMAIL_ENABLED", "false").lower() == "true"
    SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", "noreply@attendance.com")
    SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "Attendance System")

    # Notification Settings
    NOTIFY_ON_LATE = os.getenv("NOTIFY_ON_LATE", "true").lower() == "true"
    NOTIFY_ON_ABSENT = os.getenv("NOTIFY_ON_ABSENT", "false").lower() == "true"
    DAILY_SUMMARY_ENABLED = os.getenv("DAILY_SUMMARY_ENABLED", "false").lower() == "true"
    DAILY_SUMMARY_TIME = os.getenv("DAILY_SUMMARY_TIME", "18:00")  # HH:MM format

settings = Settings()
