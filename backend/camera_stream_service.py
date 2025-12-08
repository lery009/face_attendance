"""
Camera Streaming Service
Handles live video streaming from RTSP, HTTP, and Webcam sources
"""
import cv2
import numpy as np
import threading
import time
from typing import Dict, Optional
from database import get_db, Camera
import face_recognition as fr


class CameraStreamManager:
    """Manages multiple camera streams"""

    def __init__(self):
        self.active_streams: Dict[str, 'CameraStream'] = {}
        self.lock = threading.Lock()

    def get_stream(self, camera_id: str) -> Optional['CameraStream']:
        """Get or create a camera stream"""
        with self.lock:
            if camera_id in self.active_streams:
                stream = self.active_streams[camera_id]
                if stream.is_active():
                    return stream
                else:
                    # Stream died, remove it
                    del self.active_streams[camera_id]

            # Create new stream
            db = next(get_db())
            try:
                camera = db.query(Camera).filter(Camera.id == camera_id).first()
                if not camera or not camera.is_active:
                    return None

                stream = CameraStream(camera)
                if stream.start():
                    self.active_streams[camera_id] = stream
                    return stream
                return None
            finally:
                db.close()

    def stop_stream(self, camera_id: str):
        """Stop a specific camera stream"""
        with self.lock:
            if camera_id in self.active_streams:
                self.active_streams[camera_id].stop()
                del self.active_streams[camera_id]

    def stop_all(self):
        """Stop all camera streams"""
        with self.lock:
            for stream in self.active_streams.values():
                stream.stop()
            self.active_streams.clear()


