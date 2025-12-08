"""Test polling service directly"""
import sys
import time
from database import get_db, Camera
from polling_attendance_service import PollingAttendanceMonitor

# Get a camera
db = next(get_db())
camera = db.query(Camera).filter(Camera.name == "Dahua").first()

if not camera:
    print("❌ No Dahua camera found")
    sys.exit(1)

print(f"✅ Found camera: {camera.name}")
print(f"   URL: {camera.stream_url}")

# Create monitor
monitor = PollingAttendanceMonitor(camera, get_db)

# Start monitor
if monitor.start():
    print("✅ Monitor started successfully")

    # Wait and watch
    print("\n🔍 Monitoring for 15 seconds...\n")
    time.sleep(15)

    monitor.stop()
    print("\n✅ Test complete")
else:
    print("❌ Failed to start monitor")

db.close()
