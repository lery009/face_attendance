"""
Test camera monitoring status
"""
from database import get_db, Camera
import re

db = next(get_db())

cameras = db.query(Camera).filter(Camera.is_active == True).all()

print(f"\n🔍 Found {len(cameras)} active cameras:\n")

for camera in cameras:
    print(f"📷 Camera: {camera.name}")
    print(f"   Type: {camera.camera_type}")
    print(f"   Stream URL: {camera.stream_url}")
    print(f"   Username: {camera.username}")
    print(f"   Password: {'***' if camera.password else 'None'}")

    # Check if it's RTSP
    if camera.camera_type != 'rtsp':
        print(f"   ⚠️ NOT RTSP - Will be skipped!")
        print()
        continue

    # Try to extract IP
    ip_match = re.search(r'@([0-9.]+):', camera.stream_url)
    if not ip_match:
        print(f"   ❌ Could not extract IP from URL - Will be skipped!")
        print()
        continue

    ip = ip_match.group(1)
    print(f"   ✅ Extracted IP: {ip}")
    print(f"   ✅ This camera SHOULD be monitored")
    print()

db.close()
