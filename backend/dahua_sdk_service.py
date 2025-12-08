"""
Dahua Camera SDK Service
Handles communication with Dahua cameras via HTTP API
Provides face detection, recognition, and camera control features
"""
import requests
from requests.auth import HTTPDigestAuth
import json
from typing import Dict, List, Optional, Any
import base64
from datetime import datetime


class DahuaSDKService:
    """Service for interacting with Dahua camera's native SDK/API"""

    def __init__(self, ip: str, username: str, password: str, port: int = 80):
        self.ip = ip
        self.username = username
        self.password = password
        self.port = port
        self.base_url = f"http://{ip}:{port}"
        self.auth = HTTPDigestAuth(username, password)
        self.session = requests.Session()
        self.session.auth = self.auth

    def _make_request(self, endpoint: str, method: str = "GET", data: Optional[Dict] = None) -> Optional[Dict]:
        """Make HTTP request to camera API"""
        try:
            url = f"{self.base_url}{endpoint}"

            if method == "GET":
                response = self.session.get(url, timeout=10)
            elif method == "POST":
                response = self.session.post(url, json=data, timeout=10)
            elif method == "PUT":
                response = self.session.put(url, json=data, timeout=10)
            else:
                return None

            if response.status_code in [200, 201]:
                # Try to parse JSON response
                try:
                    return response.json()
                except:
                    return {"success": True, "data": response.text}
            else:
                print(f"❌ Request failed: {response.status_code} - {response.text}")
                return None

        except Exception as e:
            print(f"❌ Error making request to {endpoint}: {e}")
            return None

    def test_connection(self) -> bool:
        """Test connection to camera"""
        try:
            # Try to get system info
            response = self.session.get(f"{self.base_url}/cgi-bin/magicBox.cgi?action=getSystemInfo", timeout=5)

            if response.status_code == 200:
                print(f"✅ Successfully connected to Dahua camera at {self.ip}")
                print(f"📋 System Info: {response.text[:200]}")
                return True
            else:
                print(f"❌ Failed to connect: {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ Connection test failed: {e}")
            return False

    def get_device_info(self) -> Optional[Dict]:
        """Get detailed device information"""
        try:
            response = self.session.get(f"{self.base_url}/cgi-bin/magicBox.cgi?action=getDeviceType", timeout=5)

            if response.status_code == 200:
                # Parse response
                info = {}
                for line in response.text.split('\n'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        info[key.strip()] = value.strip()

                return info
            return None

        except Exception as e:
            print(f"❌ Error getting device info: {e}")
            return None

    def get_face_detect_capabilities(self) -> Optional[Dict]:
        """Check if camera supports face detection"""
        try:
            # Query face detection capabilities
            response = self.session.get(
                f"{self.base_url}/cgi-bin/configManager.cgi?action=getCaps&name=FaceDetect",
                timeout=5
            )

            if response.status_code == 200:
                print(f"✅ Face Detection Capabilities: {response.text}")
                return {"supported": True, "capabilities": response.text}
            else:
                print(f"⚠️ Face detection may not be supported")
                return {"supported": False}

        except Exception as e:
            print(f"❌ Error checking face detection: {e}")
            return None

    def enable_face_detection(self, channel: int = 0) -> bool:
        """Enable face detection on camera"""
        try:
            # Enable face detection
            params = {
                "action": "setConfig",
                "name": f"FaceDetect[{channel}]"
            }

            config = {
                "Enable": True,
                "DrawFrame": True,  # Draw boxes around detected faces
            }

            # Build CGI URL with parameters
            config_str = "&".join([f"FaceDetect[{channel}].{k}={v}" for k, v in config.items()])
            url = f"{self.base_url}/cgi-bin/configManager.cgi?action=setConfig&{config_str}"

            response = self.session.get(url, timeout=5)

            if response.status_code == 200 and "OK" in response.text:
                print(f"✅ Face detection enabled on channel {channel}")
                return True
            else:
                print(f"❌ Failed to enable face detection: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error enabling face detection: {e}")
            return False

    def get_face_detection_config(self, channel: int = 0) -> Optional[Dict]:
        """Get current face detection configuration"""
        try:
            response = self.session.get(
                f"{self.base_url}/cgi-bin/configManager.cgi?action=getConfig&name=FaceDetect[{channel}]",
                timeout=5
            )

            if response.status_code == 200:
                # Parse response into dict
                config = {}
                for line in response.text.split('\n'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()

                return config
            return None

        except Exception as e:
            print(f"❌ Error getting face detection config: {e}")
            return None

    def subscribe_face_detection_events(self) -> bool:
        """Subscribe to face detection events from camera"""
        try:
            # Subscribe to events (this is typically a long-polling connection)
            url = f"{self.base_url}/cgi-bin/eventManager.cgi?action=attach&codes=[FaceDetection]"

            print(f"📡 Subscribing to face detection events...")
            response = self.session.get(url, timeout=5, stream=True)

            if response.status_code == 200:
                print(f"✅ Successfully subscribed to face detection events")
                return True
            else:
                print(f"❌ Failed to subscribe: {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ Error subscribing to events: {e}")
            return False

    def get_face_recognition_capabilities(self) -> Optional[Dict]:
        """Check if camera supports face recognition (not just detection)"""
        try:
            # Query face recognition capabilities
            response = self.session.get(
                f"{self.base_url}/cgi-bin/configManager.cgi?action=getCaps&name=FaceRecognition",
                timeout=5
            )

            if response.status_code == 200:
                print(f"✅ Face Recognition Capabilities: {response.text}")
                return {"supported": True, "capabilities": response.text}
            else:
                print(f"⚠️ Face recognition may not be supported")
                return {"supported": False}

        except Exception as e:
            print(f"❌ Error checking face recognition: {e}")
            return None

    def register_face(self, person_id: str, person_name: str, image_data: bytes) -> bool:
        """Register a face in camera's database"""
        try:
            # Encode image to base64
            image_base64 = base64.b64encode(image_data).decode('utf-8')

            # Register face via camera API
            url = f"{self.base_url}/cgi-bin/faceLib.cgi?action=insert"

            data = {
                "PersonID": person_id,
                "PersonName": person_name,
                "FaceImage": image_base64,
            }

            response = self.session.post(url, json=data, timeout=10)

            if response.status_code == 200 and "OK" in response.text:
                print(f"✅ Face registered: {person_name} (ID: {person_id})")
                return True
            else:
                print(f"❌ Failed to register face: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error registering face: {e}")
            return False

    def delete_face(self, person_id: str) -> bool:
        """Delete a face from camera's database"""
        try:
            url = f"{self.base_url}/cgi-bin/faceLib.cgi?action=remove&PersonID={person_id}"

            response = self.session.get(url, timeout=5)

            if response.status_code == 200 and "OK" in response.text:
                print(f"✅ Face deleted: {person_id}")
                return True
            else:
                print(f"❌ Failed to delete face: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error deleting face: {e}")
            return False

    def get_face_library(self) -> Optional[List[Dict]]:
        """Get all registered faces from camera"""
        try:
            url = f"{self.base_url}/cgi-bin/faceLib.cgi?action=getAll"

            response = self.session.get(url, timeout=5)

            if response.status_code == 200:
                # Parse response
                try:
                    faces = response.json()
                    return faces
                except:
                    print(f"📋 Face library data: {response.text}")
                    return []
            else:
                print(f"❌ Failed to get face library: {response.text}")
                return None

        except Exception as e:
            print(f"❌ Error getting face library: {e}")
            return None

    def get_snapshot(self, channel: int = 1) -> Optional[bytes]:
        """Get a snapshot image from camera"""
        try:
            url = f"{self.base_url}/cgi-bin/snapshot.cgi?channel={channel}"

            response = self.session.get(url, timeout=10)

            if response.status_code == 200:
                print(f"✅ Snapshot captured from channel {channel}")
                return response.content
            else:
                print(f"❌ Failed to get snapshot: {response.status_code}")
                return None

        except Exception as e:
            print(f"❌ Error getting snapshot: {e}")
            return None

    def get_all_capabilities(self) -> Dict[str, Any]:
        """Get comprehensive overview of camera capabilities"""
        print(f"\n🔍 Checking Dahua camera capabilities at {self.ip}...")

        capabilities = {
            "connection": self.test_connection(),
            "device_info": self.get_device_info(),
            "face_detection": self.get_face_detect_capabilities(),
            "face_recognition": self.get_face_recognition_capabilities(),
        }

        return capabilities


def test_dahua_camera(ip: str, username: str, password: str):
    """Test Dahua camera SDK functionality"""
    print(f"\n{'='*60}")
    print(f"🎥 DAHUA CAMERA SDK TEST")
    print(f"{'='*60}\n")

    sdk = DahuaSDKService(ip, username, password)

    # Test connection
    print("\n1️⃣ Testing Connection...")
    if not sdk.test_connection():
        print("❌ Cannot connect to camera. Check IP address and credentials.")
        return

    # Get device info
    print("\n2️⃣ Getting Device Information...")
    device_info = sdk.get_device_info()
    if device_info:
        print("📋 Device Info:")
        for key, value in device_info.items():
            print(f"   {key}: {value}")

    # Check capabilities
    print("\n3️⃣ Checking Camera Capabilities...")
    capabilities = sdk.get_all_capabilities()

    print("\n" + "="*60)
    print("📊 CAPABILITY SUMMARY:")
    print("="*60)
    print(f"✓ Connection: {'✅ Working' if capabilities['connection'] else '❌ Failed'}")
    print(f"✓ Device Info: {'✅ Available' if capabilities['device_info'] else '❌ Not Available'}")
    print(f"✓ Face Detection: {'✅ Supported' if capabilities['face_detection'] and capabilities['face_detection'].get('supported') else '❌ Not Supported'}")
    print(f"✓ Face Recognition: {'✅ Supported' if capabilities['face_recognition'] and capabilities['face_recognition'].get('supported') else '❌ Not Supported'}")
    print("="*60 + "\n")

    # Test snapshot
    print("\n4️⃣ Testing Snapshot Capture...")
    snapshot = sdk.get_snapshot()
    if snapshot:
        # Save snapshot to file
        with open('/tmp/dahua_snapshot.jpg', 'wb') as f:
            f.write(snapshot)
        print(f"✅ Snapshot saved to /tmp/dahua_snapshot.jpg ({len(snapshot)} bytes)")

    # Test face detection config
    print("\n5️⃣ Getting Face Detection Configuration...")
    face_config = sdk.get_face_detection_config()
    if face_config:
        print("📋 Face Detection Config:")
        for key, value in face_config.items():
            print(f"   {key}: {value}")

    return sdk


if __name__ == "__main__":
    # Test with camera credentials
    CAMERA_IP = "192.168.2.193"
    USERNAME = "admin"
    PASSWORD = "admin@2025"

    test_dahua_camera(CAMERA_IP, USERNAME, PASSWORD)
