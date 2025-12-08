"""
Polling-Based Attendance Service
Actively takes snapshots and runs face recognition instead of waiting for camera events
"""
import threading
import time
from typing import Dict, List, Optional
from datetime import datetime, date, time as datetime_time
from database import get_db, Camera, Employee, AttendanceLog, Event, EventParticipant
import face_recognition as fr
import numpy as np
import cv2
from sqlalchemy.orm import Session
import requests
from requests.auth import HTTPDigestAuth
import re
from urllib.parse import unquote
import uuid


class PollingAttendanceMonitor:
    """Polls camera snapshots during active events and logs attendance"""

    def __init__(self, camera: Camera, db_session_factory):
        self.camera = camera
        self.db_session_factory = db_session_factory
        self.is_running = False
        self.known_faces: Dict[str, np.ndarray] = {}
        self.last_recognition: Dict[str, float] = {}  # employee_id -> timestamp
        self.recognition_cooldown = 30  # seconds between same person logs
        self.poll_interval = 3  # seconds between snapshots
        self.session = None
        self.base_url = None
        self.username = None
        self.password = None
        self.polling_thread = None

    def start(self) -> bool:
        """Start polling for this camera"""
        try:
            # Extract credentials and IP from RTSP URL
            if self.camera.camera_type != 'rtsp':
                print(f"⚠️ Camera {self.camera.name} is not RTSP type, skipping")
                return False

            # Parse RTSP URL: rtsp://username:password@ip:port/path
            creds_match = re.search(r'rtsp://([^:]+):([^@]+)@([0-9.]+):', self.camera.stream_url)

            if creds_match:
                self.username = unquote(creds_match.group(1))
                self.password = unquote(creds_match.group(2))
                ip = creds_match.group(3)
                self.base_url = f"http://{ip}:80"
                print(f"🔑 Polling monitor - Extracted credentials: {self.username}/***")
            else:
                print(f"❌ Could not extract credentials from {self.camera.stream_url}")
                return False

            # Setup HTTP session
            self.session = requests.Session()
            self.session.auth = HTTPDigestAuth(self.username, self.password)

            # Disable camera OSD to remove "Unauthorized" messages
            print(f"🔧 Disabling camera OSD display...")
            self._disable_camera_osd()

            # Load known faces
            self._load_known_faces()

            # Start polling thread
            self.is_running = True
            self.polling_thread = threading.Thread(target=self._polling_loop, daemon=True)
            self.polling_thread.start()

            print(f"✅ Polling monitor started: {self.camera.name} (every {self.poll_interval}s)")
            return True

        except Exception as e:
            print(f"❌ Failed to start polling monitor for {self.camera.name}: {e}")
            import traceback
            traceback.print_exc()
            return False

    def stop(self):
        """Stop polling"""
        self.is_running = False
        if self.polling_thread:
            self.polling_thread.join(timeout=5)
        print(f"🛑 Polling monitor stopped: {self.camera.name}")

    def _load_known_faces(self):
        """Load all employee face encodings from database"""
        db = next(self.db_session_factory())
        try:
            employees = db.query(Employee).filter(Employee.embeddings.isnot(None)).all()

            for emp in employees:
                if emp.embeddings and isinstance(emp.embeddings, list):
                    self.known_faces[emp.employee_id] = np.array(emp.embeddings, dtype=np.float64)

            print(f"📋 Loaded {len(self.known_faces)} known faces for polling monitor: {self.camera.name}")
        finally:
            db.close()

    def _get_snapshot(self) -> Optional[bytes]:
        """Get snapshot from camera"""
        try:
            url = f"{self.base_url}/cgi-bin/snapshot.cgi?channel=1"
            response = self.session.get(url, timeout=10)

            if response.status_code == 200:
                return response.content
            else:
                print(f"⚠️ Snapshot failed: HTTP {response.status_code}")
                return None

        except Exception as e:
            print(f"❌ Error getting snapshot: {e}")
            return None

    def _trigger_camera_beep(self):
        """Trigger camera's built-in buzzer/beep for audio feedback"""
        def beep_async():
            """Run beep in separate thread to not block attendance logging"""
            try:
                # Try multiple beep methods

                # Method 1: Alarm output
                try:
                    url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&AlarmOut[0].Mode=1"
                    response = self.session.get(url, timeout=3)
                    if response.status_code == 200:
                        print(f"🔔 Beep triggered (AlarmOut)")
                        time.sleep(0.5)
                        reset_url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&AlarmOut[0].Mode=0"
                        self.session.get(reset_url, timeout=3)
                        return
                except:
                    pass

                # Method 2: Audio alarm
                try:
                    url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&Alarm.0.AudioEnable=true"
                    response = self.session.get(url, timeout=3)
                    if response.status_code == 200:
                        print(f"🔔 Beep triggered (AudioEnable)")
                        return
                except:
                    pass

                # Method 3: Play audio file (some Dahua cameras support this)
                try:
                    url = f"{self.base_url}/cgi-bin/audio.cgi?action=playFile&file=default"
                    response = self.session.get(url, timeout=3)
                    if response.status_code == 200:
                        print(f"🔔 Beep triggered (PlayAudio)")
                        return
                except:
                    pass

                print(f"ℹ️ Camera beep not supported or configured")

            except Exception as e:
                print(f"ℹ️ Camera beep skipped: {e}")

        # Run beep in background thread
        threading.Thread(target=beep_async, daemon=True).start()

    def _disable_camera_osd(self):
        """Disable camera's OSD (On-Screen Display) for face recognition messages"""
        try:
            # Disable face detection OSD overlay on Dahua cameras
            # This removes the "Unauthorized" text from the video feed
            # Try multiple API approaches as different models use different parameters

            # Approach 1: Disable OSD via VideoWidget
            try:
                url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&VideoWidget.0.FaceDetection.Enable=false"
                response = self.session.get(url, timeout=10)
                if response.status_code == 200:
                    print(f"✅ Disabled face detection OSD overlay")
            except:
                pass

            # Approach 2: Disable smart info overlay
            try:
                url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&VideoWidget.0.SmartInfo.Enable=false"
                response = self.session.get(url, timeout=10)
                if response.status_code == 200:
                    print(f"✅ Disabled smart info overlay")
            except:
                pass

            # Approach 3: Disable all video overlays
            try:
                url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&VideoWidget.0.Enable=false"
                response = self.session.get(url, timeout=10)
                if response.status_code == 200:
                    print(f"✅ Disabled video widget overlays")
            except:
                pass

            print(f"ℹ️ OSD configuration attempted (some settings may not be supported by camera)")

        except Exception as e:
            print(f"ℹ️ Camera OSD configuration skipped: {e}")

    def _get_active_events(self) -> List[Event]:
        """Get currently active events"""
        db = next(self.db_session_factory())
        try:
            now = datetime.now()
            current_date = now.date()
            current_time = now.time()

            # Get events that are today and currently ongoing
            events = db.query(Event).filter(
                Event.is_active == True,
                Event.event_date == current_date
            ).all()

            active_events = []
            for event in events:
                # Parse time strings
                if isinstance(event.start_time, str):
                    parts = event.start_time.split(':')
                    start_hour = int(parts[0]) if parts[0] else 0
                    start_minute = int(parts[1]) if len(parts) > 1 else 0
                    if start_hour >= 24:
                        start_hour = 0
                    start_time = datetime_time(start_hour, start_minute)
                else:
                    start_time = event.start_time

                if isinstance(event.end_time, str):
                    parts = event.end_time.split(':')
                    end_hour = int(parts[0]) if parts[0] else 23
                    end_minute = int(parts[1]) if len(parts) > 1 else 59
                    if end_hour >= 24:
                        end_hour = 23
                    end_time = datetime_time(end_hour, end_minute)
                else:
                    end_time = event.end_time

                # Check if current time is within event time
                if start_time <= current_time <= end_time:
                    active_events.append(event)

            return active_events
        finally:
            db.close()

    def _recognize_faces(self, snapshot: bytes) -> List[tuple]:
        """
        Run face recognition on snapshot
        Returns: List of (employee_id, confidence) tuples
        """
        try:
            # Decode image
            nparr = np.frombuffer(snapshot, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                print("⚠️ Failed to decode snapshot")
                return []

            # Convert BGR to RGB
            rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

            # Detect faces - try CNN model for better detection at different angles
            face_locations = fr.face_locations(rgb_img, model='hog')

            if not face_locations:
                # Try CNN model (slower but more accurate for non-frontal faces)
                face_locations = fr.face_locations(rgb_img, model='cnn')

            if not face_locations:
                return []

            # Extract encodings
            face_encodings = fr.face_encodings(rgb_img, face_locations)

            if not face_encodings:
                return []

            recognized = []

            # Match each face
            for face_encoding in face_encodings:
                if not self.known_faces:
                    continue

                known_encodings = list(self.known_faces.values())
                known_ids = list(self.known_faces.keys())

                # Compare faces
                matches = fr.compare_faces(known_encodings, face_encoding, tolerance=0.6)
                face_distances = fr.face_distance(known_encodings, face_encoding)

                if len(face_distances) > 0:
                    best_match_index = np.argmin(face_distances)
                    if matches[best_match_index]:
                        employee_id = known_ids[best_match_index]
                        confidence = 1 - face_distances[best_match_index]
                        recognized.append((employee_id, confidence))

            return recognized

        except Exception as e:
            print(f"❌ Error in face recognition: {e}")
            import traceback
            traceback.print_exc()
            return []

    def _log_attendance(self, employee_id: str, confidence: float, event: Event):
        """Log attendance for recognized employee"""
        db = next(self.db_session_factory())
        try:
            # Get employee
            employee = db.query(Employee).filter(Employee.employee_id == employee_id).first()

            if not employee:
                print(f"⚠️ Employee {employee_id} not found")
                return

            # Check if employee is participant in this event
            participant = db.query(EventParticipant).filter(
                EventParticipant.event_id == event.id,
                EventParticipant.employee_id == employee.employee_id
            ).first()

            if not participant:
                print(f"⚠️ Employee {employee.name} ({employee_id}) is not a participant in event '{event.name}'")
                return

            # Check cooldown
            current_time = time.time()
            last_log_time = self.last_recognition.get(employee_id, 0)

            if current_time - last_log_time < self.recognition_cooldown:
                remaining = int(self.recognition_cooldown - (current_time - last_log_time))
                print(f"⏳ Cooldown active for {employee.name} ({remaining}s remaining)")
                return

            # Log attendance
            attendance = AttendanceLog(
                id=str(uuid.uuid4()),
                employee_id=employee.employee_id,
                event_id=event.id,
                camera_id=str(self.camera.id),
                timestamp=datetime.now(),
                status='present',
                confidence=str(confidence)
            )
            db.add(attendance)

            # Update participant status
            participant.status = 'attended'
            participant.attended_at = datetime.now()

            db.commit()

            # Update cooldown
            self.last_recognition[employee_id] = current_time

            print(f"✅ ATTENDANCE LOGGED: {employee.name} ({employee_id}) at event '{event.name}' - Confidence: {confidence:.2%}")

            # Trigger camera beep for audio feedback
            self._trigger_camera_beep()

        except Exception as e:
            db.rollback()
            print(f"❌ Error logging attendance: {e}")
            import traceback
            traceback.print_exc()
        finally:
            db.close()

    def _polling_loop(self):
        """Main polling loop"""
        print(f"🔄 Polling loop started for {self.camera.name}")

        while self.is_running:
            try:
                # Check for active events
                active_events = self._get_active_events()

                if not active_events:
                    # No active events, sleep and continue
                    time.sleep(self.poll_interval)
                    continue

                # We have active events, take snapshot
                print(f"📸 Taking snapshot ({len(active_events)} active event(s))...")
                snapshot = self._get_snapshot()

                if not snapshot:
                    time.sleep(self.poll_interval)
                    continue

                # Run face recognition
                recognized_faces = self._recognize_faces(snapshot)

                if recognized_faces:
                    print(f"🎯 Recognized {len(recognized_faces)} face(s)")

                    # Log attendance for each recognized face in each active event
                    for employee_id, confidence in recognized_faces:
                        for event in active_events:
                            self._log_attendance(employee_id, confidence, event)
                else:
                    print(f"👤 No recognized faces in snapshot")

            except Exception as e:
                print(f"❌ Error in polling loop: {e}")
                import traceback
                traceback.print_exc()

            # Sleep before next poll
            time.sleep(self.poll_interval)

        print(f"🛑 Polling loop stopped for {self.camera.name}")


class PollingAttendanceService:
    """Manages polling monitors for all active cameras"""

    def __init__(self, db_session_factory):
        self.db_session_factory = db_session_factory
        self.monitors: Dict[str, PollingAttendanceMonitor] = {}

    def start_all(self):
        """Start polling monitors for all active cameras"""
        db = next(self.db_session_factory())
        try:
            cameras = db.query(Camera).filter(Camera.is_active == True).all()

            print(f"\n🎯 Starting polling monitors for {len(cameras)} camera(s)...\n")

            for camera in cameras:
                monitor = PollingAttendanceMonitor(camera, self.db_session_factory)
                if monitor.start():
                    self.monitors[str(camera.id)] = monitor

        finally:
            db.close()

    def stop_all(self):
        """Stop all polling monitors"""
        for monitor in self.monitors.values():
            monitor.stop()
        self.monitors.clear()
