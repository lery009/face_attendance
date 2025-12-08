"""
Quick test script to verify email invitation sending works
"""
import asyncio
from email_service import EmailService
from datetime import datetime

async def test_invitation_email():
    """Test sending an invitation email"""
    print("🧪 Testing Email Invitation Sending...")
    print("=" * 50)

    email_service = EmailService()

    # Print configuration
    print(f"SMTP Host: {email_service.smtp_host}")
    print(f"SMTP Port: {email_service.smtp_port}")
    print(f"SMTP User: {email_service.smtp_user}")
    print(f"From Email: {email_service.from_email}")
    print("=" * 50)

    # Test email
    test_email = input("\n📧 Enter email address to test: ").strip()

    if not test_email or '@' not in test_email:
        print("❌ Invalid email address")
        return

    print(f"\n📤 Sending test invitation to: {test_email}")

    # Send test invitation
    success = email_service.send_event_invitation(
        to_email=test_email,
        event_name="Test Event",
        event_date=datetime.now(),
        event_location="Test Location",
        invitation_token="test-token-12345",
        base_url="http://localhost:8080"
    )

    if success:
        print("\n✅ SUCCESS! Email sent successfully!")
        print(f"   Check {test_email} for the invitation")
    else:
        print("\n❌ FAILED! Email could not be sent")
        print("   Check the error messages above")

    print("\n" + "=" * 50)

if __name__ == "__main__":
    asyncio.run(test_invitation_email())