class CameraStream:
    """Individual camera stream handler"""

    def __init__(self, camera: Camera):
        self.camera = camera
        self.capture = None
        self.frame = None
        self.running = False
        self.thread = None
        self.last_frame_time = 0
        self.fps = 0
        self.lock = threading.Lock()
        # Face recognition optimization
        self.frame_count = 0
        self.cached_face_data = []  # Cache detected faces for reuse
        self.process_every_n_frames = 15  # Only process face detection every 15 frames (much faster!)

    def start(self) -> bool:
        """Start the camera stream"""
        try:
            # Determine camera source
            if self.camera.camera_type == 'webcam':
                # Use default webcam (0) or parse from stream_url if provided
                source = 0
                if self.camera.stream_url and self.camera.stream_url.isdigit():
                    source = int(self.camera.stream_url)
            elif self.camera.camera_type == 'rtsp':
                # RTSP URL
                source = self.camera.stream_url
                # Add credentials if provided
                if self.camera.username and self.camera.password:
                    # Format: rtsp://username:password@ip:port/path
                    parts = source.replace('rtsp://', '').split('/', 1)
                    host_part = parts[0]
                    path_part = '/' + parts[1] if len(parts) > 1 else ''
                    source = f'rtsp://{self.camera.username}:{self.camera.password}@{host_part}{path_part}'
            elif self.camera.camera_type == 'http':
                # HTTP/MJPEG stream
                source = self.camera.stream_url
            else:
                print(f"❌ Unknown camera type: {self.camera.camera_type}")
                return False

            # Open video capture
            self.capture = cv2.VideoCapture(source)

            # Set buffer size to 1 to reduce latency
            self.capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            # Check if camera opened successfully
            if not self.capture.isOpened():
                print(f"❌ Failed to open camera: {self.camera.name}")
                return False

            # Read first frame to verify
            ret, frame = self.capture.read()
            if not ret or frame is None:
                print(f"❌ Failed to read frame from camera: {self.camera.name}")
                self.capture.release()
                return False

            self.frame = frame
            self.running = True

            # Start capture thread
            self.thread = threading.Thread(target=self._capture_loop, daemon=True)
            self.thread.start()

            print(f"✅ Camera stream started: {self.camera.name}")
            return True

        except Exception as e:
            print(f"❌ Error starting camera {self.camera.name}: {e}")
            if self.capture:
                self.capture.release()
            return False

    def _capture_loop(self):
        """Continuously capture frames from camera"""
        frame_count = 0
        start_time = time.time()

        while self.running:
            try:
                ret, frame = self.capture.read()

                if not ret or frame is None:
                    print(f"⚠️ Failed to read frame from {self.camera.name}")
                    time.sleep(0.1)
                    continue

                with self.lock:
                    self.frame = frame
                    self.last_frame_time = time.time()

                # Calculate FPS
                frame_count += 1
                if frame_count % 30 == 0:
                    elapsed = time.time() - start_time
                    self.fps = frame_count / elapsed if elapsed > 0 else 0

                # Small delay to prevent overwhelming CPU
                time.sleep(0.01)

            except Exception as e:
                print(f"❌ Error in capture loop for {self.camera.name}: {e}")
                time.sleep(0.5)

    def get_frame(self) -> Optional[np.ndarray]:
        """Get the latest frame"""
        with self.lock:
            if self.frame is not None:
                return self.frame.copy()
        return None

    def get_jpeg_frame(self, quality: int = 80) -> Optional[bytes]:
        """Get the latest frame as JPEG bytes"""
        frame = self.get_frame()
        if frame is None:
            return None

        # Encode frame as JPEG
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), quality]
        ret, buffer = cv2.imencode('.jpg', frame, encode_param)

        if ret:
            return buffer.tobytes()
        return None

    def get_frame_with_faces(self, known_faces: Dict[str, np.ndarray]) -> Optional[bytes]:
        """
        Get frame with face detection boxes and names (OPTIMIZED with frame skipping)
        known_faces: dict of {employee_id: face_encoding}
        """
        frame = self.get_frame()
        if frame is None:
            return None

        self.frame_count += 1

        # Only process face detection every N frames for performance
        if self.frame_count % self.process_every_n_frames == 0:
            # Resize frame VERY aggressively for faster processing
            small_frame = cv2.resize(frame, (0, 0), fx=0.2, fy=0.2)  # Even smaller!
            rgb_small_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)

            # Find faces in frame using faster model
            face_locations = fr.face_locations(rgb_small_frame, model="hog", number_of_times_to_upsample=0)  # HOG with no upsampling = fastest
            face_encodings = fr.face_encodings(rgb_small_frame, face_locations, num_jitters=1)  # Less jittering = faster

            # Scale back up and cache the results
            self.cached_face_data = []
            for (top, right, bottom, left), face_encoding in zip(face_locations, face_encodings):
                # Scale back up face locations (0.2 -> 1.0 = multiply by 5)
                scaled_location = (top * 5, right * 5, bottom * 5, left * 5)
                self.cached_face_data.append((scaled_location, face_encoding))

        # Draw boxes and labels using cached face data
        for (top, right, bottom, left), face_encoding in self.cached_face_data:

            # Try to match face
            name = "Unknown"
            color = (0, 0, 255)  # Red for unknown

            if known_faces:
                try:
                    # Compare with known faces
                    known_faces_list = list(known_faces.values())

                    # Ensure face_encoding is the right shape
                    if len(face_encoding.shape) == 1 and face_encoding.shape[0] == 128:
                        matches = fr.compare_faces(known_faces_list, face_encoding, tolerance=0.6)
                        face_distances = fr.face_distance(known_faces_list, face_encoding)

                        if len(face_distances) > 0:
                            best_match_index = np.argmin(face_distances)
                            if matches[best_match_index]:
                                employee_id = list(known_faces.keys())[best_match_index]
                                name = employee_id
                                color = (0, 255, 0)  # Green for recognized
                except Exception as e:
                    print(f"Error matching face: {e}")
                    # Continue with Unknown label

            # Draw rectangle
            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)

            # Draw label background
            cv2.rectangle(frame, (left, bottom - 35), (right, bottom), color, cv2.FILLED)

            # Draw label text
            cv2.putText(frame, name, (left + 6, bottom - 6),
                       cv2.FONT_HERSHEY_DUPLEX, 0.6, (255, 255, 255), 1)

        # Add FPS counter
        cv2.putText(frame, f"FPS: {self.fps:.1f}", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # Encode as JPEG with lower quality for faster streaming
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 60]  # Lower quality = faster
        ret, buffer = cv2.imencode('.jpg', frame, encode_param)
        if ret:
            return buffer.tobytes()
        return None

    def is_active(self) -> bool:
        """Check if stream is still active"""
        if not self.running:
            return False

        # Check if we've received a frame recently (within 5 seconds)
        if time.time() - self.last_frame_time > 5:
            return False

        return True

    def stop(self):
        """Stop the camera stream"""
        self.running = False

        if self.thread:
            self.thread.join(timeout=2)

        if self.capture:
            self.capture.release()

        print(f"🛑 Camera stream stopped: {self.camera.name}")


# Global stream manager instance
stream_manager = CameraStreamManager()
