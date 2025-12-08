#!/usr/bin/env python3
"""
Simple email test to verify SMTP configuration
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_smtp_connection():
    print("=== Testing Gmail SMTP Connection ===\n")

    smtp_host = os.getenv('SMTP_HOST', 'smtp.gmail.com')
    smtp_port = int(os.getenv('SMTP_PORT', '587'))
    smtp_username = os.getenv('SMTP_USERNAME')
    smtp_password = os.getenv('SMTP_PASSWORD')
    smtp_from = os.getenv('SMTP_FROM_EMAIL')

    print(f"📧 SMTP Host: {smtp_host}")
    print(f"📧 SMTP Port: {smtp_port}")
    print(f"📧 SMTP Username: {smtp_username}")
    print(f"📧 SMTP From: {smtp_from}")
    print(f"📧 Password: {'*' * len(smtp_password) if smtp_password else 'NOT SET'}\n")

    if not smtp_username or not smtp_password:
        print("❌ Error: SMTP credentials not configured")
        return False

    try:
        print("🔄 Connecting to SMTP server...")
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.set_debuglevel(1)  # Show debug output

        print("\n🔄 Starting TLS...")
        server.starttls()

        print("\n🔄 Logging in...")
        server.login(smtp_username, smtp_password)

        print("\n✅ SMTP connection successful!")
        print("✅ Login successful!")

        # Send a test email
        print("\n🔄 Sending test email to yourself...")

        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'Test Email - Face Recognition System'
        msg['From'] = smtp_from
        msg['To'] = smtp_username

        text = "This is a test email from the Face Recognition Attendance System."
        html = f"""
        <html>
          <body>
            <h2>✅ Email Configuration Test</h2>
            <p>This is a test email from the Face Recognition Attendance System.</p>
            <p>If you received this, your email configuration is working correctly!</p>
          </body>
        </html>
        """

        part1 = MIMEText(text, 'plain')
        part2 = MIMEText(html, 'html')
        msg.attach(part1)
        msg.attach(part2)

        server.sendmail(smtp_from, [smtp_username], msg.as_string())

        print(f"\n✅ Test email sent successfully to {smtp_username}")
        print("   Check your inbox (and spam folder)")

        server.quit()
        return True

    except smtplib.SMTPAuthenticationError as e:
        print(f"\n❌ Authentication failed: {e}")
        print("   Please check your Gmail App Password")
        print("   Make sure 2-Step Verification is enabled on your Google account")
        return False
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_smtp_connection()
