import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';

class LivenessDetector {
  // PASSIVE Liveness Detection - For Walk-Through Attendance
  // No user challenges required - detects natural movement

  // Track face across frames
  int consecutiveFramesWithFace = 0;
  DateTime? firstDetectionTime;

  // Track natural movement
  List<double> headYAngles = []; // Left/right rotation
  List<double> headXAngles = []; // Up/down rotation
  List<double> headZAngles = []; // Tilt
  List<double> faceWidths = [];  // Face size changes as person walks

  bool hasDetectedMovement = false;
  bool isVerified = false;

  // Thresholds
  static const int MIN_FRAMES_REQUIRED = 8; // Must see face for 8+ frames
  static const double MIN_POSE_VARIATION = 3.0; // Degrees of natural head movement
  static const double MIN_SIZE_VARIATION = 10.0; // Pixels of face size change
  static const int MAX_SAMPLES = 15; // Keep last 15 frames

  // Reset detector
  void reset() {
    consecutiveFramesWithFace = 0;
    firstDetectionTime = null;
    headYAngles.clear();
    headXAngles.clear();
    headZAngles.clear();
    faceWidths.clear();
    hasDetectedMovement = false;
    isVerified = false;
    print("🔄 Passive liveness detector RESET");
  }

  // PASSIVE Liveness Check - Detects natural walking movement
  LivenessResult checkLiveness(Face face) {
    consecutiveFramesWithFace++;
    firstDetectionTime ??= DateTime.now();

    // Collect face data
    double? headY = face.headEulerAngleY;
    double? headX = face.headEulerAngleX;
    double? headZ = face.headEulerAngleZ;
    double faceWidth = face.boundingBox.width;

    // Store measurements
    if (headY != null) {
      headYAngles.add(headY);
      if (headYAngles.length > MAX_SAMPLES) headYAngles.removeAt(0);
    }
    if (headX != null) {
      headXAngles.add(headX);
      if (headXAngles.length > MAX_SAMPLES) headXAngles.removeAt(0);
    }
    if (headZ != null) {
      headZAngles.add(headZ);
      if (headZAngles.length > MAX_SAMPLES) headZAngles.removeAt(0);
    }
    faceWidths.add(faceWidth);
    if (faceWidths.length > MAX_SAMPLES) faceWidths.removeAt(0);

    // Need minimum frames
    if (consecutiveFramesWithFace < MIN_FRAMES_REQUIRED) {
      int progress = (consecutiveFramesWithFace / MIN_FRAMES_REQUIRED * 100).toInt();
      return LivenessResult(
        isLive: false,
        score: progress,
        status: "👤 Detecting... $consecutiveFramesWithFace/$MIN_FRAMES_REQUIRED",
        hints: ["Keep looking at camera"],
        hasMotion: false,
        blinkCount: 0,
      );
    }

    // Already verified - return success
    if (isVerified) {
      return LivenessResult(
        isLive: true,
        score: 100,
        status: "✅ Live Person Detected",
        hints: ["Recognition active"],
        hasMotion: true,
        blinkCount: 0,
      );
    }

    // Check for natural movement
    bool hasNaturalMovement = _detectNaturalMovement();

    if (hasNaturalMovement) {
      isVerified = true;
      hasDetectedMovement = true;
      print("✅ PASSIVE LIVENESS VERIFIED - Natural movement detected!");
      return LivenessResult(
        isLive: true,
        score: 100,
        status: "✅ Live Person Detected",
        hints: ["Recognition active"],
        hasMotion: true,
        blinkCount: 0,
      );
    }

    // Still analyzing
    return LivenessResult(
      isLive: false,
      score: 50,
      status: "🔍 Analyzing movement...",
      hints: ["Walk naturally through"],
      hasMotion: false,
      blinkCount: 0,
    );
  }

  // Detect natural movement from walking
  bool _detectNaturalMovement() {
    // Need enough samples to analyze
    if (headYAngles.length < MIN_FRAMES_REQUIRED ||
        headXAngles.length < MIN_FRAMES_REQUIRED ||
        faceWidths.length < MIN_FRAMES_REQUIRED) {
      return false;
    }

    // Calculate variation in head pose (natural head bobbing while walking)
    double yVariation = _calculateVariation(headYAngles);
    double xVariation = _calculateVariation(headXAngles);
    double zVariation = _calculateVariation(headZAngles);

    // Calculate variation in face size (approaching/moving away from camera)
    double sizeVariation = _calculateVariation(faceWidths);

    print("📊 Movement Analysis:");
    print("   Y-axis: ${yVariation.toStringAsFixed(2)}° (left/right)");
    print("   X-axis: ${xVariation.toStringAsFixed(2)}° (up/down)");
    print("   Z-axis: ${zVariation.toStringAsFixed(2)}° (tilt)");
    print("   Size: ${sizeVariation.toStringAsFixed(2)}px");

    // Check if there's natural movement in ANY axis OR size change
    bool hasHeadMovement = yVariation > MIN_POSE_VARIATION ||
                           xVariation > MIN_POSE_VARIATION ||
                           zVariation > MIN_POSE_VARIATION;

    bool hasSizeChange = sizeVariation > MIN_SIZE_VARIATION;

    // Natural movement detected if EITHER condition met
    if (hasHeadMovement || hasSizeChange) {
      print("✅ Natural movement detected!");
      print("   Head movement: $hasHeadMovement");
      print("   Size change: $hasSizeChange");
      return true;
    }

    print("❌ No natural movement - likely static photo");
    return false;
  }

  // Calculate variation (standard deviation) in a list of values
  double _calculateVariation(List<double> values) {
    if (values.isEmpty) return 0.0;

    // Calculate mean
    double mean = values.reduce((a, b) => a + b) / values.length;

    // Calculate variance
    double variance = values
        .map((value) => pow(value - mean, 2))
        .reduce((a, b) => a + b) / values.length;

    // Return standard deviation
    return sqrt(variance);
  }
}

class LivenessResult {
  final bool isLive;
  final int score;
  final String status;
  final List<String> hints;
  final bool hasMotion;
  final int blinkCount;

  LivenessResult({
    required this.isLive,
    required this.score,
    required this.status,
    required this.hints,
    required this.hasMotion,
    required this.blinkCount,
  });
}
