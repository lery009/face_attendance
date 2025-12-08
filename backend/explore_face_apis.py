"""
Explore all possible face recognition APIs on the Dahua ASA camera
"""
import requests
from requests.auth import HTTPDigestAuth

CAMERA_IP = "192.168.2.193"
USERNAME = "admin"
PASSWORD = "admin@2025"

base_url = f"http://{CAMERA_IP}"
auth = HTTPDigestAuth(USERNAME, PASSWORD)
session = requests.Session()
session.auth = auth

print("🔍 Exploring Face Recognition Configuration...\n")

# Try various configuration names
config_names = [
    "FaceRecognition",
    "FaceDetect",
    "VideoAnalyse",
    "VideoAnalyseRule",
    "IvsFaceDetect",
    "FaceRecognitionDB",
    "FaceDataBase",
    "AccessFaceRecognition",
    "SmartFaceDetect",
    "IntelligentTraffic",
]

print("="*60)
print("Testing Configuration Endpoints:")
print("="*60 + "\n")

for name in config_names:
    try:
        url = f"{base_url}/cgi-bin/configManager.cgi?action=getConfig&name={name}"
        response = session.get(url, timeout=5)

        if response.status_code == 200 and "Error" not in response.text[:20]:
            print(f"✅ {name}")
            print(f"   {response.text[:300]}")
            print()
    except Exception as e:
        pass

print("\n" + "="*60)
print("Testing Face Database/Person Management:")
print("="*60 + "\n")

# Try person/user management endpoints
person_endpoints = [
    "/cgi-bin/recordFinder.cgi?action=factory.create&name=Person",
    "/cgi-bin/recordFinder.cgi?action=factory.create&name=AccessControlCard",
    "/cgi-bin/AccessUser.cgi?action=getAll",
    "/cgi-bin/AccessUser.cgi?action=getConfig",
    "/cgi-bin/AccessCardDB.cgi?action=getAll",
]

for endpoint in person_endpoints:
    try:
        url = base_url + endpoint
        response = session.get(url, timeout=5)

        if response.status_code == 200:
            print(f"✅ {endpoint}")
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.text[:500]}")
            print()
    except Exception as e:
        pass

print("\n" + "="*60)
print("Checking Available CGI Capabilities:")
print("="*60 + "\n")

# Check what CGI scripts are available
cgi_list_endpoints = [
    "/cgi-bin/configManager.cgi?action=getConfig&name=All",  # This might be too big
    "/cgi-bin/magicBox.cgi?action=getProductDefinition",
    "/cgi-bin/magicBox.cgi?action=getSoftwareVersion",
]

for endpoint in cgi_list_endpoints:
    try:
        url = base_url + endpoint
        response = session.get(url, timeout=5)

        if response.status_code == 200:
            print(f"✅ {endpoint}")
            # Only show first 500 chars to avoid too much output
            print(f"   {response.text[:500]}")
            print()
    except Exception as e:
        pass

print("\n" + "="*60)
print("Checking Smart Functionality:")
print("="*60 + "\n")

# Check intelligent/smart features
smart_checks = [
    "/cgi-bin/devVideoInput.cgi?action=getCaps",
    "/cgi-bin/devVideoInput.cgi?action=getCollect",
]

for endpoint in smart_checks:
    try:
        url = base_url + endpoint
        response = session.get(url, timeout=5)

        if response.status_code == 200:
            print(f"✅ {endpoint}")
            print(f"   {response.text[:500]}")
            print()
    except Exception as e:
        pass

print("\n✅ Exploration complete!")
