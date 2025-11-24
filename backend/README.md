# Face Recognition Backend API

Complete Python + FastAPI backend for web-based face recognition and attendance tracking.

## 🎯 Features

- ✅ Face detection and recognition
- ✅ Liveness detection (anti-spoofing)
- ✅ Employee registration with face images
- ✅ Automatic attendance marking
- ✅ Database storage (PostgreSQL/MySQL)
- ✅ RESTful API with CORS support
- ✅ Fast and scalable (FastAPI + Uvicorn)

---

## 📋 Prerequisites

### Required:
- Python 3.8 or higher
- PostgreSQL or MySQL database
- pip (Python package manager)

### Optional:
- GPU with CUDA (for faster CNN face detection)
- Virtual environment (recommended)

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd backend

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install packages
pip install -r requirements.txt
```

**Installation time:** ~5-10 minutes (downloads ML models)

### 2. Set Up Database

#### Option A: PostgreSQL (Recommended)

```bash
# Install PostgreSQL
brew install postgresql  # macOS
# OR
sudo apt install postgresql  # Linux

# Start PostgreSQL
brew services start postgresql  # macOS
sudo service postgresql start  # Linux

# Create database
psql postgres
CREATE DATABASE face_recognition_db;
CREATE USER your_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE face_recognition_db TO your_user;
\q
```

#### Option B: MySQL

```bash
# Install MySQL
brew install mysql  # macOS
sudo apt install mysql-server  # Linux

# Start MySQL
brew services start mysql  # macOS
sudo service mysql start  # Linux

# Create database
mysql -u root -p
CREATE DATABASE face_recognition_db;
CREATE USER 'your_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON face_recognition_db.* TO 'your_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Configure Environment

```bash
# Copy example config
cp .env.example .env

# Edit configuration
nano .env  # or use any text editor
```

**Update `.env` with your database credentials:**

```env
DATABASE_URL=postgresql://your_user:your_password@localhost:5432/face_recognition_db
```

### 4. Run the API Server

```bash
python main.py
```

**Expected output:**
```
✅ Database tables created successfully
🚀 Face Recognition Backend Started
📍 API running at: http://0.0.0.0:3000
🔍 Liveness detection: ✅ Enabled
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:3000
```

**API is now running at:** `http://localhost:3000`

---

## 📚 API Endpoints

### 1. Face Detection + Recognition

**POST** `/api/detect-recognize`

Detect faces in image and recognize them.

**Request:**
```json
{
  "image": "base64_encoded_image_string"
}
```

**Response:**
```json
{
  "faces": [
    {
      "boundingBox": {"x": 100, "y": 50, "width": 200, "height": 250},
      "name": "John Doe",
      "employeeId": "EMP001",
      "confidence": 0.95,
      "isLive": true,
      "livenessConfidence": 0.89,
      "attendanceMarked": true
    }
  ]
}
```

### 2. Employee Registration

**POST** `/api/employees/register-with-image`

Register new employee with face image.

**Request:**
```json
{
  "name": "John Doe",
  "firstname": "John",
  "lastname": "Doe",
  "employeeId": "EMP001",
  "department": "Engineering",
  "email": "john@company.com",
  "image": "base64_encoded_image_string"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Employee registered successfully",
  "data": {
    "id": "uuid-here",
    "employeeId": "EMP001",
    "name": "John Doe",
    "faceDetected": true
  }
}
```

### 3. Get All Employees

**GET** `/api/employees`

**Response:**
```json
{
  "success": true,
  "count": 5,
  "employees": [
    {
      "id": "uuid",
      "name": "John Doe",
      "employeeId": "EMP001",
      "department": "Engineering",
      "email": "john@company.com",
      "createdAt": "2024-01-15T10:30:00"
    }
  ]
}
```

### 4. Get Attendance Logs

**GET** `/api/attendance?date=2024-01-15&employee_id=EMP001`

**Query Parameters:**
- `date` (optional): Filter by date (YYYY-MM-DD)
- `employee_id` (optional): Filter by employee ID

**Response:**
```json
{
  "success": true,
  "count": 10,
  "logs": [
    {
      "id": "uuid",
      "employeeId": "EMP001",
      "employeeName": "John Doe",
      "timestamp": "2024-01-15T09:00:15",
      "confidence": "0.95",
      "method": "face_recognition"
    }
  ]
}
```

