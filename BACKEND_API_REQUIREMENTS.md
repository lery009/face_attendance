# Backend API Requirements for Web-Based Face Recognition

## Overview
The Flutter app now works on **WEB BROWSER** and sends all face detection/recognition to your backend server.

Your backend must implement these endpoints:

---

## 1. Face Detection + Recognition Endpoint

### **POST** `/api/detect-recognize`

**Purpose:** Detect faces in image, recognize them, and perform liveness detection

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
      "boundingBox": {
        "x": 100,
        "y": 50,
        "width": 200,
        "height": 250
      },
      "name": "John Doe",
      "employeeId": "EMP001",
      "confidence": 0.95,
      "isLive": true
    },
    {
      "boundingBox": {
        "x": 400,
        "y": 60,
        "width": 190,
        "height": 240
      },
      "name": "Unknown",
      "employeeId": "",
      "confidence": 0.0,
      "isLive": false
    }
  ]
}
```

**Backend Processing Steps:**
1. Decode base64 image
2. **Detect faces** using face detection library (e.g., OpenCV, dlib, face-recognition)
3. For each detected face:
   - Extract face crop
   - Generate face embeddings (FaceNet, ArcFace, etc.)
   - **Match against database** using cosine similarity
   - **Liveness detection:** Analyze face for depth, texture, movement patterns
4. Return bounding boxes + recognition results

**Recommended Libraries (Python):**
```python
# Face Detection
import cv2
import dlib
# OR
from face_recognition import face_locations

# Face Recognition
from deepface import DeepFace
# OR
import face_recognition

# Liveness Detection
from tensorflow.keras.models import load_model  # Custom model
# OR use Silent-Face-Anti-Spoofing library
```

---

## 2. Employee Registration with Image Endpoint

### **POST** `/api/employees/register-with-image`

**Purpose:** Register new employee with automatic face extraction

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

**Backend Processing Steps:**
1. Decode base64 image
2. **Detect face** in image
3. **Extract face crop**
4. **Generate embeddings** (512-dimensional vector)
5. **Store in database:**
   - Employee data (name, ID, email, etc.)
   - Face embeddings vector
6. Return success response

---

## 3. Existing Employee Match Endpoint (Keep this)

### **POST** `/api/employees/match`

This endpoint already exists - keep it for backward compatibility.

---

## Passive Liveness Detection (Server-Side)

Your backend should implement **passive liveness detection** to prevent photo attacks:

### Recommended Techniques:

#### Option 1: **Anti-Spoofing Neural Network**
```python
# Use Silent-Face-Anti-Spoofing
from silent_face_anti_spoofing import AntiSpoofPredictor

predictor = AntiSpoofPredictor()
is_real = predictor.predict(face_image)
```

#### Option 2: **Texture Analysis**
- Check for photo artifacts (pixelation, moire patterns)
- Analyze color histograms
- Look for screen reflections

#### Option 3: **Multi-frame Analysis** (Best for walk-through)
- Track face across multiple frames
- Analyze natural movement patterns
- Check for depth/3D structure
- Detect head pose variation

**Implementation Example (Python):**
```python
def check_liveness(face_frames):
    """
    Analyze sequence of frames for natural movement

    Args:
        face_frames: List of face images from consecutive frames

    Returns:
        is_live (bool): True if real person detected
    """
    # Track head pose across frames
    head_poses = [detect_head_pose(frame) for frame in face_frames]

    # Calculate variation
    pose_variation = np.std(head_poses, axis=0)

    # Check for natural movement
    if pose_variation.any() > THRESHOLD:
        return True  # Natural movement detected

    # Check for texture patterns
    texture_score = analyze_texture(face_frames[0])

    if texture_score < PHOTO_THRESHOLD:
        return False  # Likely a photo

    return True
