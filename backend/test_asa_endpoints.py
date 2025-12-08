"""
Test ASA-specific endpoints for face recognition
The DHI-ASA3223A-W is an Access Control camera with different API endpoints
"""
import requests
from requests.auth import HTTPDigestAuth
import json

CAMERA_IP = "192.168.2.193"
USERNAME = "admin"
PASSWORD = "admin@2025"

base_url = f"http://{CAMERA_IP}"
auth = HTTPDigestAuth(USERNAME, PASSWORD)
session = requests.Session()
session.auth = auth

print("🔍 Exploring ASA Camera API Endpoints...\n")

# List of possible ASA endpoints to test
endpoints = [
    # Face database management
    "/cgi-bin/AccessFace.cgi?action=factory.getCollect",
    "/cgi-bin/AccessFace.cgi?action=getPersons",
    "/cgi-bin/AccessFace.cgi?action=insert",
    "/cgi-bin/AccessFace.cgi?action=getAll",

    # Face recognition configuration
    "/cgi-bin/AccessControl.cgi?action=getConfig",
    "/cgi-bin/AccessControl.cgi?action=getCaps",

    # General capabilities
    "/cgi-bin/capability.cgi?action=get",
    "/cgi-bin/AccessControllerServer.cgi?action=getAll",

    # Event management for face recognition
    "/cgi-bin/eventManager.cgi?action=getEventIndexes&code=AccessControl",
    "/cgi-bin/eventManager.cgi?action=getCaps",

    # Face library/database
    "/cgi-bin/faceLibManager.cgi?action=getCollect",
    "/cgi-bin/faceLibManager.cgi?action=getPersons",

    # Smart functions
    "/cgi-bin/smart.cgi?action=getConfig&name=AccessControl",
    "/cgi-bin/smart.cgi?action=getCaps",

    # Access control specific
    "/cgi-bin/AccessControllerServer.cgi?action=getCurrentTime",
    "/cgi-bin/AccessControllerServer.cgi?action=getPersonTotalNumber",

    # Configuration manager for access control
    "/cgi-bin/configManager.cgi?action=getConfig&name=AccessControllerServer",
    "/cgi-bin/configManager.cgi?action=getConfig&name=AccessControl",

    # Device class - might show access control features
    "/cgi-bin/devClass.cgi",
]

successful_endpoints = []

for endpoint in endpoints:
    try:
        url = base_url + endpoint
        response = session.get(url, timeout=5)

        if response.status_code == 200 and len(response.text) > 0:
            print(f"✅ {endpoint}")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.text[:500]}")
            print()
            successful_endpoints.append({
                "endpoint": endpoint,
                "response": response.text
            })
        else:
            print(f"❌ {endpoint} - Status: {response.status_code}")

    except Exception as e:
        print(f"⚠️ {endpoint} - Error: {e}")

print("\n" + "="*60)
print(f"📊 Found {len(successful_endpoints)} working endpoints")
print("="*60)

# Save results
with open('/tmp/asa_endpoints_results.json', 'w') as f:
    json.dump(successful_endpoints, f, indent=2)

print("\n✅ Results saved to /tmp/asa_endpoints_results.json")
