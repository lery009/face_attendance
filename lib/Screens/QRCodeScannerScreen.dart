import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:realtime_face_recognition_2026/api/api_service.dart';

class QRCodeScannerScreen extends StatefulWidget {
  final String? eventId;

  const QRCodeScannerScreen({super.key, this.eventId});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  final ApiService _apiService = ApiService();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get current GPS location (non-blocking, returns null if fails)
  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('📍 Location services are disabled');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('📍 Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('📍 Location permission permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      print('📍 GPS Location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('📍 Error getting location: $e');
      return null;
    }
  }

  Future<void> _handleQRCode(String qrData) async {
    // Prevent duplicate scans within 3 seconds
    if (_lastScannedCode == qrData &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!) < const Duration(seconds: 3)) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = qrData;
      _lastScanTime = DateTime.now();
    });

    try {
      // Parse QR code data (format: "ATTENDANCE:{token}")
      if (!qrData.startsWith('ATTENDANCE:')) {
        _showErrorDialog('Invalid QR Code', 'This is not a valid attendance QR code.');
        setState(() => _isProcessing = false);
        return;
      }

      final qrToken = qrData.substring('ATTENDANCE:'.length);

      // Get GPS location (non-blocking - won't fail check-in if GPS unavailable)
      final position = await _getCurrentLocation();

      // Call check-in API with GPS if available
      final result = await _apiService.qrCheckIn(
        qrToken: qrToken,
        eventId: widget.eventId,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (result['success'] == true) {
        _showSuccessDialog(result['message'] ?? 'Attendance recorded successfully');
      } else {
        _showErrorDialog('Check-in Failed', result['message'] ?? 'Failed to record attendance');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to process QR code: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset to allow next scan
              setState(() {
                _lastScannedCode = null;
                _lastScanTime = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset to allow retry
              setState(() {
                _lastScannedCode = null;
                _lastScanTime = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventId != null ? 'Event QR Attendance' : 'QR Code Scanner',
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_controller.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Overlay with scanning area
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Stack(
              children: [
                // Top instructions
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                size: 48,
                                color: const Color(0xFF1E3A8A),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.eventId != null
                                    ? 'Scan employee QR code for event attendance'
                                    : 'Scan employee QR code to mark attendance',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scanning frame
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner decorations
                        _buildCorner(Alignment.topLeft),
                        _buildCorner(Alignment.topRight),
                        _buildCorner(Alignment.bottomLeft),
                        _buildCorner(Alignment.bottomRight),
                      ],
                    ),
                  ),
                ),

                // Bottom status
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      if (_isProcessing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Processing...',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 12),
                              Text(
                                'Point camera at QR code',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
