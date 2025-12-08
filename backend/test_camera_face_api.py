"""
Test if Dahua camera supports face registration via HTTP API
This will determine if we can sync faces from our database to the camera
"""
import requests
from requests.auth import HTTPDigestAuth
import base64

def test_face_api_endpoints():
    """Test various face-related API endpoints on Dahua camera"""

    camera_ip = "192.168.2.192"
    username = "admin"
    password = "admin@2025"

    auth = HTTPDigestAuth(username, password)
    session = requests.Session()
    session.auth = auth

    print("="*70)
    print("🔍 TESTING DAHUA CAMERA FACE API ENDPOINTS")
    print("="*70)
    print(f"\nCamera: {camera_ip}")
    print(f"Testing face database access...\n")

    # Test endpoints
    endpoints = [
        # Person/Face management
        ("Get All Faces", "/cgi-bin/AccessFace.cgi?action=getAll"),
        ("Get Face Count", "/cgi-bin/AccessControllerServer.cgi?action=getPersonTotalNumber"),
        ("Get Persons", "/cgi-bin/AccessFace.cgi?action=getPersons"),
        ("Factory Create", "/cgi-bin/recordFinder.cgi?action=factory.create&name=Person"),

        # User management
        ("Get All Users", "/cgi-bin/AccessUser.cgi?action=getAll"),
        ("Get User Count", "/cgi-bin/AccessUser.cgi?action=getUserTotalNumber"),

        # Card database
        ("Get All Cards", "/cgi-bin/AccessCardDB.cgi?action=getAll"),

        # Face library
        ("Face Lib Manager", "/cgi-bin/faceLibManager.cgi?action=getCollect"),
    ]

    results = {}

    for name, endpoint in endpoints:
        print(f"📡 Testing: {name}")
        print(f"   Endpoint: {endpoint}")

        try:
            url = f"http://{camera_ip}{endpoint}"
            response = session.get(url, timeout=10)

            status = "✅ SUCCESS" if response.status_code == 200 else f"❌ FAILED ({response.status_code})"
            print(f"   Status: {status}")

            if response.status_code == 200:
                # Show first 200 chars of response
                content = response.text[:200].replace('\n', ' ')
                print(f"   Response: {content}...")
                results[name] = {
                    "endpoint": endpoint,
                    "status": response.status_code,
                    "response": response.text
                }
            else:
                print(f"   Error: {response.text[:100]}")
                results[name] = {
                    "endpoint": endpoint,
                    "status": response.status_code,
                    "error": response.text
                }

        except Exception as e:
            print(f"   ❌ Exception: {e}")
            results[name] = {"error": str(e)}

        print()

    # Test face insertion (with dummy data)
    print("="*70)
    print("🧪 TESTING FACE INSERTION")
    print("="*70)

    # Create a minimal test payload
    test_person_id = "TEST_001"

    print(f"\nAttempting to register test person: {test_person_id}\n")

    insert_endpoints = [
        ("POST AccessFace insert", "/cgi-bin/AccessFace.cgi?action=insert", "POST"),
        ("GET AccessFace insert", f"/cgi-bin/AccessFace.cgi?action=insert&PersonID={test_person_id}&PersonName=TestPerson", "GET"),
        ("POST recordFinder insert", "/cgi-bin/recordFinder.cgi?action=insert&name=Person", "POST"),
    ]

    for name, endpoint, method in insert_endpoints:
        print(f"📡 Testing: {name}")
        print(f"   Method: {method}")
        print(f"   Endpoint: {endpoint}")

        try:
            url = f"http://{camera_ip}{endpoint}"

            if method == "POST":
                # Try JSON payload
                data = {
                    "PersonID": test_person_id,
                    "PersonName": "Test Person",
                }
                response = session.post(url, json=data, timeout=10)
            else:
                response = session.get(url, timeout=10)

            status = "✅ SUCCESS" if response.status_code == 200 else f"⚠️ Status {response.status_code}"
            print(f"   Status: {status}")
            print(f"   Response: {response.text[:200]}")

        except Exception as e:
            print(f"   ❌ Exception: {e}")

        print()

    # Summary
    print("="*70)
    print("📊 SUMMARY")
    print("="*70)

    successful = [name for name, result in results.items() if result.get('status') == 200]

    print(f"\n✅ Successful endpoints: {len(successful)}/{len(results)}")

    if successful:
        print("\nWorking endpoints:")
        for name in successful:
            print(f"  - {name}: {results[name]['endpoint']}")

    print("\n" + "="*70)
    print("CONCLUSION")
    print("="*70)

    if any("Face" in name for name in successful):
        print("\n✅ Camera SUPPORTS face database access via HTTP API!")
        print("   We CAN implement face synchronization.")
        print("\nNext steps:")
        print("  1. Implement face sync service")
        print("  2. Add photo storage to employee table")
        print("  3. Create sync API endpoints")
        print("  4. Test with real employee photos")
    else:
        print("\n❌ Camera DOES NOT support face database access via HTTP API")
        print("   Current backend recognition approach is optimal.")
        print("\nAlternatives:")
        print("  1. Continue using current system (backend recognition)")
        print("  2. Manually register faces via camera web interface")
        print("  3. Investigate native SDK (port 37777)")

    print()


if __name__ == "__main__":
    test_face_api_endpoints()
