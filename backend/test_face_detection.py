"""
Diagnostic Script to Test Face Detection
Run this to diagnose why face detection is failing
"""
import sys
import base64
from face_processor import FaceProcessor
from PIL import Image
import numpy as np
import io

def test_face_detection():
    print("\n" + "="*60)
    print("🔍 FACE DETECTION DIAGNOSTIC TEST")
    print("="*60 + "\n")

    # Initialize face processor
    print("1️⃣ Initializing FaceProcessor...")
    try:
        processor = FaceProcessor()
        print(f"   ✅ FaceProcessor initialized")
        print(f"   📊 Model: {processor.model}")
        print(f"   📊 Tolerance: {processor.tolerance}")
    except Exception as e:
        print(f"   ❌ Failed to initialize: {e}")
        return

    # Test with a simple test image (create a blank image)
    print("\n2️⃣ Testing with blank test image...")
    try:
        # Create a simple 640x480 RGB image
        test_image = np.zeros((480, 640, 3), dtype=np.uint8)
        test_image.fill(255)  # White image

        # Add a simple "face-like" rectangle (won't be detected as a face, just testing the pipeline)
        test_image[100:300, 200:400] = [200, 150, 150]  # Skin-tone rectangle

        print(f"   ✅ Created test image: {test_image.shape}")

        # Convert to base64
        pil_image = Image.fromarray(test_image)
        buffered = io.BytesIO()
        pil_image.save(buffered, format="JPEG")
        test_base64 = base64.b64encode(buffered.getvalue()).decode()

        print(f"   ✅ Converted to base64: {len(test_base64)} characters")

        # Test decoding
        decoded = processor.decode_base64_image(test_base64)
        print(f"   ✅ Decoded image shape: {decoded.shape}")
        print(f"   ✅ Decoded image dtype: {decoded.dtype}")
        print(f"   ✅ Decoded image range: {decoded.min()} - {decoded.max()}")

        # Test face detection
        faces = processor.detect_faces(decoded)
        print(f"   📊 Faces detected in blank image: {len(faces)}")

    except Exception as e:
        print(f"   ❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

    # Provide instructions for real image test
    print("\n3️⃣ To test with a real image from the frontend:")
    print("   Add this to backend main.py in detect_and_recognize():")
    print("   ───────────────────────────────────────────────────────")
    print("   # DEBUG: Save received image")
    print("   with open('received_image.txt', 'w') as f:")
    print("       f.write(request.image[:500])  # First 500 chars")
    print("   print(f'📝 Image length: {len(request.image)} chars')")
    print("   print(f'📝 Image preview: {request.image[:100]}')")
    print("   ───────────────────────────────────────────────────────")

    print("\n4️⃣ Common Issues and Fixes:")
    print("   Issue: 'No faces detected'")
    print("   Fix 1: Try changing model from 'hog' to 'cnn' in config.py")
    print("   Fix 2: Check image quality - ensure good lighting")
    print("   Fix 3: Check face size - face should be at least 80x80 pixels")
    print("   Fix 4: Ensure face is looking forward, not tilted")

    print("\n5️⃣ Testing face_recognition library directly...")
    try:
        import face_recognition
        print("   ✅ face_recognition library imported successfully")

        # Test on blank image
        test_locations = face_recognition.face_locations(test_image, model="hog")
        print(f"   📊 HOG model detected: {len(test_locations)} faces")

        # Try CNN if available
        try:
            test_locations_cnn = face_recognition.face_locations(test_image, model="cnn")
            print(f"   📊 CNN model detected: {len(test_locations_cnn)} faces")
            print("   ✅ Both HOG and CNN models available")
        except Exception as e:
            print(f"   ⚠️ CNN model not available: {e}")

    except Exception as e:
        print(f"   ❌ face_recognition test failed: {e}")

    print("\n" + "="*60)
    print("✅ DIAGNOSTIC TEST COMPLETE")
    print("="*60 + "\n")

if __name__ == "__main__":
    test_face_detection()
