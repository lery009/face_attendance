"""Use the already captured snapshot.jpg to sync to camera"""
import requests
from requests.auth import HTTPDigestAuth
import base64
from database import get_db, Camera, Employee
import re
from urllib.parse import unquote
from PIL import Image
from io import BytesIO

# Get camera and employee
db = next(get_db())
try:
    # Get camera
    camera = db.query(Camera).filter(Camera.name.like('%Dahua%')).first()
    if not camera:
        print("❌ No Dahua camera found")
        exit(1)

    # Get employee
    employee = db.query(Employee).filter(Employee.employee_id == "12344").first()
    if not employee:
        print("❌ Employee 12344 not found")
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

    print(f"📤 Syncing {employee.name} ({employee.employee_id}) to camera at {camera_ip}")
    print(f"   Using snapshot_annotated.jpg...")

    # Load the annotated snapshot (or use snapshot.jpg)
    with open('snapshot.jpg', 'rb') as f:
        img_data = f.read()

    # Create session
    session = requests.Session()
    session.auth = HTTPDigestAuth(username, password)

    # Try Method 1: CGI-based face library API
    print("\n📤 Method 1: Trying CGI-based API...")
    try:
        face_upload_url = f"{base_url}/cgi-bin/faceLib.cgi?action=insert"

        files = {
            'Face': ('face.jpg', img_data, 'image/jpeg')
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

        print(f"   Response: HTTP {response.status_code}")
        print(f"   Body: {response.text[:200]}")

        if response.status_code == 200 and 'OK' in response.text:
            print(f"✅ Face uploaded successfully (CGI API)!")
            print(f"   {employee.name} should now show as 'Authorized'")
            exit(0)

    except Exception as e:
        print(f"⚠️  CGI API error: {e}")

    # Try Method 2: RPC2 JSON-RPC API
    print("\n📤 Method 2: Trying RPC2 JSON-RPC API...")
    try:
        # Convert image to base64
        img_base64 = base64.b64encode(img_data).decode('utf-8')

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

        print(f"   Add Person Response: HTTP {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Result: {result}")

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

        print(f"   Add Face Response: HTTP {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Result: {result}")
            if result.get('result'):
                print(f"✅ Face uploaded successfully (RPC2 API)!")
                print(f"   {employee.name} should now show as 'Authorized'")
                exit(0)

    except Exception as e:
        print(f"⚠️  RPC2 API error: {e}")
        import traceback
        traceback.print_exc()

    # Try Method 3: HTTP face recognition API
    print("\n📤 Method 3: Trying HTTP face recognition API...")
    try:
        face_url = f"{base_url}/cgi-bin/FaceManagerInterface.cgi"

        params = {
            'action': 'insertFace',
            'UserID': employee.employee_id,
            'Name': employee.name
        }

        files = {
            'FacePhoto': ('face.jpg', img_data, 'image/jpeg')
        }

        response = session.post(
            face_url,
            params=params,
            files=files,
            timeout=15
        )

        print(f"   Response: HTTP {response.status_code}")
        print(f"   Body: {response.text[:200]}")

        if response.status_code == 200:
            print(f"✅ Face uploaded successfully (HTTP API)!")
            print(f"   {employee.name} should now show as 'Authorized'")
            exit(0)

    except Exception as e:
        print(f"⚠️  HTTP API error: {e}")

    print(f"\n❌ All API methods failed")
    print(f"   Your camera model may not support face database management via API")

finally:
    db.close()
