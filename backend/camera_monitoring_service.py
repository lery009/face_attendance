"""
Camera Monitoring Service
Automatically monitors Dahua cameras for face detection events and logs attendance
"""
import threading
import time
from typing import Dict, Optional
from datetime import datetime
from dahua_face_service import DahuaFaceService
from database import get_db, Camera, Employee, AttendanceLog, Event
import face_recognition as fr
import numpy as np
import cv2
from sqlalchemy.orm import Session


class CameraMonitor:
    """Monitors a single camera for face detection and logs attendance"""

    def __init__(self, camera: Camera, db_session_factory):
        self.camera = camera
        self.db_session_factory = db_session_factory
        self.dahua_service: Optional[DahuaFaceService] = None
        self.is_running = False
        self.known_faces: Dict[str, np.ndarray] = {}
        self.last_recognition: Dict[str, float] = {}  # Prevent duplicate logs
        self.recognition_cooldown = 30  # seconds

    def start(self) -> bool:
        """Start monitoring this camera"""
        try:
            # Initialize Dahua service for this camera
            if self.camera.camera_type != 'rtsp':
                print(f"⚠️ Camera {self.camera.name} is not RTSP type, skipping")
                return False

            # Extract credentials and IP from RTSP URL
            import re
            from urllib.parse import unquote

            # Try to extract username:password@ip from RTSP URL
            # Format: rtsp://username:password@ip:port/path
            creds_match = re.search(r'rtsp://([^:]+):([^@]+)@([0-9.]+):', self.camera.stream_url)

            if creds_match:
                username = unquote(creds_match.group(1))
                password = unquote(creds_match.group(2))
                ip = creds_match.group(3)
                print(f"🔑 Extracted credentials from URL: {username}/***")
            else:
                # Fallback: try to extract just IP
                ip_match = re.search(r'@([0-9.]+):', self.camera.stream_url)
                if not ip_match:
                    print(f"❌ Could not extract IP from {self.camera.stream_url}")
                    return False
                ip = ip_match.group(1)
                username = self.camera.username or 'admin'
                password = self.camera.password or 'admin'
                print(f"🔑 Using credentials: {username}/***")

            print(f"🎥 Starting monitor for camera: {self.camera.name} ({ip})")

            # Initialize Dahua service
            self.dahua_service = DahuaFaceService(ip, username, password)

            # Test connection
            caps = self.dahua_service.get_capabilities()
            if not caps.get('face_analysis_enabled'):
                print(f"⚠️ Face analysis not enabled on {self.camera.name}, enabling...")
                self.dahua_service.enable_face_analysis()

            # Load known faces from database
            self._load_known_faces()

            # Subscribe to face detection events
            self.dahua_service.subscribe_to_face_events(self._on_face_detected)

            self.is_running = True
            print(f"✅ Camera monitor started: {self.camera.name}")
            return True

        except Exception as e:
            print(f"❌ Error starting camera monitor for {self.camera.name}: {e}")
            return False

    def stop(self):
        """Stop monitoring this camera"""
        self.is_running = False
        if self.dahua_service:
            self.dahua_service.stop_event_listener()
        print(f"🛑 Camera monitor stopped: {self.camera.name}")

    def _load_known_faces(self):
        """Load all employee face encodings from database"""
        try:
            db = next(self.db_session_factory())
            employees = db.query(Employee).filter(Employee.embeddings.isnot(None)).all()

            self.known_faces = {}
            for emp in employees:
                try:
                    # Embeddings are stored as JSON list, convert to numpy array
                    if isinstance(emp.embeddings, list):
                        encoding = np.array(emp.embeddings, dtype=np.float64)
                    else:
                        # Fallback for binary format
                        encoding = np.frombuffer(emp.embeddings, dtype=np.float64)

                    if encoding.shape[0] == 128:
                        self.known_faces[emp.employee_id] = encoding
                except Exception as e:
                    print(f"⚠️ Could not load face encoding for {emp.employee_id}: {e}")

            db.close()
            print(f"📋 Loaded {len(self.known_faces)} known faces for {self.camera.name}")

        except Exception as e:
            print(f"❌ Error loading known faces: {e}")

    def _on_face_detected(self, event: Dict):
        """Callback when camera detects a face"""
        try:
            print(f"\n{'='*60}")
            print(f"🎯 FACE DETECTED by {self.camera.name}!")
            print(f"{'='*60}")
            print(f"   Event Code: {event.get('Code', 'Unknown')}")
            print(f"   Event Data: {event}")

            # Get snapshot from camera
            print(f"📸 Requesting snapshot from camera...")
            snapshot = self.dahua_service.get_snapshot()
            if not snapshot:
                print("❌ Failed to get snapshot from camera")
                return

            print(f"   ✅ Snapshot received ({len(snapshot)} bytes)")

            # Save snapshot for debugging
            timestamp = int(time.time())
            snapshot_path = f"/tmp/face_detection_{self.camera.id}_{timestamp}.jpg"
            with open(snapshot_path, 'wb') as f:
                f.write(snapshot)
            print(f"   📁 Snapshot saved: {snapshot_path}")

            # Perform face recognition
            print(f"🔍 Starting face recognition...")
            self._recognize_and_log_attendance(snapshot, timestamp)

        except Exception as e:
            print(f"❌ Error processing face detection event: {e}")
            import traceback
            traceback.print_exc()

    def _recognize_and_log_attendance(self, image_bytes: bytes, timestamp: int):
        """Perform face recognition and log attendance"""
        try:
            print(f"   Step 1: Decoding image...")
            # Decode image
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if image is None:
                print("   ❌ Failed to decode image")
                return

            print(f"   ✅ Image decoded: {image.shape}")

            # Convert to RGB for face_recognition
            print(f"   Step 2: Converting to RGB...")
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

            # Detect faces in image
            print(f"   Step 3: Detecting faces in image...")
            face_locations = fr.face_locations(rgb_image, model='hog')
            print(f"   ✅ Found {len(face_locations)} face location(s)")

            print(f"   Step 4: Extracting face encodings...")
            face_encodings = fr.face_encodings(rgb_image, face_locations)
            print(f"   ✅ Extracted {len(face_encodings)} face encoding(s)")

            if len(face_encodings) == 0:
                print("   ⚠️ No face encodings could be extracted")
                return

            # Try to match each detected face
            print(f"   Step 5: Matching against {len(self.known_faces)} known faces...")
            for idx, face_encoding in enumerate(face_encodings):
                print(f"   \n   Face #{idx + 1}:")
                employee_id = self._match_face(face_encoding)

                if employee_id:
                    # Check cooldown to prevent duplicate logs
                    last_time = self.last_recognition.get(employee_id, 0)
                    time_since_last = time.time() - last_time

                    if time_since_last < self.recognition_cooldown:
                        print(f"      ⏱️ Skipping {employee_id} (cooldown: {int(self.recognition_cooldown - time_since_last)}s remaining)")
                        continue

                    # Log attendance
                    print(f"      ✅ Proceeding to log attendance...")
                    self._log_attendance(employee_id, timestamp, image_bytes)
                    self.last_recognition[employee_id] = time.time()

                else:
                    print("      ❓ Unknown person - no match found")

            print(f"{'='*60}\n")

        except Exception as e:
            print(f"   ❌ Error in face recognition: {e}")
            import traceback
            traceback.print_exc()

    def _match_face(self, face_encoding: np.ndarray) -> Optional[str]:
        """Match a face encoding against known faces"""
        if not self.known_faces:
            print(f"      ⚠️ No known faces loaded to match against")
            return None

        try:
            known_encodings = list(self.known_faces.values())
            known_ids = list(self.known_faces.keys())

            print(f"      Comparing against {len(known_ids)} employees...")

            # Compare with known faces
            matches = fr.compare_faces(known_encodings, face_encoding, tolerance=0.6)
            face_distances = fr.face_distance(known_encodings, face_encoding)

            # Show top 3 matches for debugging
            if len(face_distances) > 0:
                sorted_indices = np.argsort(face_distances)
                print(f"      Top matches:")
                for i in range(min(3, len(sorted_indices))):
                    idx = sorted_indices[i]
                    distance = face_distances[idx]
                    confidence = 1 - distance
                    match_status = "✅ MATCH" if matches[idx] else "❌ No match"
                    print(f"        {i+1}. {known_ids[idx]}: {confidence:.2%} ({match_status}, distance: {distance:.3f})")

                # Check if best match is valid
                best_match_index = sorted_indices[0]
                if matches[best_match_index]:
                    employee_id = known_ids[best_match_index]
                    confidence = 1 - face_distances[best_match_index]
                    print(f"      ✅ RECOGNIZED: {employee_id} (confidence: {confidence:.2%})")
                    return employee_id
                else:
                    print(f"      ❌ Best match {known_ids[best_match_index]} below threshold (confidence: {(1-face_distances[best_match_index]):.2%})")

        except Exception as e:
            print(f"      ❌ Error matching face: {e}")
            import traceback
            traceback.print_exc()

        return None

    def _log_attendance(self, employee_id: str, timestamp: int, image_bytes: bytes):
        """Log attendance in database"""
        try:
            db = next(self.db_session_factory())

            # Get employee
            employee = db.query(Employee).filter(Employee.employee_id == employee_id).first()
            if not employee:
                print(f"❌ Employee {employee_id} not found in database")
                db.close()
                return

            # Create attendance log
            log = AttendanceLog(
                employee_id=employee.id,
                camera_id=self.camera.id,
                timestamp=datetime.fromtimestamp(timestamp),
                status='present',
                confidence=0.95,  # We could calculate actual confidence
            )
            db.add(log)

            # Save snapshot image to database or file system
            # For now, we'll skip saving the image to keep DB small
            # You could upload to S3 or save to disk here

            db.commit()
            print(f"   📝 Attendance logged for {employee.name}")

            db.close()

        except Exception as e:
            print(f"❌ Error logging attendance: {e}")

    def reload_faces(self):
        """Reload known faces from database (call when faces are updated)"""
        self._load_known_faces()


