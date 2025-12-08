"""Check camera status in database"""
from database import get_db, Camera
import cv2

db = next(get_db())

try:
    cameras = db.query(Camera).all()

    print("\n" + "=" * 60)
    print("📹 CAMERAS IN DATABASE")
    print("=" * 60)

    if not cameras:
        print("❌ No cameras found in database")
    else:
        for camera in cameras:
            print(f"\n🎥 Camera: {camera.name}")
            print(f"   ID: {camera.id}")
            print(f"   Type: {camera.camera_type}")
            print(f"   Stream URL: {camera.stream_url}")
            print(f"   Username: {camera.username}")
            print(f"   Password: {'*' * len(camera.password) if camera.password else 'None'}")
            print(f"   Is Active: {camera.is_active}")
            print(f"   Status: {camera.status}")
            print(f"   Location: {camera.location}")

            # Test connection
            print(f"\n   🔍 Testing connection...")

            # Build RTSP URL
            if camera.camera_type == 'rtsp':
                if camera.username and camera.password:
                    # Credentials in separate fields - build URL
                    parts = camera.stream_url.replace('rtsp://', '').split('/', 1)
                    host_part = parts[0]
                    path_part = '/' + parts[1] if len(parts) > 1 else ''
                    test_url = f'rtsp://{camera.username}:{camera.password}@{host_part}{path_part}'
                else:
                    # Credentials already in URL
                    test_url = camera.stream_url

                print(f"   Testing URL: {test_url.replace(camera.password if camera.password else '', '***') if camera.password else test_url}")

                cap = cv2.VideoCapture(test_url)

                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        print(f"   ✅ CONNECTION SUCCESSFUL!")
                        print(f"   📐 Resolution: {frame.shape[1]}x{frame.shape[0]}")
                    else:
                        print(f"   ⚠️  Opened but couldn't read frame")
                    cap.release()
                else:
                    print(f"   ❌ FAILED TO CONNECT")

            print()

    print("=" * 60)

finally:
    db.close()
