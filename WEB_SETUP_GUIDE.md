# Web-Based Face Recognition Setup Guide

## ✅ What Changed

Your Flutter app has been converted to work on **WEB BROWSER** for walk-through attendance monitoring!

### Key Changes:

1. **Created WebRecognitionScreen.dart**
   - Web-compatible face recognition
   - No ML Kit dependencies (works on browsers)
   - Sends frames to backend for processing

2. **Updated API Service**
   - New endpoint: `detectAndRecognizeFaces()` - for real-time recognition
   - New endpoint: `registerEmployeeWithImage()` - for registration
   - Backend does all face detection/recognition

3. **Updated HomeScreen**
   - Now uses `WebRecognitionScreen` instead of old mobile-only version

4. **Documented Backend Requirements**
   - See `BACKEND_API_REQUIREMENTS.md` for full API specs

---

## 🚀 How to Run on Web

### 1. Start the Flutter Web App

```bash
# Navigate to project directory
cd /Users/FDSAP-JLVILLANUEVA/StudioProjects/RealtimeFaceRecognition2026Starter

# Run on web browser
flutter run -d chrome

# OR build for production
flutter build web
```

### 2. The app will open in Chrome browser

### 3. Access the Web App
- **Local:** http://localhost:PORT
- **Production:** Deploy the `build/web` folder to any web server

---

## 🖥️ Wall-Mounted Attendance Scenario

### Setup:

```
┌─────────────────┐
│   Computer      │ ← Connected to webcam or IP camera
│   Running       │
│   Chrome        │
│   Browser       │
└────────┬────────┘
         │
         │ Sends frames (Base64)
         ↓
┌─────────────────┐
│   Backend       │ ← Your Node.js server (http://10.22.0.231:3000)
│   API Server    │
│                 │
│  - Detects face │
│  - Recognizes   │
│  - Liveness     │
│  - Marks        │
│    attendance   │
└─────────────────┘
```

### User Flow:

1. **Employee walks toward camera** 🚶
2. **Browser captures webcam frame** 📸
3. **Sends frame to backend** (every 1 second)
4. **Backend processes:**
   - Detects face
   - Extracts embeddings
   - Matches against database
   - Checks liveness (anti-spoofing)
   - Returns results
5. **If matched + live:** ✅ Mark attendance
6. **Display name on screen:** "✅ John Doe - Attendance Marked"
7. **Employee continues walking** → System ready for next person

---

## 📋 Backend Requirements

### YOU MUST IMPLEMENT these endpoints on your backend:

#### 1. `/api/detect-recognize` (POST)
**Input:** Base64 image
**Output:** List of detected faces with names

```json
{
  "faces": [
    {
      "boundingBox": {"x": 100, "y": 50, "width": 200, "height": 250},
      "name": "John Doe",
      "employeeId": "EMP001",
      "confidence": 0.95,
      "isLive": true
    }
  ]
}
```

#### 2. `/api/employees/register-with-image` (POST)
**Input:** Employee data + Base64 image
**Output:** Registration success/failure

**Full details:** See `BACKEND_API_REQUIREMENTS.md`

---

## 🎯 Passive Liveness Detection (Backend)

Your backend must detect photos/spoofing. Recommended approaches:

### Option 1: Silent-Face-Anti-Spoofing (Python)
```python
from silent_face_anti_spoofing import AntiSpoofPredictor

predictor = AntiSpoofPredictor()
is_real = predictor.predict(face_image)
```

### Option 2: Multi-Frame Analysis
- Track face across multiple frames
- Detect natural head movement
- Check for depth/3D structure
- Photos are static, real faces move

### Option 3: Texture Analysis
- Check for screen moire patterns
- Analyze color histograms
- Detect photo artifacts

**Implementation examples in:** `BACKEND_API_REQUIREMENTS.md`

---

## 📹 IP Camera Support (Future)

To use IP cameras instead of webcam:

### On Backend:
```python
import cv2

# Connect to IP camera RTSP stream
stream = cv2.VideoCapture('rtsp://192.168.1.100:554/stream')

while True:
    ret, frame = stream.read()

    # Detect and recognize faces
    result = detect_and_recognize(frame)

    # Auto-mark attendance
    for face in result['faces']:
        if face['isLive'] and face['name'] != 'Unknown':
            mark_attendance(face['employeeId'])
```

