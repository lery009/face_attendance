#!/usr/bin/env python3
"""
Create First Admin Account
Quick script to create the first admin user for the system
"""
import requests
import json

def create_admin():
    print("=== Create First Admin Account ===\n")

    username = input("Enter admin username (default: admin): ").strip() or "admin"
    password = input("Enter admin password (default: admin123): ").strip() or "admin123"
    email = input("Enter admin email (default: admin@example.com): ").strip() or "admin@example.com"
    full_name = input("Enter full name (default: Administrator): ").strip() or "Administrator"

    print(f"\nCreating admin account...")
    print(f"Username: {username}")
    print(f"Email: {email}")
    print(f"Full Name: {full_name}\n")

    # Call the registration API
    url = "http://localhost:3000/api/auth/register"
    payload = {
        "username": username,
        "password": password,
        "email": email,
        "full_name": full_name
    }

    try:
        response = requests.post(url, json=payload)
        result = response.json()

        if response.status_code == 200 and result.get('success'):
            print("✅ Admin account created successfully!")
            print(f"\nYou can now login with:")
            print(f"  Username: {username}")
            print(f"  Password: {password}")
            return True
        else:
            print(f"❌ Failed to create admin account")
            print(f"Error: {result.get('detail') or result.get('message', 'Unknown error')}")
            return False

    except requests.exceptions.ConnectionError:
        print("❌ Error: Could not connect to backend server")
        print("Make sure the backend is running on http://localhost:3000")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    create_admin()
