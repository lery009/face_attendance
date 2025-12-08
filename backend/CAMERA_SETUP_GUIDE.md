# Camera Setup & Configuration Guide

## 🎯 Current System Status

✅ **Working Setup:**
- Camera IP: `10.22.0.35` (Dahua DHI-ASA3223A-W)
- Backend: PostgreSQL-based face recognition
- Attendance: Automatic logging when faces detected

## 📡 Set Static IP on Camera

### Quick Access
- **Web Interface:** http://10.22.0.35
- **Username:** admin
- **Password:** admin@2025

### Steps to Set Static IP

1. **Login** to camera web interface
2. Go to: **Setup** → **Network** → **TCP/IP**
3. **Change settings:**
   ```
   Mode: Static (not DHCP)
   IP Address: 10.22.0.35
   Subnet Mask: 255.255.255.0
   Gateway: 10.22.0.1
   DNS: 8.8.8.8
   ```
4. **Save** and **Reboot**
5. **Verify** camera comes back at same IP

### Why Static IP?
- IP never changes
- No need for auto-discovery
- Reliable connection
- System always knows where camera is

## 🔧 If Camera IP Changes

If you forgot to set static IP and camera gets new IP:

```bash
cd backend
python3 update_camera_ip.py
# Follow prompts to update database
```

Or manually update in database:
```sql
UPDATE cameras
SET stream_url = 'rtsp://admin:admin%402025@NEW_IP:554/cam/realmonitor?channel=1&subtype=0'
WHERE name = 'Dahua Home';
```

## 📊 How The System Works

### Data Flow
```
1. Register Employee (Laptop Camera)
   ↓
2. Face Encoding Saved to PostgreSQL
   ↓
3. Backend Loads Known Faces (10 employees including "lry")
   ↓
4. Dahua Camera Detects Face (Hardware)
   ↓
5. Backend Receives Event & Gets Snapshot
   ↓
6. Face Recognition (Python face_recognition library)
   ↓
7. Match Against Known Faces
   ↓
8. Log Attendance to PostgreSQL
```

### Two Separate Databases

**Our PostgreSQL Database:**
- Registered via laptop camera
- Backend uses this for recognition
- Unlimited storage
- Easy to update
- ✅ **This is your source of truth**

**Camera's Internal Database:**
- Registered via camera web interface
- Camera shows names on screen
- Limited to ~3000 faces
- Requires manual sync
- ⚠️ **Keep this empty or separate**

## 🎯 Recommended Setup

### Option 1: Backend Only (CURRENT - RECOMMENDED)
```
✅ Register employees via your app (laptop camera)
✅ Face encodings stored in PostgreSQL
✅ Camera detects faces (hardware)
✅ Backend recognizes faces (software)
✅ Attendance logged automatically
❌ Camera screen won't show employee names
```

**Pros:**
- Already working
- Single source of truth
- Easy to manage
- Scalable

**Cons:**
- Camera display shows "Unknown" or generic message

### Option 2: Dual Database (ADVANCED)
```
📝 Register via app → PostgreSQL
➕ Manually add to camera → Camera database
✅ Backend recognizes
✅ Camera display shows names
```

**Pros:**
- Camera screen shows names
- Both systems work

**Cons:**
- Manual work per employee
- Easy to get out of sync
- More complex to maintain

## 🚀 Current Features

### ✅ What's Working
1. **Face Detection Logging**
   - Comprehensive event logs
   - Shows ALL incoming events
   - Multiple event code support
   - Connection status tracking

2. **Face Recognition**
   - Step-by-step logging
   - Shows top 3 matches with confidence
   - 30-second cooldown per person
   - Detailed error messages

3. **Automatic Monitoring**
   - Backend starts monitoring on startup
   - Subscribes to: FaceDetection, FaceRecognition, AccessControl, VideoAnalyse
   - Auto-reconnects on disconnect
   - Thread-safe operation

### 📈 What You'll See in Logs

When someone walks in front of camera:

```
============================================================
🎯 FACE DETECTED by Dahua Home!
============================================================
   Event Code: FaceDetection
📸 Requesting snapshot from camera...
   ✅ Snapshot received (245678 bytes)
🔍 Starting face recognition...
   Step 1: Decoding image...
   ✅ Image decoded: (1080, 1920, 3)
   Step 2: Converting to RGB...
   Step 3: Detecting faces in image...
   ✅ Found 1 face location(s)
   Step 4: Extracting face encodings...
   ✅ Extracted 1 face encoding(s)
   Step 5: Matching against 10 known faces...

   Face #1:
      Comparing against 10 employees...
      Top matches:
        1. EMP001: 95.23% (✅ MATCH)
        2. EMP002: 62.15% (❌ No match)
        3. EMP003: 58.92% (❌ No match)
      ✅ RECOGNIZED: EMP001 (confidence: 95.23%)
      ✅ Proceeding to log attendance...
      📝 Attendance logged for John Doe
============================================================
```