### 5. Health Check

**GET** `/health`

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00",
  "liveness_enabled": true
}
```

---

## 🧪 Testing the API

### Using curl:

```bash
# Health check
curl http://localhost:3000/health

# Test with image (replace with your base64 image)
BASE64_IMAGE=$(base64 -i test_photo.jpg | tr -d '\n')

# Detect and recognize
curl -X POST http://localhost:3000/api/detect-recognize \
  -H "Content-Type: application/json" \
  -d "{\"image\": \"$BASE64_IMAGE\"}"

# Register employee
curl -X POST http://localhost:3000/api/employees/register-with-image \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"John Doe\",
    \"firstname\": \"John\",
    \"lastname\": \"Doe\",
    \"employeeId\": \"EMP001\",
    \"department\": \"Engineering\",
    \"email\": \"john@company.com\",
    \"image\": \"$BASE64_IMAGE\"
  }"

# Get all employees
curl http://localhost:3000/api/employees

# Get today's attendance
TODAY=$(date +%Y-%m-%d)
curl "http://localhost:3000/api/attendance?date=$TODAY"
```

### Using Python:

```python
import requests
import base64

# Read and encode image
with open("test_photo.jpg", "rb") as f:
    image_base64 = base64.b64encode(f.read()).decode()

# Detect and recognize
response = requests.post(
    "http://localhost:3000/api/detect-recognize",
    json={"image": image_base64}
)

print(response.json())
```

---

## ⚙️ Configuration

Edit `.env` file to customize settings:

### Face Recognition

```env
# Lower = stricter matching (0.4-0.6 recommended)
FACE_TOLERANCE=0.6

# Detection model: "hog" (fast) or "cnn" (accurate, needs GPU)
FACE_DETECTION_MODEL=hog

# Maximum faces to detect per image
MAX_FACES_PER_IMAGE=10
```

### Liveness Detection

```env
# Enable/disable liveness detection
ENABLE_LIVENESS=true

# Threshold for liveness (0.6-0.8 recommended)
LIVENESS_THRESHOLD=0.7
```

### Attendance

```env
# Prevent duplicate attendance (minutes)
ATTENDANCE_COOLDOWN_MINUTES=5
```

---

## 🔒 Liveness Detection

### How It Works:

The backend uses **multi-method liveness detection** to prevent photo spoofing:

1. **Texture Analysis**
   - Real faces have more texture variation
   - Photos are flatter

2. **Frequency Analysis**
   - Detects screen moire patterns
   - Photos/screens have periodic patterns

3. **Color Diversity**
   - Real faces have more color variation
   - Photos have compressed color space

### Scores:

- `isLive: true` → Real person detected
- `isLive: false` → Photo/spoof detected
- `livenessConfidence: 0.0-1.0` → Confidence score

### Adjusting Sensitivity:

```env
# Stricter (fewer false accepts, may reject real faces)
LIVENESS_THRESHOLD=0.8

# Looser (more false accepts, fewer false rejects)
LIVENESS_THRESHOLD=0.6
```

---

## 📊 Database Schema

### Tables Created Automatically:

#### `employees`
```sql
id              VARCHAR(255) PRIMARY KEY
name            VARCHAR(255)
firstname       VARCHAR(255)
lastname        VARCHAR(255)
employee_id     VARCHAR(255) UNIQUE
department      VARCHAR(255)
email           VARCHAR(255)
embeddings      JSON            -- Face encoding (128-dim vector)
created_at      TIMESTAMP
updated_at      TIMESTAMP
is_active       BOOLEAN
```

#### `attendance_logs`
```sql
id              VARCHAR(255) PRIMARY KEY
employee_id     VARCHAR(255)
timestamp       TIMESTAMP
confidence      VARCHAR(50)
method          VARCHAR(50)
```

---

## 🚀 Production Deployment

### 1. Use Production Database

Update `.env`:
```env
DATABASE_URL=postgresql://user:password@production-db-host:5432/face_recognition_db
```

### 2. Disable Debug Mode

Edit `main.py`:
```python
uvicorn.run(
    "main:app",
    host="0.0.0.0",
    port=3000,
    reload=False,  # Disable auto-reload
    log_level="warning"  # Reduce logs
)
```

### 3. Use Production Server

```bash
# Install gunicorn
pip install gunicorn

