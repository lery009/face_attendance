"""
Email Notification Service
Sends email notifications for attendance events
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from typing import Optional, List
from config import settings


class NotificationService:
    """Service for sending email notifications"""

    @staticmethod
    def is_enabled() -> bool:
        """Check if email notifications are enabled"""
        return (settings.EMAIL_ENABLED and
                settings.SMTP_USERNAME and
                settings.SMTP_PASSWORD)

    @staticmethod
    def send_email(
        to_email: str,
        subject: str,
        html_body: str,
        plain_body: Optional[str] = None
    ) -> bool:
        """
        Send an email notification

        Args:
            to_email: Recipient email address
            subject: Email subject
            html_body: HTML email body
            plain_body: Plain text fallback (optional)

        Returns:
            True if sent successfully, False otherwise
        """
        if not NotificationService.is_enabled():
            print(f"📧 Email notifications disabled, skipping: {subject}")
            return False

        try:
            # Create message
            message = MIMEMultipart('alternative')
            message['From'] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
            message['To'] = to_email
            message['Subject'] = subject

            # Add plain text part
            if plain_body:
                message.attach(MIMEText(plain_body, 'plain'))

            # Add HTML part
            message.attach(MIMEText(html_body, 'html'))

            # Connect to SMTP server and send
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
                server.starttls()
                server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
                server.send_message(message)

            print(f"✅ Email sent to {to_email}: {subject}")
            return True

        except Exception as e:
            print(f"❌ Failed to send email to {to_email}: {e}")
            return False

    @staticmethod
    def send_late_arrival_notification(
        employee_name: str,
        employee_email: str,
        check_in_time: datetime,
        minutes_late: int
    ) -> bool:
        """
        Send late arrival notification to employee

        Args:
            employee_name: Employee's name
            employee_email: Employee's email
            check_in_time: When they checked in
            minutes_late: How many minutes late

        Returns:
            True if sent successfully
        """
        if not settings.NOTIFY_ON_LATE:
            return False

        subject = "Late Arrival Notice"

        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #ff9800; color: white; padding: 20px; border-radius: 5px 5px 0 0; }}
                .content {{ background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }}
                .footer {{ text-align: center; margin-top: 20px; font-size: 12px; color: #666; }}
                .warning {{ color: #ff9800; font-weight: bold; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>⏰ Late Arrival Notice</h2>
                </div>
                <div class="content">
                    <p>Hello <strong>{employee_name}</strong>,</p>

                    <p>This is to inform you that your attendance was marked as <span class="warning">LATE</span>.</p>

                    <p><strong>Check-in Details:</strong></p>
                    <ul>
                        <li>Time: {check_in_time.strftime('%I:%M %p')}</li>
                        <li>Date: {check_in_time.strftime('%B %d, %Y')}</li>
                        <li>Delay: {minutes_late} minutes</li>
                    </ul>

                    <p>Please ensure to arrive on time for future check-ins.</p>

                    <p>If you have any concerns regarding this notice, please contact your supervisor or HR department.</p>
                </div>
                <div class="footer">
                    <p>This is an automated notification from the Attendance System.</p>
                    <p>&copy; {datetime.now().year} Attendance Management System</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_body = f"""
        Late Arrival Notice

        Hello {employee_name},

        This is to inform you that your attendance was marked as LATE.

        Check-in Details:
        - Time: {check_in_time.strftime('%I:%M %p')}
        - Date: {check_in_time.strftime('%B %d, %Y')}
        - Delay: {minutes_late} minutes

        Please ensure to arrive on time for future check-ins.
        """

        return NotificationService.send_email(
            to_email=employee_email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body
        )

    @staticmethod
    def send_check_in_confirmation(
        employee_name: str,
        employee_email: str,
        check_in_time: datetime,
        status: str,
        method: str = "face_recognition"
    ) -> bool:
        """
        Send check-in confirmation email

        Args:
            employee_name: Employee's name
            employee_email: Employee's email
            check_in_time: When they checked in
            status: Attendance status (on_time, late, etc.)
            method: Check-in method

        Returns:
            True if sent successfully
        """
        # Determine color based on status
        status_colors = {
            'on_time': '#4caf50',
            'late': '#ff9800',
            'half_day': '#f44336',
            'early_departure': '#2196f3'
        }
        status_color = status_colors.get(status, '#666')

        # Determine icon based on method
        method_icons = {
            'face_recognition': '👤',
            'qr_code': '📱',
            'manual': '✍️'
        }
        method_icon = method_icons.get(method, '✓')

        subject = f"Check-in Confirmation - {status.replace('_', ' ').title()}"

        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: {status_color}; color: white; padding: 20px; border-radius: 5px 5px 0 0; }}
                .content {{ background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }}
                .status {{ color: {status_color}; font-weight: bold; text-transform: uppercase; }}
                .footer {{ text-align: center; margin-top: 20px; font-size: 12px; color: #666; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>✅ Attendance Confirmed</h2>
                </div>
                <div class="content">
                    <p>Hello <strong>{employee_name}</strong>,</p>

                    <p>Your attendance has been successfully recorded.</p>

                    <p><strong>Check-in Details:</strong></p>
                    <ul>
                        <li>Time: {check_in_time.strftime('%I:%M %p')}</li>
                        <li>Date: {check_in_time.strftime('%B %d, %Y')}</li>
                        <li>Status: <span class="status">{status.replace('_', ' ')}</span></li>
                        <li>Method: {method_icon} {method.replace('_', ' ').title()}</li>
                    </ul>

                    <p>Thank you for marking your attendance!</p>
                </div>
                <div class="footer">
                    <p>This is an automated notification from the Attendance System.</p>
                    <p>&copy; {datetime.now().year} Attendance Management System</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_body = f"""
        Attendance Confirmed

        Hello {employee_name},

        Your attendance has been successfully recorded.

        Check-in Details:
        - Time: {check_in_time.strftime('%I:%M %p')}
        - Date: {check_in_time.strftime('%B %d, %Y')}
        - Status: {status.replace('_', ' ').upper()}
        - Method: {method.replace('_', ' ').title()}

        Thank you for marking your attendance!
        """

        return NotificationService.send_email(
            to_email=employee_email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body
        )

    @staticmethod
    def send_daily_summary(
        admin_email: str,
        date: datetime,
        total_employees: int,
        present_count: int,
        late_count: int,
        absent_count: int,
        late_employees: List[dict] = None
    ) -> bool:
        """
        Send daily attendance summary to admin

        Args:
            admin_email: Admin email address
            date: Date of the summary
            total_employees: Total number of employees
            present_count: Number of employees present
            late_count: Number of late arrivals
            absent_count: Number of absences
            late_employees: List of late employees with details

        Returns:
            True if sent successfully
        """
        if not settings.DAILY_SUMMARY_ENABLED:
            return False

        subject = f"Daily Attendance Summary - {date.strftime('%B %d, %Y')}"

        # Build late employees table
        late_employees_html = ""
        if late_employees and len(late_employees) > 0:
            late_employees_html = "<h3>Late Arrivals:</h3><ul>"
            for emp in late_employees:
                late_employees_html += f"<li><strong>{emp['name']}</strong> - {emp['time']} ({emp['minutes_late']} min late)</li>"
            late_employees_html += "</ul>"

        # Calculate percentages
        on_time_count = present_count - late_count
        on_time_pct = (on_time_count / total_employees * 100) if total_employees > 0 else 0
        late_pct = (late_count / total_employees * 100) if total_employees > 0 else 0
        absent_pct = (absent_count / total_employees * 100) if total_employees > 0 else 0

        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 700px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #1E3A8A; color: white; padding: 20px; border-radius: 5px 5px 0 0; }}
                .content {{ background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }}
                .stats {{ display: flex; justify-content: space-around; margin: 20px 0; }}
                .stat-box {{ background: white; padding: 15px; border-radius: 5px; text-align: center; flex: 1; margin: 0 10px; }}
                .stat-number {{ font-size: 32px; font-weight: bold; }}
                .stat-label {{ font-size: 14px; color: #666; }}
                .on-time {{ color: #4caf50; }}
                .late {{ color: #ff9800; }}
                .absent {{ color: #f44336; }}
                .footer {{ text-align: center; margin-top: 20px; font-size: 12px; color: #666; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>📊 Daily Attendance Summary</h2>
                    <p>{date.strftime('%A, %B %d, %Y')}</p>
                </div>
                <div class="content">
                    <div class="stats">
                        <div class="stat-box">
                            <div class="stat-number on-time">{on_time_count}</div>
                            <div class="stat-label">On Time ({on_time_pct:.1f}%)</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-number late">{late_count}</div>
                            <div class="stat-label">Late ({late_pct:.1f}%)</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-number absent">{absent_count}</div>
                            <div class="stat-label">Absent ({absent_pct:.1f}%)</div>
                        </div>
                    </div>

                    <p><strong>Total Employees:</strong> {total_employees}</p>
                    <p><strong>Present Today:</strong> {present_count} ({(present_count/total_employees*100):.1f}%)</p>

                    {late_employees_html}
                </div>
                <div class="footer">
                    <p>This is an automated daily summary from the Attendance System.</p>
                    <p>&copy; {datetime.now().year} Attendance Management System</p>
                </div>
            </div>
        </body>
        </html>
        """

        return NotificationService.send_email(
            to_email=admin_email,
            subject=subject,
            html_body=html_body
        )

    @staticmethod
    def send_registration_invitation(
        recipient_email: str,
        invitation_token: str,
        frontend_url: str = "http://localhost",
        event=None
    ) -> bool:
        """
        Send registration invitation email with unique link

        Args:
            recipient_email: Email address to send invitation to
            invitation_token: Unique invitation token
            frontend_url: Frontend URL (for generating registration link)
            event: Optional Event object if invitation is for an event

        Returns:
            True if sent successfully
        """
        registration_link = f"{frontend_url}/#/register?token={invitation_token}"

        # Update subject based on whether it's for an event
        if event:
            subject = f"You're Invited to {event.name} - Registration Required"
        else:
            subject = "You're Invited to Register - Attendance System"

        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #1E3A8A; color: white; padding: 20px; border-radius: 5px 5px 0 0; }}
                .content {{ background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }}
                .button {{ display: inline-block; background-color: #1E3A8A; color: white; padding: 12px 30px;
                           text-decoration: none; border-radius: 5px; margin: 20px 0; font-weight: bold; }}
                .button:hover {{ background-color: #2563eb; }}
                .footer {{ text-align: center; margin-top: 20px; font-size: 12px; color: #666; }}
                .info-box {{ background-color: #e3f2fd; padding: 15px; border-left: 4px solid #2196f3; margin: 15px 0; }}
                .link {{ color: #1E3A8A; word-break: break-all; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h2>📧 Registration Invitation</h2>
                </div>
                <div class="content">
                    <p>Hello,</p>

                    <p>You've been invited to register for the <strong>Face Recognition Attendance System</strong>.</p>

                    {f'''
                    <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
                        <h3 style="margin: 0 0 10px 0; color: #856404;">📅 Event Invitation</h3>
                        <p style="margin: 5px 0;"><strong>Event:</strong> {event.name}</p>
                        {f'<p style="margin: 5px 0;"><strong>Description:</strong> {event.description}</p>' if event.description else ''}
                        {f'<p style="margin: 5px 0;"><strong>Date:</strong> {event.start_date.strftime("%B %d, %Y") if event.start_date else "TBA"}{f" - {event.end_date.strftime('%B %d, %Y')}" if event.end_date and event.end_date != event.start_date else ""}</p>' if event.start_date else ''}
                        <p style="margin: 5px 0; font-weight: bold; color: #856404;">You must register first to participate in this event!</p>
                    </div>
                    ''' if event else ''}

                    <p>Click the button below to complete your registration:</p>

                    <div style="text-align: center;">
                        <a href="{registration_link}" class="button">Complete Registration</a>
                    </div>

                    <div class="info-box">
                        <strong>What to prepare:</strong>
                        <ul style="margin: 10px 0;">
                            <li>A clear photo of your face (well-lit, facing forward)</li>
                            <li>Your personal information (name, employee ID, department)</li>
                            <li>Contact details (phone number, address)</li>
                        </ul>
                    </div>

                    <p style="font-size: 14px; color: #666;">If the button doesn't work, copy and paste this link into your browser:</p>
                    <p class="link">{registration_link}</p>

                    <p style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 13px; color: #666;">
                        <strong>Note:</strong> This invitation link is unique to you and will expire after use or after 7 days.
                    </p>
                </div>
                <div class="footer">
                    <p>This is an automated invitation from the Attendance System.</p>
                    <p>&copy; {datetime.now().year} Attendance Management System</p>
                </div>
            </div>
        </body>
        </html>
        """

        plain_body = f"""
        Registration Invitation - Face Recognition Attendance System

        Hello,

        You've been invited to register for the Face Recognition Attendance System.

        {f'''
        EVENT INVITATION:
        Event: {event.name}
        {f"Description: {event.description}" if event.description else ""}
        {f"Date: {event.start_date.strftime('%B %d, %Y')}" if event.start_date else ""}

        You must register first to participate in this event!
        ''' if event else ''}

        Complete your registration by visiting this link:
        {registration_link}

        What to prepare:
        - A clear photo of your face (well-lit, facing forward)
        - Your personal information (name, employee ID, department)
        - Contact details (phone number, address)

        Note: This invitation link is unique to you and will expire after use or after 7 days.

        ---
        Attendance Management System
        """

        return NotificationService.send_email(
            to_email=recipient_email,
            subject=subject,
            html_body=html_body,
            plain_body=plain_body
        )
