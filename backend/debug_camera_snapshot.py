"""Debug script to save camera snapshot and check face detection"""
import requests
from requests.auth import HTTPDigestAuth
import numpy as np
import cv2
import face_recognition as fr
from database import get_db, Camera
import re
from urllib.parse import unquote

# Get camera
db = next(get_db())
try:
    camera = db.query(Camera).filter(Camera.name.like('%Dahua%')).first()

    if not camera:
        print("❌ No Dahua camera found")
        exit(1)

    # Extract credentials
    creds_match = re.search(r'rtsp://([^:]+):([^@]+)@([0-9.]+):', camera.stream_url)

    if not creds_match:
        print("❌ Could not extract credentials")
        exit(1)

    username = unquote(creds_match.group(1))
    password = unquote(creds_match.group(2))
    camera_ip = creds_match.group(3)
    base_url = f"http://{camera_ip}:80"

    print(f"📸 Getting snapshot from {camera_ip}...")

    # Create session
    session = requests.Session()
    session.auth = HTTPDigestAuth(username, password)

    # Get snapshot
    snapshot_url = f"{base_url}/cgi-bin/snapshot.cgi?channel=1"
    response = session.get(snapshot_url, timeout=10)

    if response.status_code != 200:
        print(f"❌ Failed to get snapshot: HTTP {response.status_code}")
        exit(1)

    # Save raw snapshot
    with open('snapshot.jpg', 'wb') as f:
        f.write(response.content)
    print(f"✅ Saved raw snapshot to snapshot.jpg ({len(response.content)} bytes)")

    # Decode and analyze
    nparr = np.frombuffer(response.content, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        print("❌ Failed to decode snapshot")
        exit(1)

    print(f"✅ Image decoded: {img.shape} (height={img.shape[0]}, width={img.shape[1]})")

    # Convert to RGB
    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Try face detection with different models
    print(f"\n🔍 Running face detection...")

    # Try with HOG model (default, faster but less accurate)
    print(f"   Trying HOG model...")
    face_locations = fr.face_locations(rgb_img, model='hog')
    print(f"   HOG model: Found {len(face_locations)} face(s)")

    if not face_locations:
        # Try with CNN model (slower but more accurate, handles non-frontal faces better)
        print(f"   Trying CNN model (more accurate)...")
        face_locations = fr.face_locations(rgb_img, model='cnn')
        print(f"   CNN model: Found {len(face_locations)} face(s)")

    print(f"\n   Total faces detected: {len(face_locations)}")

    if face_locations:
        for i, (top, right, bottom, left) in enumerate(face_locations):
            print(f"\n   Face {i+1}:")
            print(f"     Position: top={top}, right={right}, bottom={bottom}, left={left}")
            print(f"     Size: {right-left}x{bottom-top} pixels")

            # Draw rectangle on image
            cv2.rectangle(img, (left, top), (right, bottom), (0, 255, 0), 2)

        # Save annotated image
        cv2.imwrite('snapshot_annotated.jpg', img)
        print(f"\n✅ Saved annotated snapshot to snapshot_annotated.jpg")
    else:
        print(f"\n⚠️  No faces detected in snapshot")
        print(f"   Possible reasons:")
        print(f"   - Person not in camera view")
        print(f"   - Poor lighting")
        print(f"   - Face too small/far from camera")
        print(f"   - Face angle not frontal")
        print(f"   - Check snapshot.jpg to see what camera sees")

finally:
    db.close()
