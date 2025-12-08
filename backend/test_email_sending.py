#!/usr/bin/env python3
"""
Test email sending with SMTP configuration
"""
from notification_service import NotificationService
import sys

def test_email():
    print("=== Testing Email Configuration ===\n")

    # Test recipient
    test_email = "test@example.com"
    test_token = "test_token_12345"

    print(f"📧 Attempting to send test invitation to: {test_email}")
    print(f"🔗 Test token: {test_token}\n")

    try:
        success = NotificationService.send_registration_invitation(
            recipient_email=test_email,
            invitation_token=test_token,
            frontend_url="http://localhost"
        )

        if success:
            print("✅ Email sent successfully!")
            print("   Check your email inbox (and spam folder)")
            return True
        else:
            print("❌ Email sending failed")
            print("   Check the error messages above")
            return False

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("This will test email sending with your configured SMTP settings.\n")
    email = input("Enter a test email address (or press Enter to use 'test@example.com'): ").strip()

    if not email:
        email = "test@example.com"

    print()
    success = test_email()
    sys.exit(0 if success else 1)
