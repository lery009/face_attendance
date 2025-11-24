"""
Face Detection and Recognition Module
"""
import face_recognition
import numpy as np
import cv2
from PIL import Image
import io
import base64
from typing import List, Tuple, Optional
from config import settings
from liveness_detector import LivenessDetector

class FaceProcessor:
    """Handle face detection, recognition, and embedding generation"""

    def __init__(self):
        self.tolerance = settings.FACE_RECOGNITION_TOLERANCE
        self.model = settings.FACE_DETECTION_MODEL
        self.liveness_detector = LivenessDetector()

    def decode_base64_image(self, base64_string: str) -> np.ndarray:
        """
        Decode base64 image string to numpy array

        Args:
            base64_string: Base64 encoded image

        Returns:
            numpy array (RGB)
        """
        try:
            # Remove data URL prefix if present
            if "base64," in base64_string:
                base64_string = base64_string.split("base64,")[1]

            # Decode base64
            image_bytes = base64.b64decode(base64_string)

            # Convert to PIL Image
            image = Image.open(io.BytesIO(image_bytes))

            # Convert to RGB
            if image.mode != 'RGB':
                image = image.convert('RGB')

            # Convert to numpy array
            return np.array(image)

        except Exception as e:
            print(f"❌ Error decoding image: {e}")
            raise ValueError(f"Invalid image data: {e}")

    def detect_faces(self, image: np.ndarray) -> List[Tuple]:
        """
        Detect all faces in image

        Args:
            image: numpy array (RGB)

        Returns:
            List of tuples: (face_location, face_encoding)
        """
        try:
            # Detect face locations
            face_locations = face_recognition.face_locations(
                image,
                model=self.model,
                number_of_times_to_upsample=1
            )

            if not face_locations:
                print("ℹ️ No faces detected")
                return []

            # Limit number of faces
            if len(face_locations) > settings.MAX_FACES_PER_IMAGE:
                print(f"⚠️ Too many faces detected ({len(face_locations)}), limiting to {settings.MAX_FACES_PER_IMAGE}")
                face_locations = face_locations[:settings.MAX_FACES_PER_IMAGE]

            # Generate face encodings (embeddings)
            face_encodings = face_recognition.face_encodings(
                image,
                known_face_locations=face_locations,
                num_jitters=1
            )

            print(f"✅ Detected {len(face_locations)} face(s)")

            return list(zip(face_locations, face_encodings))

        except Exception as e:
            print(f"❌ Face detection error: {e}")
            return []

    def extract_face_crop(self, image: np.ndarray, face_location: Tuple) -> np.ndarray:
        """
        Extract face region from image

        Args:
            image: Full image
            face_location: (top, right, bottom, left)

        Returns:
            Face crop as numpy array
        """
        top, right, bottom, left = face_location

        # Add padding
        padding = 20
        height, width = image.shape[:2]
        top = max(0, top - padding)
        right = min(width, right + padding)
        bottom = min(height, bottom + padding)
        left = max(0, left - padding)

        # Extract face
        face_crop = image[top:bottom, left:right]

        return face_crop

    def match_face(self, face_encoding: np.ndarray, employee_embeddings: List[Tuple[str, List[float]]]) -> Optional[Tuple[str, float]]:
        """
        Match face encoding against database of employee embeddings

        Args:
            face_encoding: 128-d face encoding vector
            employee_embeddings: List of (employee_id, embedding) tuples

        Returns:
            Tuple of (employee_id, confidence) or None if no match
        """
        if not employee_embeddings:
            return None

        best_match_id = None
        best_distance = float('inf')

        for employee_id, stored_embedding in employee_embeddings:
            # Convert stored embedding to numpy array
            stored_array = np.array(stored_embedding)

            # Calculate face distance (lower = better match)
            distance = face_recognition.face_distance([stored_array], face_encoding)[0]

            if distance < best_distance:
                best_distance = distance
                best_match_id = employee_id

        # Check if best match is within tolerance
        if best_distance <= self.tolerance:
            # Convert distance to confidence (0-1)
            confidence = 1.0 - best_distance
            print(f"✅ Match found: {best_match_id} (confidence: {confidence:.2f})")
            return (best_match_id, confidence)

        print(f"ℹ️ No match found (best distance: {best_distance:.2f})")
        return None

    def process_image_for_recognition(self, base64_image: str, employee_embeddings: List[Tuple[str, str, List[float]]]) -> List[dict]:
        """
        Complete face detection and recognition pipeline

        Args:
            base64_image: Base64 encoded image
            employee_embeddings: List of (employee_id, name, embedding) tuples

        Returns:
            List of detected face results
        """
        try:
            # Decode image
            image = self.decode_base64_image(base64_image)

            # Detect faces
            detected_faces = self.detect_faces(image)

            if not detected_faces:
                return []

            results = []

            for face_location, face_encoding in detected_faces:
                # Extract face crop for liveness detection
                face_crop = self.extract_face_crop(image, face_location)

                # Check liveness
                is_live, liveness_confidence, liveness_method = self.liveness_detector.check_liveness(face_crop)

                # Convert face_location to bounding box
                top, right, bottom, left = face_location
                bounding_box = {
                    "x": int(left),
                    "y": int(top),
                    "width": int(right - left),
                    "height": int(bottom - top)
                }

                # Match face against database
                match_result = self.match_face(face_encoding, [(emp_id, emb) for emp_id, _, emb in employee_embeddings])

                if match_result:
                    employee_id, confidence = match_result

                    # Find employee name
                    employee_name = next((name for eid, name, _ in employee_embeddings if eid == employee_id), "Unknown")

                    results.append({
                        "boundingBox": bounding_box,
                        "name": employee_name,
                        "employeeId": employee_id,
                        "confidence": float(confidence),
                        "isLive": is_live,
                        "livenessConfidence": float(liveness_confidence)
                    })
                else:
                    # Unknown face
                    results.append({
                        "boundingBox": bounding_box,
                        "name": "Unknown",
                        "employeeId": "",
                        "confidence": 0.0,
                        "isLive": is_live,
                        "livenessConfidence": float(liveness_confidence)
                    })

            return results

        except Exception as e:
            print(f"❌ Processing error: {e}")
            raise

    def generate_face_embedding(self, base64_image: str) -> Tuple[Optional[List[float]], Optional[Tuple]]:
        """
        Generate face embedding from image (for registration)

        Args:
            base64_image: Base64 encoded image

        Returns:
            Tuple of (embedding, face_location) or (None, None) if no face
        """
        try:
            # Decode image
            image = self.decode_base64_image(base64_image)

            # Detect faces
            detected_faces = self.detect_faces(image)

            if not detected_faces:
                print("❌ No face detected in registration image")
                return None, None

            if len(detected_faces) > 1:
                print("⚠️ Multiple faces detected, using first face")

            # Use first face
            face_location, face_encoding = detected_faces[0]

            # Convert to list for JSON storage
            embedding_list = face_encoding.tolist()

            print(f"✅ Generated embedding: {len(embedding_list)} dimensions")

            return embedding_list, face_location

        except Exception as e:
            print(f"❌ Embedding generation error: {e}")
            return None, None
