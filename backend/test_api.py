"""
Quick Test Script for Face Recognition API
Tests all endpoints to ensure backend is working correctly
"""
import requests
import base64
import json
from pathlib import Path

# API Base URL
BASE_URL = "http://localhost:3000"

def test_health():
    """Test health endpoint"""
    print("\n1️⃣ Testing Health Endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ API is healthy!")
            print(f"   Liveness enabled: {data['liveness_enabled']}")
            return True
        else:
            print(f"   ❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        print(f"   Make sure the backend is running: python main.py")
        return False

def encode_image(image_path):
    """Encode image to base64"""
    try:
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode()
    except FileNotFoundError:
        print(f"   ❌ Image not found: {image_path}")
        print(f"   Please provide a test image with a face")
        return None

def test_register_employee(image_base64):
    """Test employee registration"""
    print("\n2️⃣ Testing Employee Registration...")

    if not image_base64:
        print("   ⏭️ Skipping (no image)")
        return None

    try:
        payload = {
            "name": "Test Employee",
            "firstname": "Test",
            "lastname": "Employee",
            "employeeId": "TEST001",
            "department": "Testing",
            "email": "test@company.com",
            "image": image_base64
        }

        response = requests.post(
            f"{BASE_URL}/api/employees/register-with-image",
            json=payload
        )

        if response.status_code in [200, 201]:
            data = response.json()
            print(f"   ✅ Registration successful!")
            print(f"   Employee ID: {data['data']['employeeId']}")
            print(f"   Name: {data['data']['name']}")
            return data['data']['employeeId']
        elif response.status_code == 400:
            print(f"   ⚠️ Employee already exists (OK)")
            return "TEST001"
        else:
            print(f"   ❌ Registration failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return None

    except Exception as e:
        print(f"   ❌ Error: {e}")
        return None

def test_detect_recognize(image_base64):
    """Test face detection and recognition"""
    print("\n3️⃣ Testing Face Detection & Recognition...")

    if not image_base64:
        print("   ⏭️ Skipping (no image)")
        return False

    try:
        payload = {"image": image_base64}

        response = requests.post(
            f"{BASE_URL}/api/detect-recognize",
            json=payload
        )

        if response.status_code == 200:
            data = response.json()
            faces = data.get('faces', [])

            if not faces:
                print(f"   ⚠️ No faces detected in image")
                return False

            print(f"   ✅ Detected {len(faces)} face(s):")
            for i, face in enumerate(faces, 1):
                print(f"\n   Face {i}:")
                print(f"      Name: {face['name']}")
                print(f"      Employee ID: {face.get('employeeId', 'N/A')}")
                print(f"      Confidence: {face['confidence']:.2%}")
                print(f"      Is Live: {'✅ Yes' if face['isLive'] else '❌ No'}")
                print(f"      Liveness Confidence: {face['livenessConfidence']:.2%}")
                if face.get('attendanceMarked'):
                    print(f"      Attendance: ✅ Marked")

            return True
        else:
            print(f"   ❌ Detection failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False

    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_get_employees():
    """Test get all employees"""
    print("\n4️⃣ Testing Get All Employees...")

    try:
        response = requests.get(f"{BASE_URL}/api/employees")

        if response.status_code == 200:
            data = response.json()
            count = data['count']
            print(f"   ✅ Found {count} employee(s) in database")

            if count > 0:
                print(f"\n   Employees:")
                for emp in data['employees'][:5]:  # Show first 5
                    print(f"      - {emp['name']} ({emp['employeeId']})")

            return True
        else:
            print(f"   ❌ Failed: {response.status_code}")
            return False

    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def test_get_attendance():
    """Test get attendance logs"""
    print("\n5️⃣ Testing Get Attendance Logs...")

    try:
        from datetime import date
        today = date.today().isoformat()

        response = requests.get(f"{BASE_URL}/api/attendance?date={today}")

        if response.status_code == 200:
            data = response.json()
            count = data['count']
            print(f"   ✅ Found {count} attendance log(s) for today")

            if count > 0:
                print(f"\n   Recent attendance:")
                for log in data['logs'][:5]:  # Show first 5
                    print(f"      - {log['employeeName']} at {log['timestamp']}")

            return True
        else:
            print(f"   ❌ Failed: {response.status_code}")
            return False

    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Run all tests"""
    print("=" * 60)
    print("🧪 Face Recognition API Test Suite")
    print("=" * 60)

    # Test health
    if not test_health():
        print("\n❌ Backend is not running!")
        print("\nPlease start the backend:")
        print("   cd backend")
        print("   python main.py")
        return

    # Find test image
    test_image_path = None
    possible_paths = [
        "test_image.jpg",
        "test_photo.jpg",
        "../test.jpg",
        "sample.jpg"
    ]

    for path in possible_paths:
        if Path(path).exists():
            test_image_path = path
            break

    if test_image_path:
        print(f"\n📷 Using test image: {test_image_path}")
        image_base64 = encode_image(test_image_path)
    else:
        print(f"\n⚠️ No test image found")
        print(f"   Place a photo with a face as 'test_image.jpg' in the backend folder")
        print(f"   Tests requiring image will be skipped")
        image_base64 = None

    # Run tests
    test_register_employee(image_base64)
    test_detect_recognize(image_base64)
    test_get_employees()
    test_get_attendance()

    # Summary
    print("\n" + "=" * 60)
    print("✅ Test Suite Complete!")
    print("=" * 60)
    print("\n📝 Next Steps:")
    print("   1. If all tests passed: ✅ Backend is ready!")
    print("   2. Start Flutter web: flutter run -d chrome")
    print("   3. Test the complete system")
    print("\n🔗 API Documentation: http://localhost:3000/docs")

if __name__ == "__main__":
    main()
