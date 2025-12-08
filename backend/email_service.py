"""
Email Service for sending invitations and notifications
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
from config import settings
from datetime import datetime

class EmailService:
    """Service for sending emails"""

    def __init__(self):
        self.smtp_host = getattr(settings, 'SMTP_HOST', 'smtp.gmail.com')
        self.smtp_port = getattr(settings, 'SMTP_PORT', 587)
        self.smtp_user = getattr(settings, 'SMTP_USERNAME', '')
        self.smtp_password = getattr(settings, 'SMTP_PASSWORD', '')
        self.from_email = getattr(settings, 'SMTP_FROM_EMAIL', self.smtp_user)
        self.from_name = getattr(settings, 'SMTP_FROM_NAME', 'Face Recognition System')

    def send_email(self, to_email: str, subject: str, html_body: str, text_body: Optional[str] = None) -> bool:
        """
        Send an email

        Args:
            to_email: Recipient email address
            subject: Email subject
            html_body: HTML body content
            text_body: Plain text body content (optional)

        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"{self.from_name} <{self.from_email}>"
            msg['To'] = to_email

            # Add text body if provided
            if text_body:
                part1 = MIMEText(text_body, 'plain')
                msg.attach(part1)

            # Add HTML body
            part2 = MIMEText(html_body, 'html')
            msg.attach(part2)

            # Send email
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                if self.smtp_user and self.smtp_password:
                    server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)

            print(f"✅ Email sent successfully to {to_email}")
            return True

        except Exception as e:
            print(f"❌ Failed to send email to {to_email}: {str(e)}")
            return False

    def send_event_invitation(
        self,
        to_email: str,
        event_name: str,
        event_date: datetime,
        event_location: str,
        invitation_token: str,
        base_url: str
    ) -> bool:
        """
        Send event invitation email

        Args:
            to_email: Recipient email address
            event_name: Name of the event
            event_date: Date and time of the event
            event_location: Event location
            invitation_token: Unique invitation token
            base_url: Base URL of the application

        Returns:
            bool: True if email sent successfully, False otherwise
        """
        registration_url = f"{base_url}/register?token={invitation_token}"

        subject = f"You're Invited: {event_name}"

        # Format date nicely
        formatted_date = event_date.strftime("%B %d, %Y at %I:%M %p")

        # HTML email template
        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                .header {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px;
                    text-align: center;
                    border-radius: 10px 10px 0 0;
                }}
                .content {{
                    background: #f9f9f9;
                    padding: 30px;
                    border-radius: 0 0 10px 10px;
                }}
                .event-details {{
                    background: white;
                    padding: 20px;
                    border-radius: 8px;
                    margin: 20px 0;
                }}
                .detail-row {{
                    padding: 10px 0;
                    border-bottom: 1px solid #eee;
                }}
                .detail-row:last-child {{
                    border-bottom: none;
                }}
                .detail-label {{
                    font-weight: bold;
                    color: #667eea;
                }}
                .button {{
                    display: inline-block;
                    padding: 15px 30px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    text-decoration: none;
                    border-radius: 5px;
                    margin: 20px 0;
                    font-weight: bold;
                }}
                .button:hover {{
                    opacity: 0.9;
                }}
                .footer {{
                    text-align: center;
                    margin-top: 20px;
                    color: #666;
                    font-size: 12px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Event Invitation</h1>
                </div>
                <div class="content">
                    <p>Hello!</p>
                    <p>You have been invited to attend the following event:</p>

                    <div class="event-details">
                        <div class="detail-row">
                            <span class="detail-label">Event:</span> {event_name}
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Date:</span> {formatted_date}
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Location:</span> {event_location}
                        </div>
                    </div>

                    <p>To attend this event, please register your face for recognition by clicking the button below:</p>

                    <div style="text-align: center;">
                        <a href="{registration_url}" class="button">Register Now</a>
                    </div>

                    <p style="color: #666; font-size: 14px;">
                        Or copy and paste this link into your browser:<br>
                        <a href="{registration_url}">{registration_url}</a>
                    </p>

                    <p><strong>Note:</strong> You will need to upload a clear photo of your face for the face recognition system. This will allow you to check in automatically when you arrive at the event.</p>

                    <div class="footer">
                        <p>This invitation was sent by {self.from_name}</p>
                        <p>If you received this email in error, please ignore it.</p>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """

        # Plain text version
        text_body = f"""
        Event Invitation

        Hello!

        You have been invited to attend the following event:

        Event: {event_name}
        Date: {formatted_date}
        Location: {event_location}

        To attend this event, please register your face for recognition by visiting:
        {registration_url}

        Note: You will need to upload a clear photo of your face for the face recognition system.
        This will allow you to check in automatically when you arrive at the event.

        ---
        This invitation was sent by {self.from_name}
        If you received this email in error, please ignore it.
        """

        return self.send_email(to_email, subject, html_body, text_body)

# Create singleton instance
email_service = EmailService()
