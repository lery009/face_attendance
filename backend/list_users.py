#!/usr/bin/env python3
"""
List Users in Database
Shows existing user accounts (without passwords)
"""
from database import get_db, User

def list_users():
    print("=== Existing User Accounts ===\n")

    db = next(get_db())

    try:
        users = db.query(User).all()

        if not users:
            print("No users found in database.")
            return

        print(f"Found {len(users)} user(s):\n")

        for user in users:
            print(f"Username: {user.username}")
            print(f"Email: {user.email}")
            print(f"Full Name: {user.full_name}")
            print(f"Role: {user.role}")
            print(f"Active: {user.is_active}")
            print("-" * 50)

    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    list_users()
