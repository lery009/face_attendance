"""
Dahua Face Recognition Service
Integrates Dahua camera's built-in face detection with our face recognition system
"""
import requests
from requests.auth import HTTPDigestAuth
import json
import threading
import time
from typing import Dict, List, Optional, Callable
import cv2
import numpy as np


class DahuaFaceService:
    """
    Service to integrate Dahua camera's built-in face detection with our system.

    What the camera CAN do via HTTP API:
    - Face detection with anti-spoofing
    - Feature extraction (Age, Sex, Glasses, Emotion)
    - Take snapshots when faces detected
    - Real-time event streaming
    - Face quality filtering

    What requires native SDK (port 37777):
    - Direct access to face database
    - Face registration in camera
    - Face matching using camera's database

    Our hybrid approach:
    - Use camera's hardware-accelerated face DETECTION
    - Get high-quality snapshots from camera
    - Perform face RECOGNITION using our backend
    - Best performance and flexibility
    """

    def __init__(self, ip: str, username: str, password: str, port: int = 80):
        self.ip = ip
        self.username = username
        self.password = password
        self.port = port
        self.base_url = f"http://{ip}:{port}"
        self.auth = HTTPDigestAuth(username, password)
        self.session = requests.Session()
        self.session.auth = self.auth

        # Event streaming
        self.event_thread = None
        self.event_running = False
        self.event_callbacks = []

    def get_face_analysis_config(self) -> Optional[Dict]:
        """Get current face analysis configuration"""
        try:
            response = self.session.get(
                f"{self.base_url}/cgi-bin/configManager.cgi?action=getConfig&name=VideoAnalyseRule",
                timeout=5
            )

            if response.status_code == 200:
                # Parse response into dict
                config = {}
                for line in response.text.split('\n'):
                    if '=' in line and 'VideoAnalyseRule[0][0]' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()

                return config
            return None

        except Exception as e:
            print(f"❌ Error getting face analysis config: {e}")
            return None

    def enable_face_analysis(self, channel: int = 0) -> bool:
        """Enable face analysis on the camera"""
        try:
            # Enable face analysis with optimal settings
            params = [
                f"VideoAnalyseRule[{channel}][0].Enable=true",
                f"VideoAnalyseRule[{channel}][0].Config.FaceAntifakeLevel=1",  # Anti-spoofing
                f"VideoAnalyseRule[{channel}][0].Config.MinQuality=50",  # Minimum face quality
                f"VideoAnalyseRule[{channel}][0].EventHandler.SnapshotEnable=true",  # Take snapshots
                f"VideoAnalyseRule[{channel}][0].EventHandler.SnapshotTimes=1",
            ]

            config_str = "&".join(params)
            url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&{config_str}"

            response = self.session.get(url, timeout=5)

            if response.status_code == 200 and "OK" in response.text:
                print(f"✅ Face analysis enabled on channel {channel}")
                return True
            else:
                print(f"❌ Failed to enable face analysis: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error enabling face analysis: {e}")
            return False

    def get_snapshot(self, channel: int = 1) -> Optional[bytes]:
        """Get a snapshot from camera"""
        try:
            url = f"{self.base_url}/cgi-bin/snapshot.cgi?channel={channel}"
            response = self.session.get(url, timeout=10)

            if response.status_code == 200:
                return response.content
            return None

        except Exception as e:
            print(f"❌ Error getting snapshot: {e}")
            return None

    def subscribe_to_face_events(self, callback: Callable[[Dict], None]):
        """
        Subscribe to real-time face detection events from camera.

        Args:
            callback: Function to call when face is detected. Receives event data dict.
        """
        self.event_callbacks.append(callback)

        if not self.event_running:
            self.event_running = True
            self.event_thread = threading.Thread(target=self._event_loop, daemon=True)
            self.event_thread.start()
            print("📡 Started face detection event listener")

    def _event_loop(self):
        """Background thread that listens for face detection events"""
        connection_attempts = 0
        while self.event_running:
            try:
                connection_attempts += 1
                # Subscribe to multiple event codes to catch any face-related events
                event_codes = "FaceDetection,FaceRecognition,AccessControl,VideoAnalyse"
                url = f"{self.base_url}/cgi-bin/eventManager.cgi?action=attach&codes=[{event_codes}]"

                print(f"📡 Connecting to camera event stream (attempt #{connection_attempts})...")
                print(f"   URL: {url}")
                print(f"   Auth: {self.username}/***")
                response = self.session.get(url, timeout=30, stream=True)

                if response.status_code == 200:
                    print(f"✅ Connected to face detection events (status {response.status_code})")
                    print(f"   Listening for events: {event_codes}")

                    line_count = 0
                    for line in response.iter_lines():
                        if not self.event_running:
                            break

                        line_count += 1

                        if line:
                            decoded_line = line.decode('utf-8', errors='ignore')

                            # Log ALL events for debugging
                            print(f"📨 [Line {line_count}] Raw event: {decoded_line[:200]}")

                            # Check if it's a face-related event
                            is_face_event = any(code in decoded_line for code in [
                                'Code=FaceDetection',
                                'Code=FaceRecognition',
                                'Code=AccessControl',
                                'Code=VideoAnalyse',
                                'Code=FaceAnalysis'
                            ])

                            if is_face_event:
                                print(f"   ✅ MATCHED face event!")
                                event_data = self._parse_event(decoded_line)

                                # Notify all callbacks
                                for callback in self.event_callbacks:
                                    try:
                                        callback(event_data)
                                    except Exception as e:
                                        print(f"❌ Error in event callback: {e}")
                                        import traceback
                                        traceback.print_exc()
                            else:
                                print(f"   ⚠️ Non-face event (ignored)")
                        else:
                            # Empty line (keepalive)
                            if line_count % 10 == 0:  # Log every 10th keepalive
                                print(f"💓 Keepalive (line {line_count})")

            except requests.Timeout:
                if self.event_running:
                    print(f"⏱️ Event connection timeout after {connection_attempts} attempts, reconnecting...")
                    time.sleep(5)
            except Exception as e:
                if self.event_running:
                    print(f"❌ Event stream error (attempt #{connection_attempts}): {e}")
                    import traceback
                    traceback.print_exc()
                    time.sleep(5)

    def _parse_event(self, event_line: str) -> Dict:
        """Parse event data from camera"""
        event_data = {
            "timestamp": time.time(),
            "raw": event_line,
        }

        # Parse key-value pairs from event
        for part in event_line.split(';'):
            if '=' in part:
                key, value = part.split('=', 1)
                event_data[key.strip()] = value.strip()

        return event_data

    def stop_event_listener(self):
        """Stop listening for events"""
        self.event_running = False
        if self.event_thread:
            self.event_thread.join(timeout=5)
        print("🛑 Stopped face detection event listener")

    def get_capabilities(self) -> Dict:
        """Get camera face detection capabilities summary"""
        config = self.get_face_analysis_config()

        capabilities = {
            "face_analysis_enabled": False,
            "anti_spoofing": False,
            "feature_detection": [],
            "min_quality": 0,
            "recognize_distance": 0,
        }

        if config:
            enabled = config.get("table.VideoAnalyseRule[0][0].Enable", "false")
            capabilities["face_analysis_enabled"] = enabled.lower() == "true"

            antifake = config.get("table.VideoAnalyseRule[0][0].Config.FaceAntifakeLevel", "0")
            capabilities["anti_spoofing"] = int(antifake) > 0

            # Parse feature list
            features = []
            for i in range(10):
                feature = config.get(f"table.VideoAnalyseRule[0][0].Config.FeatureList[{i}]")
                if feature:
                    features.append(feature)
            capabilities["feature_detection"] = features

            min_quality = config.get("table.VideoAnalyseRule[0][0].Config.MinQuality", "0")
            capabilities["min_quality"] = int(min_quality)

            distance = config.get("table.VideoAnalyseRule[0][0].Config.RecognizeDistance", "0")
            capabilities["recognize_distance"] = int(distance)

        return capabilities


