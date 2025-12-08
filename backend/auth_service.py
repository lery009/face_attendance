"""
Authentication Service
Handles password hashing, JWT token creation and verification
"""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from zoneinfo import ZoneInfo
from config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT Configuration
SECRET_KEY = settings.JWT_SECRET_KEY if hasattr(settings, 'JWT_SECRET_KEY') else "your-secret-key-change-this-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

class AuthService:
    """Authentication service for user management"""

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash"""
        return pwd_context.verify(plain_password, hashed_password)

    @staticmethod
    def get_password_hash(password: str) -> str:
        """Hash a password"""
        # Bcrypt has a 72-byte limit, truncate if necessary
        password_bytes = password.encode('utf-8')
        if len(password_bytes) > 72:
            password = password_bytes[:72].decode('utf-8', errors='ignore')
        return pwd_context.hash(password)

    @staticmethod
    def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token"""
        to_encode = data.copy()

        if expires_delta:
            expire = datetime.now(ZoneInfo(settings.TIMEZONE)) + expires_delta
        else:
            expire = datetime.now(ZoneInfo(settings.TIMEZONE)) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    @staticmethod
    def verify_token(token: str) -> Optional[dict]:
        """Verify JWT token and return payload"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except JWTError:
            return None

    @staticmethod
    def check_permission(user_role: str, required_role: str) -> bool:
        """
        Check if user role has required permission
        Role hierarchy: admin > manager > viewer
        """
        roles_hierarchy = {
            'admin': 3,
            'manager': 2,
            'viewer': 1
        }

        user_level = roles_hierarchy.get(user_role.lower(), 0)
        required_level = roles_hierarchy.get(required_role.lower(), 0)

        return user_level >= required_level
