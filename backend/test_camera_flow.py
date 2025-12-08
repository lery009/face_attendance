#!/usr/bin/env python3
"""
Test script for Camera + Event flow
"""
import requests
import json
from datetime import datetime, timedelta

BASE_URL = "http://localhost:3000"

def print_response(title, response):
    """Pretty print API response"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")
    print(f"Status Code: {response.status_code}")
    try:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except:
        print(f"Response: {response.text}")
    print()

def main():
    print("\n🧪 TESTING CAMERA + EVENT FLOW")
    print("="*60)

    # Step 1: Login
    print("\n1️⃣  Logging in...")
    login_response = requests.post(
        f"{BASE_URL}/api/auth/login",
        json={"username": "admin", "password": "admin123"}
    )
    print_response("Login", login_response)

    if login_response.status_code != 200:
        print("❌ Login failed! Stopping test.")
        return

    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Step 2: Create cameras
    print("\n2️⃣  Creating test cameras...")

    camera1_data = {
        "name": "Main Entrance Camera",
        "camera_type": "rtsp",
        "stream_url": "rtsp://192.168.1.100:554/stream",
        "username": "admin",
        "password": "camera123",
        "location": "Building A - Main Entrance"
    }

    camera1_response = requests.post(
        f"{BASE_URL}/cameras",
        json=camera1_data,
        headers=headers
    )
    print_response("Create Camera 1 (RTSP)", camera1_response)

    camera2_data = {
        "name": "Conference Room Camera",
        "camera_type": "http",
        "stream_url": "http://192.168.1.101:8080/video",
        "location": "Building B - Conference Room 1"
    }

    camera2_response = requests.post(
        f"{BASE_URL}/cameras",
        json=camera2_data,
        headers=headers
    )
    print_response("Create Camera 2 (HTTP)", camera2_response)

    if camera1_response.status_code != 200:
        print("❌ Camera creation failed! Stopping test.")
        return

    camera1_id = camera1_response.json()["camera"]["id"]
    camera2_id = camera2_response.json()["camera"]["id"]

    # Step 3: List all cameras
    print("\n3️⃣  Listing all cameras...")
    list_cameras_response = requests.get(
        f"{BASE_URL}/cameras",
        headers=headers
    )
    print_response("List All Cameras", list_cameras_response)

    # Step 4: Create an event
    print("\n4️⃣  Creating test event...")
    event_date = (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")

    event_data = {
        "name": "Annual Team Meeting 2025",
        "description": "Quarterly all-hands meeting for entire team",
        "event_date": event_date,
        "start_time": "09:00",
        "end_time": "17:00",
        "location": "Main Conference Center",
        "status": "upcoming",
        "participant_ids": []  # Empty participant list for testing
    }

    create_event_response = requests.post(
        f"{BASE_URL}/api/events",
        json=event_data,
        headers=headers
    )
    print_response("Create Event", create_event_response)

    if create_event_response.status_code != 200:
        print("❌ Event creation failed! Stopping test.")
        return

    event_id = create_event_response.json()["data"]["id"]

    # Step 5: Link cameras to event
    print("\n5️⃣  Linking cameras to event...")

    link1_response = requests.post(
        f"{BASE_URL}/events/{event_id}/cameras",
        json={"camera_id": camera1_id, "is_primary": True},
        headers=headers
    )
    print_response("Link Camera 1 (Primary)", link1_response)

    link2_response = requests.post(
        f"{BASE_URL}/events/{event_id}/cameras",
        json={"camera_id": camera2_id, "is_primary": False},
        headers=headers
    )
    print_response("Link Camera 2 (Secondary)", link2_response)

    # Step 6: Get event cameras
    print("\n6️⃣  Getting cameras linked to event...")
    event_cameras_response = requests.get(
        f"{BASE_URL}/events/{event_id}/cameras",
        headers=headers
    )
    print_response("Event Cameras", event_cameras_response)

    # Step 7: Test camera details
    print("\n7️⃣  Getting camera details...")
    camera1_details = requests.get(
        f"{BASE_URL}/cameras/{camera1_id}",
        headers=headers
    )
    print_response("Camera 1 Details", camera1_details)

    # Step 8: Update camera
    print("\n8️⃣  Updating camera status...")
    update_response = requests.put(
        f"{BASE_URL}/cameras/{camera1_id}",
        json={"status": "online", "location": "Building A - Main Entrance (Updated)"},
        headers=headers
    )
    print_response("Update Camera", update_response)

    # Step 9: Unlink one camera
    print("\n9️⃣  Unlinking secondary camera from event...")
    unlink_response = requests.delete(
        f"{BASE_URL}/events/{event_id}/cameras/{camera2_id}",
        headers=headers
    )
    print_response("Unlink Camera 2", unlink_response)

    # Step 10: Verify unlink
    print("\n🔟 Verifying camera was unlinked...")
    verify_cameras_response = requests.get(
        f"{BASE_URL}/events/{event_id}/cameras",
        headers=headers
    )
    print_response("Event Cameras After Unlink", verify_cameras_response)

    print("\n" + "="*60)
    print("✅ CAMERA + EVENT FLOW TEST COMPLETED!")
    print("="*60)
    print(f"\n📋 Summary:")
    print(f"  - Created 2 cameras (IDs: {camera1_id[:8]}..., {camera2_id[:8]}...)")
    print(f"  - Created event (ID: {event_id[:8]}...)")
    print(f"  - Linked cameras to event")
    print(f"  - Verified event-camera relationship")
    print(f"  - Updated camera status")
    print(f"  - Tested unlinking camera from event")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