## 🔍 Troubleshooting

### Camera Offline
```bash
# Check if camera is reachable
ping 10.22.0.35

# Test HTTP access
curl -I http://10.22.0.35
```

### No Face Detection Events
1. Check backend logs for connection status
2. Verify face analysis enabled on camera:
   ```bash
   curl --digest -u "admin:admin@2025" \
     "http://10.22.0.35/cgi-bin/configManager.cgi?action=getConfig&name=VideoAnalyseRule"
   ```
3. Look for `Enable=true` in response

### Face Not Recognized
- Check if employee registered with face photo
- Verify embeddings saved in database
- Check matching confidence threshold (currently 60%)
- Review backend logs for match details

### Attendance Not Logging
1. Check cooldown period (30 seconds between logs)
2. Verify employee is in event participants
3. Check database connection
4. Review backend error logs

## 📝 Database Schema

### Employees Table
```sql
CREATE TABLE employees (
    id UUID PRIMARY KEY,
    employee_id VARCHAR UNIQUE,
    name VARCHAR,
    embeddings JSONB,  -- Face encoding (128-dim array)
    is_active BOOLEAN
);
```

### Cameras Table
```sql
CREATE TABLE cameras (
    id UUID PRIMARY KEY,
    name VARCHAR,
    camera_type VARCHAR,  -- 'rtsp'
    stream_url VARCHAR,   -- Full RTSP URL with credentials
    username VARCHAR,
    password VARCHAR,
    is_active BOOLEAN
);
```

### Attendance Logs Table
```sql
CREATE TABLE attendance_logs (
    id UUID PRIMARY KEY,
    employee_id UUID REFERENCES employees(id),
    camera_id UUID REFERENCES cameras(id),
    timestamp TIMESTAMP,
    status VARCHAR,  -- 'present'
    confidence FLOAT
);
```

## 🎛️ Configuration

### Recognition Tolerance
File: `camera_monitoring_service.py:227`
```python
matches = fr.compare_faces(known_encodings, face_encoding, tolerance=0.6)
```
- Lower = stricter matching (fewer false positives)
- Higher = looser matching (more false positives)
- Default: 0.6 (60% match required)

### Cooldown Period
File: `camera_monitoring_service.py:27`
```python
self.recognition_cooldown = 30  # seconds
```
- Prevents duplicate logs
- Adjust based on your needs

### Event Subscription
File: `dahua_face_service.py:140`
```python
event_codes = "FaceDetection,FaceRecognition,AccessControl,VideoAnalyse"
```
- Subscribes to multiple event types
- Ensures all face-related events are captured

## 🔐 Security Notes

### Camera Credentials
- Default: admin/admin@2025
- Change in camera web interface
- Update in database after changing
- Use strong passwords

### Network Security
- Camera on local network (10.22.0.0/24)
- Not exposed to internet
- Backend authentication required for API access

### Data Privacy
- Face encodings are one-way (cannot reconstruct face from encoding)
- Snapshots saved to /tmp (temporary)
- Can be configured to not save snapshots

## 📚 Related Files

### Core Services
- `camera_monitoring_service.py` - Main monitoring & recognition
- `dahua_face_service.py` - Event streaming from camera
- `dahua_sdk_service.py` - HTTP API wrapper

### Configuration
- `database.py` - Database models
- `config.py` - Environment settings
- `.env` - Credentials (not in git)

### Test Scripts
- `test_event_stream.py` - Test event subscription
- `test_monitoring.py` - Check monitoring status
- `update_camera_ip.py` - Update camera IP
- `test_camera_face_api.py` - Test face API endpoints

### Documentation
- `CAMERA_INTEGRATION_GUIDE.md` - Integration details
- `DAHUA_SDK_SUMMARY.md` - SDK capabilities
- `CAMERA_SETUP_GUIDE.md` - This file

## ✅ Checklist

Before going live:

- [ ] Set static IP on camera (10.22.0.35)
- [ ] Verify camera web interface accessible
- [ ] Test backend monitoring starts successfully
- [ ] Register test employee with face photo
- [ ] Walk in front of camera to test detection
- [ ] Verify attendance logged in database
- [ ] Check logs show detailed recognition steps
- [ ] Set appropriate cooldown period
- [ ] Adjust recognition tolerance if needed
- [ ] Document any custom configurations

## 🆘 Support

If you encounter issues:

1. Check backend logs for detailed errors
2. Verify camera is online: `ping 10.22.0.35`
3. Test face analysis config on camera
4. Review employee embeddings in database
5. Check event subscription is active
6. Verify database connection working

## 🎉 System Ready!

Your attendance system is configured and ready to use. The camera will automatically detect faces, the backend will recognize them, and attendance will be logged - all without manual intervention!

Key Points:
- ✅ Single source of truth: PostgreSQL database
- ✅ Camera provides hardware face detection
- ✅ Backend provides intelligent recognition
- ✅ Automatic logging with detailed visibility
- ✅ Static IP prevents connection issues