### On Frontend:
No changes needed! Backend handles camera connection.

---

## 🔧 Configuration

### Update Backend URL

Edit `lib/api/api_service.dart`:

```dart
class ApiService {
  final String baseUrl = 'http://10.22.0.231:3000/api';  // ← Change this
```

For production:
```dart
final String baseUrl = 'https://your-domain.com/api';
```

---

## 🧪 Testing

### Test with Photo (Should Block):
1. Open web app in browser
2. Hold up a printed photo to webcam
3. **Expected:** System should NOT recognize (liveness fails)
4. Check backend logs for "isLive: false"

### Test with Live Person (Should Work):
1. Walk toward webcam naturally
2. Face should be detected
3. **Expected:** "✅ [Your Name] - Live Person Detected"
4. Attendance marked in database

---

## 📱 Mobile App Still Works!

The old `RecognitionScreen.dart` (with ML Kit) still exists for **mobile apps**.

- **Web:** Uses `WebRecognitionScreen` (server-side processing)
- **Mobile:** Uses `RecognitionScreen` (on-device ML Kit)

Both work from same codebase!

---

## 🏗️ Production Deployment

### 1. Build Flutter Web App
```bash
flutter build web --release
```

### 2. Deploy `build/web` folder to:
- **Nginx**
- **Apache**
- **Firebase Hosting**
- **Netlify**
- **Any static web host**

### 3. Configure Web Server

**Nginx Example:**
```nginx
server {
    listen 80;
    server_name attendance.yourcompany.com;

    root /var/www/face-recognition/build/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend
    location /api {
        proxy_pass http://localhost:3000;
    }
}
```

### 4. SSL Certificate (Required for webcam access)
```bash
# Browsers require HTTPS for camera access
certbot --nginx -d attendance.yourcompany.com
```

---

## 🚨 Important Notes

### Webcam Permissions:
- Browsers require **HTTPS** for camera access (except localhost)
- User must **allow camera permission** on first visit

### Performance:
- Current: Processes 1 frame per second
- Adjust in `WebRecognitionScreen.dart`: `FRAME_INTERVAL_MS = 1000`
- Faster = more API calls, better detection
- Slower = less load, may miss quick walk-throughs

### Browser Compatibility:
- ✅ Chrome (recommended)
- ✅ Edge
- ✅ Firefox
- ⚠️ Safari (may have camera issues)

---

## 📊 Attendance Flow

```
Employee enters → Webcam detects face → Send to backend
    ↓
Backend: Detect + Recognize + Liveness Check
    ↓
Match found + Live? → Mark attendance in DB
    ↓
Return to frontend → Show "✅ John Doe - Present"
    ↓
Employee leaves → System resets for next person
```

---

## 🐛 Troubleshooting

### "Camera not detected"
- Check browser permissions
- Ensure HTTPS (or localhost)
- Try different browser

### "No faces detected"
- Check backend logs
- Verify `/api/detect-recognize` is implemented
- Test backend with curl

### "Always shows Unknown"
- Check database has employee embeddings
- Verify face matching threshold (should be ~0.6)
- Check backend matching logic

### "Photos are being recognized"
- Implement liveness detection on backend!
- See `BACKEND_API_REQUIREMENTS.md`
- Use anti-spoofing library

---

## ✅ Checklist

Before going live:

- [ ] Implement `/api/detect-recognize` on backend
- [ ] Implement `/api/employees/register-with-image` on backend
- [ ] Add liveness detection (anti-spoofing)
- [ ] Test with real photos (should block)
- [ ] Test with live person (should work)
- [ ] Deploy web app to production
- [ ] Enable HTTPS
- [ ] Set up IP camera (optional)
- [ ] Configure attendance database
- [ ] Add rate limiting (prevent abuse)
- [ ] Set up monitoring/logging

---

## 📞 Next Steps

1. **Implement Backend APIs** (see `BACKEND_API_REQUIREMENTS.md`)
2. **Test locally** with `flutter run -d chrome`
3. **Add liveness detection** to prevent photo attacks
4. **Deploy to production** when ready

---

## 🎉 Summary

**Frontend:** ✅ Complete and ready for web
**Backend:** ⏳ You need to implement the API endpoints

The Flutter app is now **100% web-compatible** and perfect for your wall-mounted attendance scenario!

No more head turns, no more ML Kit issues, just smooth walk-through attendance monitoring! 🚀
