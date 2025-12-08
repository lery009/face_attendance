"""
Test Event Stream from Dahua Camera
This script directly tests the event stream connection and shows what events the camera sends.
"""
import requests
from requests.auth import HTTPDigestAuth
import time

def test_event_stream(ip: str = "192.168.2.192", username: str = "admin", password: str = "admin@2025"):
    """
    Test the Dahua camera event stream and display all events received.

    Usage:
        python3 test_event_stream.py

    Then walk in front of the camera to trigger face detection.
    """
    print("="*70)
    print("🎥 DAHUA CAMERA EVENT STREAM TEST")
    print("="*70)
    print(f"\nCamera: http://{ip}")
    print(f"Username: {username}")
    print(f"Password: ***")

    # Test different event codes
    event_configs = [
        ("All Face Events", "FaceDetection,FaceRecognition,AccessControl,VideoAnalyse"),
        ("FaceDetection Only", "FaceDetection"),
        ("FaceRecognition Only", "FaceRecognition"),
        ("AccessControl Only", "AccessControl"),
        ("All Events", "All"),
    ]

    print("\n" + "="*70)
    print("TESTING EVENT SUBSCRIPTIONS")
    print("="*70)

    for name, codes in event_configs:
        print(f"\n📡 Testing: {name}")
        print(f"   Event Codes: [{codes}]")
        print(f"   Duration: 10 seconds")
        print(f"   👤 Walk in front of camera now...")
        print(f"   " + "-"*60)

        try:
            url = f"http://{ip}/cgi-bin/eventManager.cgi?action=attach&codes=[{codes}]"
            auth = HTTPDigestAuth(username, password)

            # Make request with timeout
            response = requests.get(url, auth=auth, timeout=15, stream=True)

            if response.status_code != 200:
                print(f"   ❌ Failed to connect (status {response.status_code})")
                print(f"   Response: {response.text[:200]}")
                continue

            print(f"   ✅ Connected successfully")

            # Listen for events
            start_time = time.time()
            event_count = 0

            for line in response.iter_lines():
                if time.time() - start_time > 10:  # 10 second timeout
                    break

                if line:
                    event_count += 1
                    decoded = line.decode('utf-8', errors='ignore')

                    # Highlight important events
                    if any(keyword in decoded for keyword in ['Face', 'Access', 'Video']):
                        print(f"   🎯 EVENT #{event_count}: {decoded}")
                    else:
                        # Show first 100 chars of other events
                        print(f"   📨 Event #{event_count}: {decoded[:100]}...")

            if event_count == 0:
                print(f"   ⚠️ No events received in 10 seconds")
            else:
                print(f"   ✅ Received {event_count} events")

        except requests.Timeout:
            print(f"   ⏱️ Connection timeout")
        except Exception as e:
            print(f"   ❌ Error: {e}")

        print(f"   " + "-"*60)

    # Test face analysis config
    print("\n" + "="*70)
    print("CHECKING FACE ANALYSIS CONFIG")
    print("="*70)

    try:
        config_url = f"http://{ip}/cgi-bin/configManager.cgi?action=getConfig&name=VideoAnalyseRule"
        auth = HTTPDigestAuth(username, password)
        response = requests.get(config_url, auth=auth, timeout=5)

        if response.status_code == 200:
            print("\n✅ Face Analysis Configuration:")

            # Parse and display relevant settings
            for line in response.text.split('\n'):
                if 'Enable' in line or 'FaceAntifake' in line or 'MinQuality' in line:
                    print(f"   {line.strip()}")
        else:
            print(f"\n❌ Failed to get config (status {response.status_code})")

    except Exception as e:
        print(f"\n❌ Error getting config: {e}")

    # Test snapshot capability
    print("\n" + "="*70)
    print("TESTING SNAPSHOT")
    print("="*70)

    try:
        snapshot_url = f"http://{ip}/cgi-bin/snapshot.cgi?channel=1"
        auth = HTTPDigestAuth(username, password)
        response = requests.get(snapshot_url, auth=auth, timeout=10)

        if response.status_code == 200:
            filename = f"/tmp/test_snapshot_{int(time.time())}.jpg"
            with open(filename, 'wb') as f:
                f.write(response.content)
            print(f"\n✅ Snapshot saved: {filename}")
            print(f"   Size: {len(response.content)} bytes")
        else:
            print(f"\n❌ Failed to get snapshot (status {response.status_code})")

    except Exception as e:
        print(f"\n❌ Error getting snapshot: {e}")

    print("\n" + "="*70)
    print("✅ TEST COMPLETE")
    print("="*70)
    print("\nSummary:")
    print("- If you saw face-related events above, the camera IS sending them")
    print("- If NO events appeared, check:")
    print("  1. Is face analysis enabled on the camera?")
    print("  2. Did you walk in front of the camera during the test?")
    print("  3. Is the camera's face detection working in its web interface?")
    print("\nNext Steps:")
    print("- If events ARE being sent: The backend should now log them")
    print("- If NO events: Enable face detection in camera settings")
    print()


if __name__ == "__main__":
    print("\n🔧 Starting diagnostic test...")
    print("Make sure you're ready to walk in front of the camera!\n")
    time.sleep(2)

    test_event_stream()
