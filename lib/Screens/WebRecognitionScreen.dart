import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../main.dart';

// WEB-COMPATIBLE Recognition Screen
// Works on: Web Browser, Mobile
// Face detection happens on SERVER-SIDE

class WebRecognitionScreen extends StatefulWidget {
  const WebRecognitionScreen({super.key});

  @override
  State<WebRecognitionScreen> createState() => _WebRecognitionScreenState();
}

class _WebRecognitionScreenState extends State<WebRecognitionScreen> {
  CameraController? controller;
  bool isBusy = false;
  final ApiService apiService = ApiService();

  // Recognition results from server
  List<DetectedFace> detectedFaces = [];
  String statusMessage = "Initializing camera...";

  // Frame processing
  Timer? frameTimer;
  static const int FRAME_INTERVAL_MS = 1000; // Process every 1 second

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      // Use first available camera (webcam on web)
      final camera = cameras.first;

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() {
        statusMessage = "Camera ready - Processing...";
      });

      // Start frame processing timer
      startFrameProcessing();
    } catch (e) {
      print("❌ Camera error: $e");
      setState(() {
        statusMessage = "Camera error: $e";
      });
    }
  }

  void startFrameProcessing() {
    frameTimer = Timer.periodic(Duration(milliseconds: FRAME_INTERVAL_MS), (timer) async {
      if (!isBusy && controller != null && controller!.value.isInitialized) {
        await processFrame();
      }
    });
  }

  Future<void> processFrame() async {
    if (isBusy) return;

    setState(() {
      isBusy = true;
    });

    try {
      // Capture current frame
      final XFile imageFile = await controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Send to backend for detection and recognition
      final response = await apiService.detectAndRecognizeFaces(
        imageBase64: base64Image,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        if (data['faces'] != null && data['faces'] is List) {
          List<DetectedFace> faces = (data['faces'] as List)
              .map((faceJson) => DetectedFace.fromJson(faceJson))
              .toList();

          setState(() {
            detectedFaces = faces;
            if (faces.isEmpty) {
              statusMessage = "No face detected";
            } else if (faces.length == 1) {
              statusMessage = faces[0].isLive
                  ? "✅ ${faces[0].name} - Live"
                  : "🔍 Analyzing...";
            } else {
              statusMessage = "${faces.length} faces detected";
            }
          });

          // Log recognized faces
          for (var face in faces) {
            if (face.name != "Unknown" && face.isLive) {
              print("✅ RECOGNIZED: ${face.name} (${face.employeeId}) - ${(face.confidence * 100).toStringAsFixed(1)}%");
              // Here you can trigger attendance marking
            }
          }
        }
      } else {
        setState(() {
          detectedFaces = [];
          statusMessage = "Processing...";
        });
      }
    } catch (e) {
      print("❌ Frame processing error: $e");
    } finally {
      setState(() {
        isBusy = false;
      });
    }
  }

  @override
  void dispose() {
    frameTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Face Recognition (Web)'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          // Camera preview
          if (controller != null && controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: CameraPreview(controller!),
              ),
            )
          else
            Center(
              child: CircularProgressIndicator(),
            ),

          // Face detection overlay
          if (controller != null && controller!.value.isInitialized)
            CustomPaint(
              painter: FaceOverlayPainter(
                detectedFaces,
                Size(
                  controller!.value.previewSize!.height,
                  controller!.value.previewSize!.width,
                ),
              ),
              size: Size.infinite,
            ),

          // Status banner
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    detectedFaces.any((f) => f.isLive)
                        ? Icons.check_circle
                        : Icons.face,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Face list
          if (detectedFaces.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: detectedFaces.map((face) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            face.isLive ? Icons.verified : Icons.pending,
                            color: face.isLive ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              face.name != "Unknown"
                                  ? "${face.name} (${(face.confidence * 100).toStringAsFixed(0)}%)"
                                  : "Unknown",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Model for detected face from server
class DetectedFace {
  final BoundingBox boundingBox;
  final String name;
  final String employeeId;
  final double confidence;
  final bool isLive;

  DetectedFace({
    required this.boundingBox,
    required this.name,
    required this.employeeId,
    required this.confidence,
    required this.isLive,
  });

  factory DetectedFace.fromJson(Map<String, dynamic> json) {
    return DetectedFace(
      boundingBox: BoundingBox.fromJson(json['boundingBox'] ?? {}),
      name: json['name'] ?? 'Unknown',
      employeeId: json['employeeId'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      isLive: json['isLive'] ?? false,
    );
  }
}

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
    );
  }
}

// Custom painter for face detection overlay
class FaceOverlayPainter extends CustomPainter {
  final List<DetectedFace> faces;
  final Size imageSize;

  FaceOverlayPainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (final face in faces) {
      final box = face.boundingBox;

      // Scale bounding box to screen size
      final rect = Rect.fromLTWH(
        box.x * scaleX,
        box.y * scaleY,
        box.width * scaleX,
        box.height * scaleY,
      );

      // Draw rectangle
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = face.isLive ? Colors.green : Colors.yellow;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(8)),
        paint,
      );

      // Draw name label
      if (face.name != "Unknown") {
        final textSpan = TextSpan(
          text: face.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            backgroundColor: face.isLive ? Colors.green : Colors.orange,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(rect.left, rect.top - 24),
        );
      }
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) => true;
}
