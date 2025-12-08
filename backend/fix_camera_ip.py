"""
Fix the camera IP address from 192.168.2.193 to 192.168.2.192
"""
from database import get_db, Camera

db = next(get_db())

# Find the camera with wrong IP
camera = db.query(Camera).filter(Camera.stream_url.like('%192.168.2.193%')).first()

if camera:
    print(f"Found camera: {camera.name}")
    print(f"Old URL: {camera.stream_url}")

    # Update the IP address
    new_url = camera.stream_url.replace('192.168.2.193', '192.168.2.192')
    camera.stream_url = new_url

    db.commit()

    print(f"New URL: {camera.stream_url}")
    print("✅ Camera IP updated successfully!")
else:
    print("❌ Camera with IP 192.168.2.193 not found")

db.close()
