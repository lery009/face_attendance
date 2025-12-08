"""
Sync Face Data to Dahua Camera
Pushes employee face data from our database to the camera's internal face database
"""
import requests
from requests.auth import HTTPDigestAuth
import base64
import json
from database import get_db, Employee, Camera
import cv2
import numpy as np
import face_recognition as fr
from io import BytesIO
from PIL import Image

def sync_employee_to_camera(employee_id: str, camera_id: str):
    """
    Sync a single employee's face data to a specific camera

    Args:
        employee_id: Employee ID to sync
        camera_id: Camera ID to sync to
    """
    db = next(get_db())
    try:
        # Get employee
        employee = db.query(Employee).filter(Employee.employee_id == employee_id).first()
        if not employee:
            print(f"❌ Employee {employee_id} not found")
            return False

        # Get camera
        camera = db.query(Camera).filter(Camera.id == camera_id).first()
        if not camera:
            print(f"❌ Camera {camera_id} not found")
            return False

        # Extract camera IP from RTSP URL
        import re
        from urllib.parse import unquote
        creds_match = re.search(r'rtsp://([^:]+):([^@]+)@([0-9.]+):', camera.stream_url)

        if not creds_match:
            print(f"❌ Could not extract credentials from camera URL")
            return False

        username = unquote(creds_match.group(1))
        password = unquote(creds_match.group(2))
        camera_ip = creds_match.group(3)
        base_url = f"http://{camera_ip}:80"

        print(f"📤 Syncing {employee.name} ({employee_id}) to camera at {camera_ip}")

        # Create HTTP session with digest auth
        session = requests.Session()
        session.auth = HTTPDigestAuth(username, password)

        # Step 1: Create a face image from our stored embeddings
        # Since we only have embeddings, we need to get the original face image
        # For now, let's create a placeholder or fetch from a stored image path
        # In production, you'd store the original face image when registering

        # For this demo, let's assume we need to capture a new image from camera
        print("⚠️  Need face image to upload to camera")
        print("    Attempting to capture current snapshot...")

        # Get snapshot from camera
        snapshot_url = f"{base_url}/cgi-bin/snapshot.cgi?channel=1"
        response = session.get(snapshot_url, timeout=10)

        if response.status_code != 200:
            print(f"❌ Failed to get snapshot: HTTP {response.status_code}")
            return False

        # Decode snapshot
        nparr = np.frombuffer(response.content, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            print("❌ Failed to decode snapshot")
            return False

        # Convert to RGB for face detection
        rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        # Detect faces in snapshot using CNN model (better for non-frontal faces)
        print("   Trying HOG face detection...")
        face_locations = fr.face_locations(rgb_img, model='hog')

        if not face_locations:
            print("   HOG failed, trying CNN model (more accurate)...")
            face_locations = fr.face_locations(rgb_img, model='cnn')

        if not face_locations:
            print("❌ No face detected in snapshot")
            print("   Please stand in front of camera and try again")
            return False

        # Get the first face
        top, right, bottom, left = face_locations[0]

        # Crop face with some padding
        padding = 50
        face_img = rgb_img[max(0, top-padding):bottom+padding,
                          max(0, left-padding):right+padding]

        # Convert to JPEG
        pil_img = Image.fromarray(face_img)
        img_buffer = BytesIO()
        pil_img.save(img_buffer, format='JPEG', quality=95)
        img_base64 = base64.b64encode(img_buffer.getvalue()).decode('utf-8')

        print(f"✅ Captured face image ({face_img.shape})")

        # Step 2: Try multiple Dahua API methods

        # Method 1: Try CGI-based face library API (older cameras)
        try:
            print("📤 Trying CGI-based API...")

            # Upload face via CGI
            face_upload_url = f"{base_url}/cgi-bin/faceLib.cgi?action=insert"

            # Prepare multipart form data
            files = {
                'Face': ('face.jpg', img_buffer.getvalue(), 'image/jpeg')
            }
            data = {
                'PersonName': employee.name,
                'PersonID': employee.employee_id,
                'GroupID': 'default'
            }

            response = session.post(
                face_upload_url,
                files=files,
                data=data,
                timeout=15
            )

            if response.status_code == 200:
                print(f"✅ Face uploaded successfully (CGI API)!")
                print(f"   {employee.name} will now show as 'Authorized'")
                return True
            else:
                print(f"⚠️  CGI API failed: HTTP {response.status_code}")
                print(f"   Response: {response.text[:200]}")

        except Exception as e:
            print(f"⚠️  CGI API error: {e}")

        # Method 2: Try RPC2 JSON-RPC API (newer cameras)
        try:
            print("📤 Trying RPC2 JSON-RPC API...")

            # First, create a person record
            person_data = {
                "method": "faceLibManager.addPerson",
                "params": {
                    "info": {
                        "Name": employee.name,
                        "PersonID": employee.employee_id,
                        "GroupIDs": ["default"],
                    }
                },
                "id": 1
            }

            add_person_url = f"{base_url}/RPC2"
            response = session.post(
                add_person_url,
                json=person_data,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )

            if response.status_code == 200:
                result = response.json()
                if result.get('result'):
                    print(f"✅ Person record created")

            # Add face image
            face_data = {
                "method": "faceLibManager.addFace",
                "params": {
                    "info": {
                        "PersonID": employee.employee_id,
                        "PhotoData": img_base64,
                        "PhotoFormat": "jpg"
                    }
                },
                "id": 2
            }

            response = session.post(
                add_person_url,
                json=face_data,
                headers={'Content-Type': 'application/json'},
                timeout=15
            )

            if response.status_code == 200:
                result = response.json()
                if result.get('result'):
                    print(f"✅ Face uploaded successfully (RPC2 API)!")
                    print(f"   {employee.name} will now show as 'Authorized'")
                    return True
                else:
                    error = result.get('error', {})
                    print(f"⚠️  RPC2 API failed: {error.get('message', 'Unknown error')}")

        except Exception as e:
            print(f"⚠️  RPC2 API error: {e}")

        # Method 3: Try HTTP POST to face recognition endpoint
        try:
            print("📤 Trying HTTP face recognition API...")

            # Some Dahua cameras use this endpoint
            face_url = f"{base_url}/cgi-bin/FaceManagerInterface.cgi"

            params = {
                'action': 'insertFace',
                'UserID': employee.employee_id,
                'Name': employee.name
            }

            files = {
                'FacePhoto': ('face.jpg', img_buffer.getvalue(), 'image/jpeg')
            }

            response = session.post(
                face_url,
                params=params,
                files=files,
                timeout=15
            )

            if response.status_code == 200:
                print(f"✅ Face uploaded successfully (HTTP API)!")
                print(f"   {employee.name} will now show as 'Authorized'")
                print(f"   Response: {response.text[:200]}")
                return True
            else:
                print(f"⚠️  HTTP API failed: HTTP {response.status_code}")
                print(f"   Response: {response.text[:200]}")

        except Exception as e:
            print(f"⚠️  HTTP API error: {e}")

        print(f"\n❌ All API methods failed")
        print(f"   Your camera model may not support face database management via API")
        print(f"   You may need to manually add faces using the camera's web interface")
        return False

    except Exception as e:
        print(f"❌ Error syncing to camera: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        db.close()


def sync_all_employees_to_camera(camera_id: str):
    """Sync all employees to a specific camera"""
    db = next(get_db())
    try:
        employees = db.query(Employee).filter(Employee.embeddings.isnot(None)).all()

        print(f"\n🔄 Syncing {len(employees)} employees to camera...")

        success_count = 0
        for employee in employees:
            if sync_employee_to_camera(employee.employee_id, camera_id):
                success_count += 1
            print()  # Blank line between employees

        print(f"✅ Successfully synced {success_count}/{len(employees)} employees")

    finally:
        db.close()


if __name__ == "__main__":
    # Get Dahua camera
    db = next(get_db())
    try:
        camera = db.query(Camera).filter(Camera.name.like('%Dahua%')).first()

        if not camera:
            print("❌ No Dahua camera found")
            exit(1)

        print(f"Found camera: {camera.name} ({camera.id})")
        print()

        # Sync specific employee (Lery)
        print("=" * 60)
        print("Syncing Lery (12344) to camera...")
        print("=" * 60)
        sync_employee_to_camera("12344", str(camera.id))

    finally:
        db.close()
