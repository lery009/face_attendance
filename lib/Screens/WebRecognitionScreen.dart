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

class _WebRecognitionScreenState extends State<WebRecognitionScreen> with SingleTickerProviderStateMixin {
  CameraController? controller;
  bool isBusy = false;
  final ApiService apiService = ApiService();

  // Recognition results from server
  List<DetectedFace> detectedFaces = [];
  DetectedFace? centerFace; // The face closest to center
  String statusMessage = "Initializing camera...";

  // Event management
  Map<String, dynamic>? activeEvent;
  bool isLoadingEvents = true;
  List<Map<String, dynamic>> ongoingEvents = [];

  // Welcome card animation
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  DetectedFace? _recognizedPerson;
  bool _showWelcomeCard = false;

  // Frame processing
  Timer? frameTimer;
  static const int FRAME_INTERVAL_MS = 1000; // Process every 1 second

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.elasticOut,
    );
    loadOngoingEvents();
    initializeCamera();
  }

  Future<void> loadOngoingEvents() async {
    setState(() => isLoadingEvents = true);

    try {
      final response = await apiService.getAllEvents(status: 'ongoing');

      if (response['success'] == true && response['events'] != null) {
        final events = response['events'] as List<dynamic>;

        setState(() {
          ongoingEvents = events.map((e) => e as Map<String, dynamic>).toList();
          activeEvent = ongoingEvents.isNotEmpty ? ongoingEvents[0] : null;
          isLoadingEvents = false;

          if (activeEvent != null) {
            statusMessage = "Event: ${activeEvent!['name']}";
          } else {
            statusMessage = "No active events - Camera preview only";
          }
        });

        print("📅 Loaded ${ongoingEvents.length} ongoing event(s)");
        if (activeEvent != null) {
          print("🎯 Active event: ${activeEvent!['name']}");
        }
      } else {
        setState(() {
          ongoingEvents = [];
          activeEvent = null;
          isLoadingEvents = false;
          statusMessage = "No active events - Camera preview only";
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        ongoingEvents = [];
        activeEvent = null;
        isLoadingEvents = false;
        statusMessage = "Error loading events";
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Find the face closest to the center of the frame
  DetectedFace? _findCenterFace(List<DetectedFace> faces) {
    if (faces.isEmpty) return null;
    if (faces.length == 1) return faces[0];

    // Get camera dimensions
    if (controller == null) return null;
    final imageWidth = controller!.value.previewSize!.height;
    final imageHeight = controller!.value.previewSize!.width;

    // Center point of the image
    final centerX = imageWidth / 2;
    final centerY = imageHeight / 2;

    // Find face with center closest to image center
    DetectedFace? closestFace;
    double minDistance = double.infinity;

    for (var face in faces) {
      // Calculate center of face bounding box
      final faceCenterX = face.boundingBox.x + (face.boundingBox.width / 2);
      final faceCenterY = face.boundingBox.y + (face.boundingBox.height / 2);

      // Calculate Euclidean distance to center
      final distance = ((faceCenterX - centerX) * (faceCenterX - centerX) +
                       (faceCenterY - centerY) * (faceCenterY - centerY));

      if (distance < minDistance) {
        minDistance = distance;
        closestFace = face;
      }
    }

    return closestFace;
  }

  void _showWelcomeMessage(DetectedFace face) {
    setState(() {
      _recognizedPerson = face;
      _showWelcomeCard = true;
    });
    _animationController?.forward();

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _animationController?.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showWelcomeCard = false;
            });
          }
        });
      }
    });
  }

  Future<void> initializeCamera() async {
    try {
      print("🎥 Starting camera initialization...");
      print("🎥 Available cameras: ${cameras.length}");

      // Use first available camera (webcam on web)
      final camera = cameras.first;
      print("🎥 Using camera: ${camera.name}");

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();
      print("🎥 Camera initialized successfully!");

      if (!mounted) {
        print("⚠️ Widget not mounted, aborting");
        return;
      }

      setState(() {
        statusMessage = "Camera ready - Processing...";
      });

      // Start frame processing timer
      print("⏱️ Starting frame processing timer...");
      startFrameProcessing();
      print("✅ Frame processing started!");
    } catch (e) {
      print("❌ Camera error: $e");
      setState(() {
        statusMessage = "Camera error: $e";
      });
    }
  }

  void startFrameProcessing() {
    print("🔄 Creating periodic timer (every ${FRAME_INTERVAL_MS}ms)...");
    frameTimer = Timer.periodic(Duration(milliseconds: FRAME_INTERVAL_MS), (timer) async {
      print("⏰ Timer tick - isBusy: $isBusy, controller: ${controller != null}, initialized: ${controller?.value.isInitialized}");
      if (!isBusy && controller != null && controller!.value.isInitialized) {
        print("📸 Processing frame...");
        await processFrame();
      }
    });
    print("✅ Timer created successfully");
  }

  Future<void> processFrame() async {
    if (isBusy) return;

    print("🔒 Setting isBusy = true");
    setState(() {
      isBusy = true;
    });

    try {
      print("📷 Taking picture...");
      // Capture current frame
      final XFile imageFile = await controller!.takePicture();
      print("✅ Picture taken, reading bytes...");
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print("✅ Got ${imageBytes.length} bytes, encoding to base64...");
      final String base64Image = base64Encode(imageBytes);
      print("✅ Base64 encoded, sending to backend...");

      // Send to backend for detection and recognition
      final response = await apiService.detectAndRecognizeFaces(
        imageBase64: base64Image,
        eventId: activeEvent?['id'],  // Pass event ID if available
      );
      print("✅ Backend responded: $response");

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        if (data['faces'] != null && data['faces'] is List) {
          List<DetectedFace> faces = (data['faces'] as List)
              .map((faceJson) => DetectedFace.fromJson(faceJson))
              .toList();

          // Find the face closest to center
          final selectedFace = _findCenterFace(faces);

          setState(() {
            detectedFaces = faces;
            centerFace = selectedFace;

            if (faces.isEmpty) {
              statusMessage = activeEvent == null
                  ? "No active events - Camera preview only"
                  : "Looking for faces...";
            } else if (faces.length == 1) {
              final face = faces[0];
              if (face.name != "Unknown" && face.isLive) {
                if (activeEvent != null) {
                  statusMessage = "✅ ${_getGreeting()}, ${face.name}!";
                  // Show welcome card only when event is active
                  _showWelcomeMessage(face);
                } else {
                  statusMessage = "Recognized: ${face.name} (No attendance marked - No active event)";
                }
              } else if (face.name != "Unknown" && !face.isLive) {
                statusMessage = "⚠️ Liveness check failed - Please try again";
              } else {
                statusMessage = "Unknown person - Please register first";
              }
            } else {
              // Multiple faces detected
              if (selectedFace != null) {
                if (selectedFace.name != "Unknown" && selectedFace.isLive) {
                  if (activeEvent != null) {
                    statusMessage = "✅ ${_getGreeting()}, ${selectedFace.name}!";
                    _showWelcomeMessage(selectedFace);
                  } else {
                    statusMessage = "${faces.length} faces - Center: ${selectedFace.name} (No active event)";
                  }
                } else if (selectedFace.name != "Unknown" && !selectedFace.isLive) {
                  statusMessage = "⚠️ Center person: Liveness check failed";
                } else {
                  statusMessage = "${faces.length} faces detected - Center person: Unknown";
                }
              } else {
                statusMessage = "${faces.length} faces detected - Position yourself in center";
              }
            }
          });

          // Log recognized faces
          for (var face in faces) {
            if (face.name != "Unknown" && face.isLive) {
              print("✅ RECOGNIZED: ${face.name} (${face.employeeId}) - ${(face.confidence * 100).toStringAsFixed(1)}%");
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
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              activeEvent != null ? 'Mark Attendance' : 'Camera Preview',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            if (activeEvent != null)
              Text(
                activeEvent!['name'],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          if (ongoingEvents.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Event',
              onSelected: (eventId) {
                setState(() {
                  activeEvent = ongoingEvents.firstWhere((e) => e['id'] == eventId);
                  statusMessage = "Event: ${activeEvent!['name']}";
                });
              },
              itemBuilder: (context) => ongoingEvents.map((event) {
                return PopupMenuItem<String>(
                  value: event['id'],
                  child: Text(event['name']),
                );
              }).toList(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadOngoingEvents,
            tooltip: 'Refresh Events',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
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
              const Center(
                child: CircularProgressIndicator(),
              ),

            // Center target indicator
            if (controller != null && controller!.value.isInitialized)
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        color: Colors.white.withOpacity(0.5),
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Position face here',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Face detection overlay
            if (controller != null && controller!.value.isInitialized)
              CustomPaint(
                painter: FaceOverlayPainter(
                  detectedFaces,
                  centerFace,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: activeEvent == null
                        ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
                        : detectedFaces.any((f) => f.isLive && f.name != "Unknown")
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: activeEvent == null
                          ? Colors.black.withOpacity(0.3)
                          : detectedFaces.any((f) => f.isLive && f.name != "Unknown")
                              ? const Color(0xFF10B981).withOpacity(0.4)
                              : Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        activeEvent == null
                            ? Icons.event_busy
                            : detectedFaces.any((f) => f.isLive && f.name != "Unknown")
                                ? Icons.verified_user
                                : detectedFaces.isEmpty
                                    ? Icons.face_retouching_natural
                                    : Icons.remove_red_eye,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeEvent == null
                                ? 'No Active Event'
                                : detectedFaces.any((f) => f.isLive && f.name != "Unknown")
                                    ? 'Recognition Successful'
                                    : 'Scanning...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeEvent == null
                                ? 'Attendance marking disabled - Camera preview only'
                                : statusMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Event Info Card (Bottom)
            if (activeEvent != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeEvent!['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (activeEvent!['location'] != null)
                                  Text(
                                    activeEvent!['location'],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withOpacity(0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${activeEvent!['start_time']} - ${activeEvent!['end_time']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFF10B981),
                                  size: 8,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'ONGOING',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Welcome Card (Animated)
            if (_showWelcomeCard && _recognizedPerson != null)
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation!,
                  child: Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF3B82F6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Success Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Greeting
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Name
                        Text(
                          _recognizedPerson!.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Employee ID
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID: ${_recognizedPerson!.employeeId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Status Message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _recognizedPerson!.attendanceMarked
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _recognizedPerson!.attendanceMarked
                                    ? Icons.verified
                                    : Icons.info_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _recognizedPerson!.attendanceMarked
                                    ? 'Attendance Already Marked Today'
                                    : 'Attendance Marked Successfully',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Timestamp
                        Text(
                          'Recorded at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
  final bool attendanceMarked;

  DetectedFace({
    required this.boundingBox,
    required this.name,
    required this.employeeId,
    required this.confidence,
    required this.isLive,
    this.attendanceMarked = false,
  });

  factory DetectedFace.fromJson(Map<String, dynamic> json) {
    return DetectedFace(
      boundingBox: BoundingBox.fromJson(json['boundingBox'] ?? {}),
      name: json['name'] ?? 'Unknown',
      employeeId: json['employeeId'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      isLive: json['isLive'] ?? false,
      attendanceMarked: json['attendanceMarked'] ?? false,
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
  final DetectedFace? centerFace;
  final Size imageSize;

  FaceOverlayPainter(this.faces, this.centerFace, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (final face in faces) {
      final box = face.boundingBox;
      final isCenterFace = centerFace != null && face == centerFace;

      // Scale bounding box to screen size
      final rect = Rect.fromLTWH(
        box.x * scaleX,
        box.y * scaleY,
        box.width * scaleX,
        box.height * scaleY,
      );

      // Draw rectangle with different styles for center vs non-center faces
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCenterFace ? 6.0 : 3.0
        ..color = isCenterFace
            ? (face.isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
            : Colors.white.withOpacity(0.4);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(8)),
        paint,
      );

      // Add corner accents for center face
      if (isCenterFace) {
        final accentPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..color = face.isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

        const cornerLength = 20.0;

        // Top-left corner
        canvas.drawLine(rect.topLeft, rect.topLeft + Offset(cornerLength, 0), accentPaint);
        canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, cornerLength), accentPaint);

        // Top-right corner
        canvas.drawLine(rect.topRight, rect.topRight + Offset(-cornerLength, 0), accentPaint);
        canvas.drawLine(rect.topRight, rect.topRight + Offset(0, cornerLength), accentPaint);

        // Bottom-left corner
        canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(cornerLength, 0), accentPaint);
        canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -cornerLength), accentPaint);

        // Bottom-right corner
        canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-cornerLength, 0), accentPaint);
        canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -cornerLength), accentPaint);
      }

      // Draw name label (only for center face or if single face)
      if ((isCenterFace || faces.length == 1) && face.name != "Unknown") {
        final textSpan = TextSpan(
          text: face.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            backgroundColor: face.isLive
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
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

      // Draw "SELECTED" badge for center face when multiple faces detected
      if (isCenterFace && faces.length > 1) {
        final badgeSpan = TextSpan(
          text: '  SELECTED  ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: face.isLive
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ),
        );

        final badgePainter = TextPainter(
          text: badgeSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        badgePainter.paint(
          canvas,
          Offset(rect.left, rect.bottom + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) => true;
}
