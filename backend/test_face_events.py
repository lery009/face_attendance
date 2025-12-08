"""
Test subscribing to face detection events from Dahua camera
"""
import requests
from requests.auth import HTTPDigestAuth
import json
import time

CAMERA_IP = "192.168.2.193"
USERNAME = "admin"
PASSWORD = "admin@2025"

base_url = f"http://{CAMERA_IP}"
auth = HTTPDigestAuth(USERNAME, PASSWORD)

print("🎥 Testing Face Detection Events\n")
print("="*60)

# Subscribe to face detection events
print("📡 Subscribing to FaceRecognition events...")

try:
    # The eventManager.cgi endpoint is used to subscribe to events
    # We'll try multiple event codes
    event_codes = [
        "FaceRecognition",
        "FaceDetection",
        "FaceAnalysis",
        "VideoAnalyse",
        "AccessControl",
    ]

    for event_code in event_codes:
        print(f"\n🔍 Trying event code: {event_code}")
        url = f"{base_url}/cgi-bin/eventManager.cgi?action=attach&codes=[{event_code}]"

        try:
            # This is a long-polling connection - it will stay open
            response = requests.get(url, auth=auth, timeout=10, stream=True)

            print(f"   Status: {response.status_code}")

            if response.status_code == 200:
                print(f"   ✅ Successfully subscribed to {event_code}!")
                print(f"   📥 Waiting for events (10 seconds)...")

                # Read events for 10 seconds
                start_time = time.time()
                for line in response.iter_lines():
                    if time.time() - start_time > 10:
                        break

                    if line:
                        decoded_line = line.decode('utf-8', errors='ignore')
                        print(f"   📨 Event: {decoded_line[:200]}")

                response.close()
            else:
                print(f"   ❌ Failed: {response.status_code}")

        except requests.Timeout:
            print(f"   ⏱️ Timeout (no events received)")
        except Exception as e:
            print(f"   ⚠️ Error: {e}")

except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "="*60)
print("✅ Event subscription test complete")
