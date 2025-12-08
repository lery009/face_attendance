"""
Update camera IP address from 192.168.2.192 to 10.22.0.35
"""
from database import get_db, Camera

db = next(get_db())

# Find the camera with old IP
camera = db.query(Camera).filter(Camera.stream_url.like('%192.168.2.192%')).first()

if camera:
    print(f"Found camera: {camera.name}")
    print(f"Old URL: {camera.stream_url}")

    # Update the IP address
    new_url = camera.stream_url.replace('192.168.2.192', '10.22.0.35')
    camera.stream_url = new_url

    db.commit()

    print(f"New URL: {camera.stream_url}")
    print("✅ Camera IP updated successfully!")
else:
    print("⚠️ Camera with IP 192.168.2.192 not found")
    print("\nLet me check all cameras...")

    cameras = db.query(Camera).all()
    for cam in cameras:
        print(f"\n📷 {cam.name}")
        print(f"   URL: {cam.stream_url}")
        print(f"   Active: {cam.is_active}")

db.close()