class CameraMonitoringService:
    """Manages monitoring for multiple cameras"""

    def __init__(self):
        self.monitors: Dict[str, CameraMonitor] = {}
        self.lock = threading.Lock()

    def start_camera_monitoring(self, camera: Camera) -> bool:
        """Start monitoring a specific camera"""
        with self.lock:
            if camera.id in self.monitors:
                print(f"⚠️ Camera {camera.name} is already being monitored")
                return True

            monitor = CameraMonitor(camera, get_db)
            if monitor.start():
                self.monitors[camera.id] = monitor
                return True
            return False

    def stop_camera_monitoring(self, camera_id: str):
        """Stop monitoring a specific camera"""
        with self.lock:
            if camera_id in self.monitors:
                self.monitors[camera_id].stop()
                del self.monitors[camera_id]

    def start_all_cameras(self, db: Session):
        """Start monitoring all active cameras"""
        cameras = db.query(Camera).filter(Camera.is_active == True).all()

        print(f"\n🎥 Starting monitoring for {len(cameras)} camera(s)...")

        for camera in cameras:
            self.start_camera_monitoring(camera)

    def stop_all_cameras(self):
        """Stop monitoring all cameras"""
        with self.lock:
            for monitor in self.monitors.values():
                monitor.stop()
            self.monitors.clear()

    def reload_all_faces(self):
        """Reload face encodings for all active monitors"""
        with self.lock:
            for monitor in self.monitors.values():
                monitor.reload_faces()

    def get_monitoring_status(self) -> Dict:
        """Get status of all monitored cameras"""
        with self.lock:
            return {
                camera_id: {
                    "camera_name": monitor.camera.name,
                    "is_running": monitor.is_running,
                    "known_faces_count": len(monitor.known_faces),
                }
                for camera_id, monitor in self.monitors.items()
            }


# Global monitoring service instance
monitoring_service = CameraMonitoringService()
