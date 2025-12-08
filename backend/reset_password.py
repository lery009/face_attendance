#!/usr/bin/env python3
"""
Reset User Password
Allows resetting password for any user
"""
from database import get_db, User
from auth_service import AuthService

def reset_password():
    print("=== Reset User Password ===\n")

    username = input("Enter username (default: admin): ").strip() or "admin"
    new_password = input("Enter new password (default: admin123): ").strip() or "admin123"

    db = next(get_db())

    try:
        # Find user
        user = db.query(User).filter(User.username == username).first()

        if not user:
            print(f"❌ User '{username}' not found")
            return

        # Update password
        user.hashed_password = AuthService.get_password_hash(new_password)
        db.commit()

        print(f"\n✅ Password reset successfully!")
        print(f"\nYou can now login with:")
        print(f"  Username: {username}")
        print(f"  Password: {new_password}")

    except Exception as e:
        db.rollback()
        print(f"❌ Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    reset_password()
