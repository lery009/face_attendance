# 🔐 Login Guide - Face Recognition Attendance System

## Default Admin Credentials

Your admin account is ready to use:

```
Username: admin
Password: admin123
```

## How to Login

1. **Start the Backend** (if not already running):
   ```bash
   cd backend
   python3 main.py
   ```
   Backend will run on: http://localhost:3000

2. **Start the Flutter App**:
   ```bash
   flutter run -d chrome
   ```
   Or use your IDE's run button

3. **Login**:
   - Open the app in your browser
   - You'll see the **Login Screen** (not "First Time Setup")
   - Enter:
     - Username: `admin`
     - Password: `admin123`
   - Click **"Sign In"**

## After Login

You'll have access to all features:

### ✅ Core Features:
- **Dashboard** - Overview and statistics
- **Mark Attendance** - Face recognition check-in
- **Register Employee** - Add new employees with face images
- **Attendance Logs** - View all check-in records

### ✅ Advanced Features:
- **QR Code Scanner** - Alternative check-in method
- **Analytics Dashboard** - Charts and visualizations
- **Reports & Analytics** - Export to Excel/CSV/PDF
- **Employee Management** - CRUD operations
- **Bulk Import** - Import employees from CSV
- **Event Management** - Create events with attendance tracking
- **Online Registration** - Public self-registration portal

### 🔧 Admin-Only Features:
- **User Management** - Create users with different roles (admin/manager/user)
- **Location Management** - GPS geofencing for check-ins
- **Notification Settings** - Email notifications configuration
- **Dark Mode Toggle** - Switch theme (icon in top right)

## User Roles

The system supports 3 roles:

1. **Admin** - Full system access
2. **Manager** - Can manage employees and view reports
3. **User** - Basic attendance marking only

## Need to Reset Password?

If you forget the password, run:

```bash
cd backend
python3 reset_password.py
```

Follow the prompts to reset any user's password.

## Creating Additional Users

After logging in as admin:

1. Go to **Dashboard**
2. Scroll down to **"User Management"** (admin only)
3. Click **"Add New User"**
4. Fill in the details:
   - Username
   - Password
   - Email
   - Full Name
   - Role (admin/manager/user)
5. Click **Create User**

## Troubleshooting

### "Cannot connect to server"
- Make sure backend is running: `cd backend && python3 main.py`
- Check backend URL in Flutter app: `lib/api/api_service.dart` (should be `http://localhost:3000/api`)

### "Login failed"
- Double-check credentials (username: `admin`, password: `admin123`)
- Try resetting password with `python3 reset_password.py`

### "First Time Setup" screen appears
- This has been fixed in the latest code
- Refresh the app
- If it persists, the login screen should still work - just use the admin credentials

## Database Location

PostgreSQL database connection is configured in:
```
backend/.env
```

Default: `postgresql://user:password@localhost:5432/face_recognition_db`

## Backend API Documentation

The backend API is running at: http://localhost:3000

View API endpoints: http://localhost:3000 (shows welcome message with available endpoints)

## Security Notes

⚠️ **Important for Production:**

1. **Change the default admin password** immediately after first login
2. **Update JWT secret** in `backend/.env`:
   ```
   JWT_SECRET_KEY=your-secure-random-key-here
   ```
3. **Configure CORS** properly in `backend/config.py`
4. **Use HTTPS** in production
5. **Enable email notifications** for security alerts

## Features Summary

This system includes:

✅ **11 Completed Phases:**
1. Late/Absent tracking with work hours
2. Export Reports (Excel/CSV/PDF)
3. Analytics Dashboard with charts
4. Search & Filters
5. Admin Roles & Permissions
6. QR Code check-in system
7. GPS Geofencing
8. Email Notifications
9. Bulk Operations & Multi-face registration
10. Dark Mode theme support
11. Complete authentication system

## Support

For issues or questions:
- Check the console logs (browser F12 for frontend, terminal for backend)
- Review backend logs for API errors
- Check database connection in `.env`

---

**System Status:** ✅ Fully Operational
**Backend:** Running on port 3000
**Frontend:** Flutter Web/Mobile
**Database:** PostgreSQL
**Authentication:** JWT-based with bcrypt password hashing