```

---

## Database Schema

Your database needs to store face embeddings:

```sql
CREATE TABLE employees (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    firstname VARCHAR(255),
    lastname VARCHAR(255),
    employee_id VARCHAR(255) UNIQUE,
    department VARCHAR(255),
    email VARCHAR(255),
    embeddings JSON,  -- Store as JSON array of 512 floats
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- For fast similarity search
CREATE INDEX idx_employee_id ON employees(employee_id);
```

**Embeddings Format:**
```json
{
  "embeddings": [0.123, -0.456, 0.789, ..., 0.234]  // 512 values
}
```

---

## Face Matching Logic (Server-Side)

```python
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

def match_face(query_embedding, database_embeddings, threshold=0.6):
    """
    Match face embedding against database

    Args:
        query_embedding: 512-dim vector from detected face
        database_embeddings: List of (employee_id, embedding) tuples
        threshold: Similarity threshold (0-1)

    Returns:
        best_match: (employee_id, confidence) or None
    """
    best_score = 0
    best_employee = None

    for employee_id, db_embedding in database_embeddings:
        # Calculate cosine similarity
        similarity = cosine_similarity(
            [query_embedding],
            [db_embedding]
        )[0][0]

        if similarity > best_score:
            best_score = similarity
            best_employee = employee_id

    # Return match if above threshold
    if best_score > threshold:
        return (best_employee, best_score)

    return None
```

---

## Recommended Technology Stack

### Option 1: **Python + FastAPI** (Recommended)
```python
from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel
import face_recognition
import numpy as np

app = FastAPI()

@app.post("/api/detect-recognize")
async def detect_recognize(request: ImageRequest):
    # Decode image
    image = decode_base64_image(request.image)

    # Detect faces
    face_locations = face_recognition.face_locations(image)
    face_encodings = face_recognition.face_encodings(image, face_locations)

    results = []
    for location, encoding in zip(face_locations, face_encodings):
        # Match against database
        match = match_face_in_db(encoding)

        # Liveness check
        is_live = check_liveness([image])

        results.append({
            "boundingBox": {
                "x": location[3],
                "y": location[0],
                "width": location[1] - location[3],
                "height": location[2] - location[0]
            },
            "name": match['name'] if match else "Unknown",
            "employeeId": match['employee_id'] if match else "",
            "confidence": match['confidence'] if match else 0.0,
            "isLive": is_live
        })

    return {"faces": results}
```

### Option 2: **Node.js + face-api.js**
```javascript
const faceapi = require('face-api.js');
const canvas = require('canvas');

app.post('/api/detect-recognize', async (req, res) => {
  const { image } = req.body;

  // Decode base64
  const img = await canvas.loadImage(Buffer.from(image, 'base64'));

  // Detect faces
  const detections = await faceapi
    .detectAllFaces(img)
    .withFaceLandmarks()
    .withFaceDescriptors();

  // Match and return results
  const results = await Promise.all(
    detections.map(async (detection) => {
      const match = await matchFace(detection.descriptor);
      return {
        boundingBox: detection.detection.box,
        name: match?.name || 'Unknown',
        employeeId: match?.employeeId || '',
        confidence: match?.confidence || 0,
        isLive: await checkLiveness(img, detection)
      };
    })
  );

  res.json({ faces: results });
});
```

---

## Testing Your Backend

### Test with curl:
```bash
# Convert image to base64
BASE64_IMAGE=$(base64 -i test_face.jpg)

# Test detection endpoint
curl -X POST http://localhost:3000/api/detect-recognize \
  -H "Content-Type: application/json" \
  -d "{\"image\": \"$BASE64_IMAGE\"}"
```

### Expected Response:
```json
{
  "faces": [
    {
      "boundingBox": {"x": 120, "y": 80, "width": 180, "height": 220},
      "name": "John Doe",
      "employeeId": "EMP001",
      "confidence": 0.89,
      "isLive": true
    }
  ]
}
```

---

## Performance Optimization

1. **Use GPU acceleration** for face detection (CUDA, OpenVINO)
2. **Cache face embeddings** in memory (Redis)
3. **Use vector database** for fast similarity search (Faiss, Milvus)
4. **Batch processing** if multiple cameras
5. **Async processing** for non-blocking requests

---

## Security Considerations

1. **Rate limiting** - Prevent abuse (max 10 requests/second per IP)
2. **Authentication** - Require API key for requests
3. **HTTPS only** - Encrypt image transmission
4. **Input validation** - Check image size/format
5. **Duplicate prevention** - Block same person checking in twice within 5 minutes

---

## IP Camera Integration (Future)

For IP cameras (RTSP streams):

```python
import cv2

# Connect to IP camera
stream = cv2.VideoCapture('rtsp://camera_ip:554/stream')

while True:
    ret, frame = stream.read()

    # Process frame same as webcam
    result = detect_and_recognize(frame)

    # Mark attendance if recognized
    if result['faces']:
        for face in result['faces']:
            if face['isLive'] and face['name'] != 'Unknown':
                mark_attendance(face['employeeId'])
```

---

## Next Steps

1. ✅ **Implement** `/api/detect-recognize` endpoint
2. ✅ **Implement** `/api/employees/register-with-image` endpoint
3. ✅ **Add liveness detection** (anti-spoofing)
4. ✅ **Test with Flutter web app**
5. ✅ **Deploy backend** to production server
6. ✅ **Configure IP cameras** (if needed)

---

## Questions?

The Flutter app is now ready for web browser. You just need to implement the backend API endpoints as described above.

**Current Frontend Status:** ✅ Ready
**Required Backend Status:** ⏳ Pending implementation
