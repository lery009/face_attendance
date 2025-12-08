import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import '../api/api_service.dart';
import '../services/auth_service.dart';
import 'CameraViewerScreen.dart';

class LiveMonitoringScreen extends StatefulWidget {
  final String? eventId;

  const LiveMonitoringScreen({Key? key, this.eventId}) : super(key: key);

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  List<Map<String, dynamic>> cameras = [];
  bool isLoading = true;
  String eventName = "";

  @override
  void initState() {
    super.initState();
    loadCameras();
  }

  Future<void> loadCameras() async {
    setState(() => isLoading = true);

    try {
      if (widget.eventId != null) {
        // Load cameras for specific event
        final response = await apiService.getEventCameraStreams(widget.eventId!);

        if (response['success'] == true) {
          setState(() {
            eventName = response['event_name'] ?? '';
            cameras = (response['cameras'] as List<dynamic>)
                .map((c) => c as Map<String, dynamic>)
                .toList();
          });
        }
      } else {
        // Load all cameras
        final response = await apiService.getCameras();

        if (response['success'] == true) {
          setState(() {
            cameras = (response['cameras'] as List<dynamic>)
                .map((c) => c as Map<String, dynamic>)
                .toList();
          });
        }
      }
    } catch (e) {
      print("Error loading cameras: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _registerCameraView(String cameraId) {
    // Include JWT token as query parameter for authentication
    final token = authService.token ?? '';
    final streamUrl = '${apiService.baseUrl}/cameras/$cameraId/stream/recognition?token=$token';
    final viewType = 'multi-camera-$cameraId';

    // Ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = streamUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.backgroundColor = '#000000';

        return img;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId != null
            ? 'Live Monitoring - $eventName'
            : 'Live Camera Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadCameras,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cameras.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No cameras available',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      if (widget.eventId != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Link cameras to this event to start monitoring',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                )
              : _buildCameraGrid(),
    );
  }

  Widget _buildCameraGrid() {
    // Determine grid layout based on number of cameras
    int crossAxisCount = 2;
    if (cameras.length == 1) {
      crossAxisCount = 1;
    } else if (cameras.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: cameras.length,
      itemBuilder: (context, index) {
        final camera = cameras[index];
        return _buildCameraCard(camera);
      },
    );
  }

  Widget _buildCameraCard(Map<String, dynamic> camera) {
    final cameraId = camera['id'] as String;
    final cameraName = camera['name'] as String;
    final location = camera['location'] as String? ?? '';
    final isPrimary = camera['is_primary'] as bool? ?? false;

    // Register view factory for this camera
    _registerCameraView(cameraId);
    final viewType = 'multi-camera-$cameraId';

    return InkWell(
      onTap: () {
        // Open full screen camera view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraViewerScreen(
              cameraId: cameraId,
              cameraName: cameraName,
              withRecognition: true,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? Colors.blue : Colors.grey.shade300,
            width: isPrimary ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Camera stream
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HtmlElementView(
                viewType: viewType,
              ),
            ),

            // Camera info overlay
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cameraName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PRIMARY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Live indicator
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Full screen button
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraViewerScreen(
                          cameraId: cameraId,
                          cameraName: cameraName,
                          withRecognition: true,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Full Screen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Stop all camera streams when leaving the screen
    for (var camera in cameras) {
      apiService.stopCameraStream(camera['id'] as String);
    }
    super.dispose();
  }
}
