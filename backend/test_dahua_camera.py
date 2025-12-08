"""
Test script to connect to Dahua DHI-ASA3223A-W camera
"""
import cv2
import sys

def test_dahua_camera(ip_address, username="admin", password="admin"):
    """
    Test connection to Dahua camera

    Common Dahua RTSP URLs:
    - Main stream: rtsp://username:password@IP:554/cam/realmonitor?channel=1&subtype=0
    - Sub stream: rtsp://username:password@IP:554/cam/realmonitor?channel=1&subtype=1
    """

    print("=" * 60)
    print("🎥 Testing Dahua Camera Connection")
    print("=" * 60)
    print(f"IP Address: {ip_address}")
    print(f"Username: {username}")
    print(f"Password: {'*' * len(password)}")
    print()

    # Common Dahua RTSP URL formats
    rtsp_urls = [
        f"rtsp://{username}:{password}@{ip_address}:554/cam/realmonitor?channel=1&subtype=0",  # Main stream
        f"rtsp://{username}:{password}@{ip_address}:554/cam/realmonitor?channel=1&subtype=1",  # Sub stream
        f"rtsp://{username}:{password}@{ip_address}:554/live",  # Alternative format
        f"rtsp://{username}:{password}@{ip_address}/cam/realmonitor?channel=1&subtype=0",  # Without port
    ]

    for i, rtsp_url in enumerate(rtsp_urls, 1):
        print(f"🔍 Testing URL {i}: {rtsp_url.replace(password, '***')}")

        try:
            cap = cv2.VideoCapture(rtsp_url)

            if cap.isOpened():
                print("✅ Connection successful!")

                # Try to read a frame
                ret, frame = cap.read()

                if ret and frame is not None:
                    height, width = frame.shape[:2]
                    print(f"✅ Frame captured successfully!")
                    print(f"   Resolution: {width}x{height}")
                    print(f"   Working RTSP URL: {rtsp_url.replace(password, '***')}")
                    print()
                    print("=" * 60)
                    print("✅ SUCCESS! Use this URL to add the camera:")
                    print(f"   {rtsp_url.replace(password, '***')}")
                    print("=" * 60)

                    cap.release()
                    return rtsp_url
                else:
                    print("⚠️  Connection opened but couldn't read frame")
                    cap.release()
            else:
                print("❌ Failed to connect")

        except Exception as e:
            print(f"❌ Error: {e}")

        print()

    print("=" * 60)
    print("❌ Could not connect to camera with any standard URL")
    print("=" * 60)
    print()
    print("Troubleshooting:")
    print("1. Check if camera IP is correct")
    print("2. Verify username/password (default is usually admin/admin)")
    print("3. Check if RTSP is enabled in camera settings")
    print("4. Try accessing camera web interface: http://{}".format(ip_address))
    print("5. Check camera documentation for correct RTSP URL format")

    return None


if __name__ == "__main__":
    print()
    print("DHI-ASA3223A-W Camera Connection Test")
    print()

    # Get camera details
    if len(sys.argv) > 1:
        camera_ip = sys.argv[1]
    else:
        camera_ip = input("Enter camera IP address: ").strip()

    if not camera_ip:
        print("❌ IP address required")
        sys.exit(1)

    username = input("Enter username (press Enter for 'admin'): ").strip() or "admin"
    password = input("Enter password (press Enter for 'admin'): ").strip() or "admin"

    print()
    working_url = test_dahua_camera(camera_ip, username, password)

    if working_url:
        print()
        print("Next steps:")
        print("1. Copy the working RTSP URL above")
        print("2. Go to Camera Management in your app")
        print("3. Add new camera with this URL")
        print("4. The camera will be ready for face detection!")
