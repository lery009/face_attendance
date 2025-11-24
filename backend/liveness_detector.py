"""
Liveness Detection Module
Detects if face is from a real person or a photo/video
"""
import cv2
import numpy as np
from scipy import ndimage
from config import settings

class LivenessDetector:
    """Simple liveness detection using texture analysis"""

    def __init__(self):
        self.threshold = settings.LIVENESS_THRESHOLD

    def check_liveness(self, face_image):
        """
        Check if face is live using multiple techniques

        Args:
            face_image: numpy array of face image (RGB)

        Returns:
            tuple: (is_live: bool, confidence: float, method: str)
        """
        if not settings.ENABLE_LIVENESS:
            return True, 1.0, "disabled"

        try:
            # Convert to grayscale
            if len(face_image.shape) == 3:
                gray = cv2.cvtColor(face_image, cv2.COLOR_RGB2GRAY)
            else:
                gray = face_image

            # Multiple detection methods
            texture_score = self._texture_analysis(gray)
            frequency_score = self._frequency_analysis(gray)
            color_score = self._color_diversity_analysis(face_image)

            # Combine scores (weighted average)
            combined_score = (
                texture_score * 0.4 +
                frequency_score * 0.3 +
                color_score * 0.3
            )

            is_live = combined_score > self.threshold

            print(f"🔍 Liveness Analysis:")
            print(f"   Texture: {texture_score:.3f}")
            print(f"   Frequency: {frequency_score:.3f}")
            print(f"   Color: {color_score:.3f}")
            print(f"   Combined: {combined_score:.3f}")
            print(f"   Result: {'✅ LIVE' if is_live else '❌ PHOTO'}")

            return is_live, combined_score, "multi_method"

        except Exception as e:
            print(f"❌ Liveness detection error: {e}")
            # Fail open (assume live) to avoid blocking real users
            return True, 0.5, "error"

    def _texture_analysis(self, gray_image):
        """
        Analyze texture patterns (photos have different texture than real faces)

        Args:
            gray_image: Grayscale face image

        Returns:
            float: Texture score (0-1, higher = more likely real)
        """
        # Calculate Local Binary Pattern (LBP) variance
        # Real faces have more texture variation than photos
        laplacian = cv2.Laplacian(gray_image, cv2.CV_64F)
        variance = laplacian.var()

        # Normalize variance score
        # Real faces typically have variance > 100
        # Photos often have variance < 50
        score = min(variance / 150.0, 1.0)

        return score

    def _frequency_analysis(self, gray_image):
        """
        Analyze frequency domain (photos have screen moire patterns)

        Args:
            gray_image: Grayscale face image

        Returns:
            float: Frequency score (0-1, higher = more likely real)
        """
        # Apply FFT to detect periodic patterns (screen pixels)
        f_transform = np.fft.fft2(gray_image)
        f_shift = np.fft.fftshift(f_transform)
        magnitude_spectrum = np.abs(f_shift)

        # Real faces have smoother frequency distribution
        # Photos/screens have periodic patterns
        h, w = magnitude_spectrum.shape
        center_h, center_w = h // 2, w // 2

        # Check high-frequency content (edges of spectrum)
        edge_region = magnitude_spectrum[0:10, :].sum() + magnitude_spectrum[-10:, :].sum()
        total = magnitude_spectrum.sum()

        # Photos/screens have more high-frequency content
        high_freq_ratio = edge_region / (total + 1e-6)

        # Lower ratio = more likely real face
        score = 1.0 - min(high_freq_ratio * 10, 1.0)

        return score

    def _color_diversity_analysis(self, rgb_image):
        """
        Analyze color diversity (photos/screens have less color variation)

        Args:
            rgb_image: RGB face image

        Returns:
            float: Color diversity score (0-1, higher = more likely real)
        """
        if len(rgb_image.shape) != 3:
            return 0.5

        # Calculate color histogram
        hist_r = cv2.calcHist([rgb_image], [0], None, [256], [0, 256])
        hist_g = cv2.calcHist([rgb_image], [1], None, [256], [0, 256])
        hist_b = cv2.calcHist([rgb_image], [2], None, [256], [0, 256])

        # Calculate entropy (measure of color diversity)
        def entropy(hist):
            hist = hist / (hist.sum() + 1e-6)
            hist = hist[hist > 0]
            return -np.sum(hist * np.log2(hist))

        r_entropy = entropy(hist_r)
        g_entropy = entropy(hist_g)
        b_entropy = entropy(hist_b)

        avg_entropy = (r_entropy + g_entropy + b_entropy) / 3

        # Real faces typically have entropy > 5
        # Photos often have entropy < 4
        score = min(avg_entropy / 6.0, 1.0)

        return score

    def check_liveness_advanced(self, face_frames):
        """
        Advanced liveness check using multiple frames
        (For future implementation with video streams)

        Args:
            face_frames: List of face images from consecutive frames

        Returns:
            tuple: (is_live: bool, confidence: float, method: str)
        """
        if len(face_frames) < 3:
            return self.check_liveness(face_frames[0])

        # TODO: Implement multi-frame analysis
        # - Track optical flow (real faces move)
        # - Detect head pose changes
        # - Check for depth information
        # - Analyze temporal consistency

        # For now, use single frame analysis on first frame
        return self.check_liveness(face_frames[0])