def test_dahua_face_service():
    """Test Dahua face service"""
    print("🎥 Testing Dahua Face Recognition Service\n")
    print("="*60)

    service = DahuaFaceService("192.168.2.193", "admin", "admin@2025")

    # Get capabilities
    print("\n1️⃣ Checking Face Analysis Capabilities...")
    caps = service.get_capabilities()
    print(f"   Face Analysis: {'✅ Enabled' if caps['face_analysis_enabled'] else '❌ Disabled'}")
    print(f"   Anti-Spoofing: {'✅ Yes' if caps['anti_spoofing'] else '❌ No'}")
    print(f"   Features: {', '.join(caps['feature_detection'])}")
    print(f"   Min Quality: {caps['min_quality']}")
    print(f"   Recognize Distance: {caps['recognize_distance']}cm")

    # Test snapshot
    print("\n2️⃣ Testing Snapshot...")
    snapshot = service.get_snapshot()
    if snapshot:
        with open('/tmp/face_snapshot.jpg', 'wb') as f:
            f.write(snapshot)
        print(f"   ✅ Snapshot saved ({len(snapshot)} bytes)")

        # Try to detect faces in snapshot using OpenCV
        import cv2
        nparr = np.frombuffer(snapshot, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is not None:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
            faces = face_cascade.detectMultiScale(gray, 1.1, 4)
            print(f"   🔍 Detected {len(faces)} face(s) in snapshot")

    # Test event subscription
    print("\n3️⃣ Testing Event Subscription...")
    print("   📡 Subscribing to face detection events...")
    print("   👤 Please walk in front of the camera to test...")

    def on_face_detected(event):
        print(f"\n   🎯 FACE DETECTED!")
        print(f"      Event: {event.get('Code', 'Unknown')}")
        print(f"      Time: {event.get('timestamp', 0)}")

        # Get snapshot when face detected
        snapshot = service.get_snapshot()
        if snapshot:
            filename = f"/tmp/face_event_{int(time.time())}.jpg"
            with open(filename, 'wb') as f:
                f.write(snapshot)
            print(f"      📸 Saved snapshot: {filename}")

    service.subscribe_to_face_events(on_face_detected)

    # Wait for events
    try:
        print("   ⏱️ Listening for 30 seconds...")
        time.sleep(30)
    except KeyboardInterrupt:
        print("\n   ⏸️ Interrupted by user")

    service.stop_event_listener()

    print("\n" + "="*60)
    print("✅ Test complete!")


if __name__ == "__main__":
    test_dahua_face_service()
