import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import '../api/api_service.dart';
import '../services/auth_service.dart';

class CameraViewerScreen extends StatefulWidget {
  final String cameraId;
  final String cameraName;
  final bool withRecognition;

  const CameraViewerScreen({
    Key? key,
    required this.cameraId,
    required this.cameraName,
    this.withRecognition = true,
  }) : super(key: key);

  @override
  State<CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<CameraViewerScreen> {
  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final String viewType = 'camera-stream-view';
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    // Register the platform view factory for camera stream
    // Include JWT token as query parameter for authentication
    final token = authService.token ?? '';
    final streamUrl = widget.withRecognition
        ? '${apiService.baseUrl}/cameras/${widget.cameraId}/stream/recognition?token=$token'
        : '${apiService.baseUrl}/cameras/${widget.cameraId}/stream?token=$token';

    // Register view factory with unique ID
    final uniqueViewType = '$viewType-${widget.cameraId}';

    // Ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      uniqueViewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = streamUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000000';

        return img;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueViewType = '$viewType-${widget.cameraId}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isFullScreen
          ? null
          : AppBar(
              title: Text(widget.cameraName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () {
                    setState(() {
                      isFullScreen = true;
                    });
                  },
                  tooltip: 'Full Screen',
                ),
                IconButton(
                  icon: Icon(
                    widget.withRecognition
                        ? Icons.face
                        : Icons.videocam,
                  ),
                  onPressed: () {
                    // Toggle recognition mode
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraViewerScreen(
                          cameraId: widget.cameraId,
                          cameraName: widget.cameraName,
                          withRecognition: !widget.withRecognition,
                        ),
                      ),
                    );
                  },
                  tooltip: widget.withRecognition
                      ? 'Disable Face Recognition'
                      : 'Enable Face Recognition',
                ),
              ],
            ),
      body: Stack(
        children: [
          // Camera stream
          Center(
            child: HtmlElementView(
              viewType: uniqueViewType,
            ),
          ),

          // Full screen controls
          if (isFullScreen)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () {
                  setState(() {
                    isFullScreen = false;
                  });
                },
                tooltip: 'Exit Full Screen',
              ),
            ),

          // Info overlay
          if (!isFullScreen)
            Positioned(
              bottom: 16,
              left: 16,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (widget.withRecognition)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Face Recognition: ON',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Stop camera stream when viewer is closed
    apiService.stopCameraStream(widget.cameraId);
    super.dispose();
  }
}
