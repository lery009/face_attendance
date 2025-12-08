import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:realtime_face_recognition_2026/api/api_service.dart';

class QRCodeDisplayScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const QRCodeDisplayScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<QRCodeDisplayScreen> createState() => _QRCodeDisplayScreenState();
}

class _QRCodeDisplayScreenState extends State<QRCodeDisplayScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _qrToken;
  String? _qrData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQRCode();
  }

  Future<void> _loadQRCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.getEmployeeQrCode(widget.employeeId);
      if (result['success'] == true) {
        setState(() {
          _qrToken = result['qr_token'];
          _qrData = result['qr_data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to load QR code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading QR code: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateQRCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate QR Code'),
        content: const Text(
          'Are you sure you want to regenerate this QR code? The old QR code will no longer work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.regenerateQrCode(widget.employeeId);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code regenerated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadQRCode();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to regenerate QR code'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee QR Code'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadQRCode,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Employee Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFF1E3A8A),
                                child: Text(
                                  widget.employeeName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.employeeName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${widget.employeeId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // QR Code Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'Attendance QR Code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scan this code to mark attendance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: QrImageView(
                                  data: _qrData!,
                                  version: QrVersions.auto,
                                  size: 250,
                                  backgroundColor: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 16),
                              Text(
                                'Token: ${_qrToken!.substring(0, 8)}...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Instructions Card
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How to use',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInstructionItem('1. Show this QR code to attendance scanner'),
                              _buildInstructionItem('2. Wait for confirmation beep/message'),
                              _buildInstructionItem('3. Your attendance will be recorded'),
                              const SizedBox(height: 8),
                              Divider(color: Colors.blue[200]),
                              const SizedBox(height: 8),
                              Text(
                                '⚠️ Keep this QR code private. If compromised, regenerate it immediately.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Regenerate Button
                      OutlinedButton.icon(
                        onPressed: _regenerateQRCode,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate QR Code'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          side: BorderSide(color: Colors.orange[700]!),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }
}