# Run with gunicorn (better for production)
gunicorn main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:3000 \
  --access-logfile - \
  --error-logfile -
```

### 4. Configure CORS

Edit `config.py`:
```python
CORS_ORIGINS = [
    "https://attendance.yourcompany.com",
    "https://yourcompany.com"
]
```

### 5. Set Up Reverse Proxy (Nginx)

```nginx
server {
    listen 80;
    server_name api.yourcompany.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 6. Enable SSL

```bash
certbot --nginx -d api.yourcompany.com
```

---

## 🔧 Troubleshooting

### Issue: "No module named 'face_recognition'"

**Solution:**
```bash
# Install CMake and dlib first
pip install cmake
pip install dlib
pip install face-recognition
```

### Issue: Database connection error

**Solution:**
```bash
# Check database is running
psql -U your_user -d face_recognition_db

# Verify DATABASE_URL in .env
# Make sure host, port, username, password are correct
```

### Issue: "No face detected"

**Solution:**
- Ensure image has clear frontal face
- Check image is not too dark/bright
- Try using `FACE_DETECTION_MODEL=cnn` for better accuracy

### Issue: Slow processing

**Solution:**
- Use `FACE_DETECTION_MODEL=hog` (faster)
- Reduce `MAX_FACES_PER_IMAGE`
- Use GPU with CNN model
- Resize images before sending

### Issue: Photos are being detected as live

**Solution:**
```env
# Increase liveness threshold
LIVENESS_THRESHOLD=0.8

# Or temporarily disable for testing
ENABLE_LIVENESS=false
```

---

## 📈 Performance

### Expected Processing Times:

- **Face Detection:** 100-300ms per image
- **Face Recognition:** 50-100ms per face
- **Liveness Detection:** 50-150ms per face
- **Total:** ~200-500ms per request

### Optimization Tips:

1. **Use HOG model** (faster, CPU-friendly)
2. **Resize images** client-side (max 1280px width)
3. **Enable GPU** for CNN model
4. **Cache employee embeddings** in Redis
5. **Use multiple workers** (gunicorn)

---

## 🔐 Security Best Practices

1. **Enable HTTPS** in production
2. **Restrict CORS** origins
3. **Use strong database passwords**
4. **Enable rate limiting**
5. **Validate image sizes**
6. **Keep liveness detection enabled**
7. **Monitor for suspicious activity**
8. **Regular database backups**

---

## 📝 Development

### Running in Development Mode:

```bash
# Auto-reload on code changes
python main.py

# OR with uvicorn directly
uvicorn main:app --reload --host 0.0.0.0 --port 3000
```

### Adding New Features:

1. **New endpoint** → Add to `main.py`
2. **Database model** → Add to `database.py`
3. **Configuration** → Add to `config.py`
4. **Face processing logic** → Add to `face_processor.py`

---

## 📦 Project Structure

```
backend/
├── main.py                  # FastAPI application & endpoints
├── config.py                # Configuration settings
├── database.py              # Database models & connection
├── face_processor.py        # Face detection & recognition
├── liveness_detector.py     # Liveness detection logic
├── requirements.txt         # Python dependencies
├── .env.example            # Configuration template
└── README.md               # This file
```

---

## 🆘 Support

### Common Commands:

```bash
# Install dependencies
pip install -r requirements.txt

# Run server
python main.py

# Check logs
tail -f uvicorn.log

# Test endpoint
curl http://localhost:3000/health

# View database
psql -U user -d face_recognition_db
SELECT * FROM employees;
```

### Need Help?

1. Check this README
2. Review error logs
3. Test with curl/Postman
4. Verify database connection
5. Check `.env` configuration

---

## ✅ Checklist

Before deploying:

- [ ] Database created and configured
- [ ] `.env` file configured
- [ ] Dependencies installed
- [ ] Server starts without errors
- [ ] Health endpoint responds
- [ ] Test face detection works
- [ ] Test registration works
- [ ] Liveness detection tested with photos
- [ ] Attendance logging works
- [ ] CORS configured for frontend
- [ ] Production database configured
- [ ] SSL enabled
- [ ] Backups configured

---

## 🎉 You're Ready!

The backend is now complete and ready to work with your Flutter web app!

**Next steps:**
1. Start the backend: `python main.py`
2. Start Flutter web: `flutter run -d chrome`
3. Test the complete system

**Happy coding! 🚀**
