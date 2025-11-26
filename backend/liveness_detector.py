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
            blur_score = self._blur_detection(gray)
            reflection_score = self._reflection_detection(face_image)

            # Combine scores (weighted average with more emphasis on anti-spoofing)
            combined_score = (
                texture_score * 0.25 +
                frequency_score * 0.25 +
                color_score * 0.20 +
                blur_score * 0.15 +
                reflection_score * 0.15
            )

            is_live = combined_score > self.threshold

            print(f"🔍 Liveness Analysis:")
            print(f"   Texture: {texture_score:.3f}")
            print(f"   Frequency: {frequency_score:.3f}")
            print(f"   Color: {color_score:.3f}")
            print(f"   Blur: {blur_score:.3f}")
            print(f"   Reflection: {reflection_score:.3f}")
            print(f"   Combined: {combined_score:.3f} (Threshold: {self.threshold})")
            print(f"   Result: {'✅ LIVE' if is_live else '❌ PHOTO/SCREEN'}")

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

        # Normalize variance score - STRICTER thresholds
        # Real faces typically have variance > 120
        # Photos often have variance < 60
        score = min(variance / 180.0, 1.0)

        return score

    def _blur_detection(self, gray_image):
        """
        Detect unnatural blur patterns (photos/screens have different blur)

        Args:
            gray_image: Grayscale face image

        Returns:
            float: Blur score (0-1, higher = more likely real)
        """
        # Calculate sharpness using variance of Laplacian
        laplacian = cv2.Laplacian(gray_image, cv2.CV_64F)
        sharpness = laplacian.var()

        # Photos/printed images often have uniform blur or excessive sharpness
        # Real faces have natural sharpness variation

        # Also check gradient magnitude distribution
        sobelx = cv2.Sobel(gray_image, cv2.CV_64F, 1, 0, ksize=3)
        sobely = cv2.Sobel(gray_image, cv2.CV_64F, 0, 1, ksize=3)
        gradient_magnitude = np.sqrt(sobelx**2 + sobely**2)
        gradient_std = gradient_magnitude.std()

        # Real faces: sharpness 50-500, gradient_std > 15
        # Photos: often outside this range
        sharpness_score = 1.0 if 50 < sharpness < 500 else 0.3
        gradient_score = min(gradient_std / 25.0, 1.0)

        score = (sharpness_score + gradient_score) / 2
        return score

    def _reflection_detection(self, rgb_image):
        """
        Detect screen reflections and glare (common in photos/screens)

        Args:
            rgb_image: RGB face image

        Returns:
            float: Reflection score (0-1, higher = more likely real)
        """
        if len(rgb_image.shape) != 3:
            return 0.5

        # Convert to grayscale for reflection analysis
        gray = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2GRAY)

        # Detect very bright spots (reflections/glare)
        bright_threshold = 240
        very_bright_pixels = np.sum(gray > bright_threshold)
        total_pixels = gray.shape[0] * gray.shape[1]
        bright_ratio = very_bright_pixels / total_pixels

        # Real faces: < 2% very bright pixels
        # Photos/screens: often > 5% (reflections, glare)
        if bright_ratio > 0.05:
            reflection_penalty = 0.3
        elif bright_ratio > 0.02:
            reflection_penalty = 0.6
        else:
            reflection_penalty = 1.0

        # Check for unnatural contrast (screens often have higher contrast)
        contrast = gray.std()
        # Real faces: contrast 30-60
        # Photos/screens: often > 70 or < 20
        if 30 < contrast < 60:
            contrast_score = 1.0
        else:
            contrast_score = 0.5

        score = (reflection_penalty + contrast_score) / 2
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
