# Dahua DHI-ASA3223A-W Camera SDK Integration Summary

## Camera Information
- **Model**: DHI-ASA3223A-W (Access Control Camera)
- **IP Address**: 192.168.2.193
- **Firmware**: 3.003.0000000.4.R (build: 2025-04-17)
- **Hardware**: 1.00
- **Processor**: FREYJA

## What We Discovered

### ✅ Camera DOES Support (via HTTP API):

1. **Face Analysis/Detection**
   - Hardware-accelerated face detection
   - Anti-spoofing detection (FaceAntifakeLevel: 1)
   - Face quality filtering (MinQuality: 50)
   - Recognition distance: 150cm

2. **Feature Extraction**
   - Age estimation
   - Gender detection
   - Glasses detection
   - Emotion recognition
   - Helmet detection

3. **Snapshot Capability**
   - High-quality snapshots on demand
   - Automatic snapshot when face detected
   - Full resolution images

4. **Real-time Events**
   - Face detection event streaming
   - Long-polling HTTP connection
   - Event notifications when faces detected

5. **Configuration**
   - Enable/disable face analysis
   - Adjust detection sensitivity
   - Configure event handlers
   - Set time schedules

### ❌ Limited/Not Available (via HTTP API):

1. **Face Database Management**
   - Cannot register faces directly in camera's database via HTTP
   - Cannot access camera's internal face library
   - Cannot perform face matching using camera's database

2. **Face Recognition**
   - Camera can DETECT faces but doesn't expose face RECOGNITION API via HTTP
   - Face matching requires native SDK (port 37777) or DSS platform

## Our Solution: Hybrid Approach

### Best of Both Worlds

We combine the camera's hardware capabilities with our backend intelligence:

```
Camera (Hardware)              →        Our Backend (Software)
├─ Face Detection                       ├─ Face Recognition
├─ Anti-spoofing                       ├─ Face Database
├─ Feature Extraction                  ├─ Attendance Logging
├─ High-Quality Snapshots              ├─ Event Management
└─ Real-time Events                    └─ Reporting
```

### How It Works

1. **Face Detection**: Camera uses hardware to detect faces (fast, efficient)
2. **Snapshot**: Camera takes high-quality snapshot when face detected
3. **Event**: Camera sends real-time event to our backend
4. **Recognition**: Our backend performs face recognition using our database
5. **Logging**: System logs attendance and creates records

### Advantages

✅ **Performance**: Hardware-accelerated detection is much faster than software
✅ **Reliability**: Anti-spoofing prevents fake faces
✅ **Flexibility**: We control the face database and recognition logic
✅ **Integration**: Easy to integrate with our existing system
✅ **Cost**: No need for expensive Dahua DSS platform

## API Endpoints We Use

### 1. Configuration
```
GET /cgi-bin/configManager.cgi?action=getConfig&name=VideoAnalyseRule
- Get face analysis configuration

GET /cgi-bin/configManager.cgi?action=setConfig&VideoAnalyseRule[0][0].Enable=true
- Enable face analysis
```

### 2. Snapshot
```
GET /cgi-bin/snapshot.cgi?channel=1
- Get snapshot from camera
```

### 3. Events
```
GET /cgi-bin/eventManager.cgi?action=attach&codes=[FaceDetection]
- Subscribe to face detection events (long-polling)
```

### 4. System Info
```
GET /cgi-bin/magicBox.cgi?action=getSystemInfo
- Get camera system information
```

## Authentication

The camera uses **HTTP Digest Authentication**:
- Username: admin
- Password: admin@2025
- Port: 80 (HTTP)
- RTSP Port: 554 (for video streaming)

## Files Created

1. **dahua_sdk_service.py** - Basic HTTP API wrapper
2. **dahua_face_service.py** - Face detection integration service
3. **test_dahua_camera.py** - Connection and capability test
4. **test_asa_endpoints.py** - API endpoint exploration
5. **explore_face_apis.py** - Face API discovery

## Next Steps

To fully integrate with our system, we need to:

1. ✅ Connect to camera's event stream
2. ✅ Listen for face detection events
3. ✅ Capture snapshots when faces detected
4. ⬜ Perform face recognition on snapshots
5. ⬜ Log attendance records
6. ⬜ Update frontend to show camera status
7. ⬜ Add real-time notifications

## Limitations

- Cannot use camera's internal face database (requires native SDK)
- HTTP API is read-only for most face features
- Event streaming is one-way (camera → backend)
- No way to trigger actions on camera (door unlock, relay control) via HTTP

## For Advanced Features

If you need to:
- Register faces in camera's hardware database
- Use camera's built-in face matching
- Control door locks/relays
- Access full SDK features

You will need:
- **Dahua SDK** (C/C++/Python wrapper) for port 37777
- Or **Dahua DSS Platform** (their VMS software)
- Or **Third-party SDK wrappers** (dav_client, etc.)

However, for face recognition attendance system, our hybrid approach provides **better flexibility and performance** than using the camera's limited database.
