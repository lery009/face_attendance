import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../api/api_service.dart';

class OnlineRegistrationScreen extends StatefulWidget {
  final String? invitationToken; // Optional invitation token from URL

  const OnlineRegistrationScreen({super.key, this.invitationToken});

  @override
  State<OnlineRegistrationScreen> createState() => _OnlineRegistrationScreenState();
}

class _OnlineRegistrationScreenState extends State<OnlineRegistrationScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? capturedImageBase64;
  bool isRegistering = false;
  bool isCapturing = false;
  bool isValidatingToken = false;
  bool tokenIsValid = false;
  String? tokenValidationMessage;
  String? invitedEmail;
  String? urlToken; // Token parsed from URL
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _parseUrlToken();
    _validateInvitationToken();
  }

  void _parseUrlToken() {
    // Parse token from URL if widget.invitationToken is not provided
    // This handles direct URL access like: http://localhost/#/register?token=xyz
    if (widget.invitationToken == null) {
      try {
        final uri = Uri.parse(html.window.location.href);
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          urlToken = token;
          print('📧 Invitation token found in URL: ${token.substring(0, 8)}...');
        }
      } catch (e) {
        print('Error parsing URL token: $e');
      }
    }
  }

  @override
  void dispose() {
    firstnameController.dispose();
    lastnameController.dispose();
    employeeIdController.dispose();
    departmentController.dispose();
    emailController.dispose();
    phoneController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // Get the active token (from widget or URL)
  String? get activeToken => widget.invitationToken ?? urlToken;

  Future<void> _validateInvitationToken() async {
    // Check if token was provided (from widget or URL)
    final token = activeToken;
    if (token == null || token.isEmpty) {
      // No token - regular open registration
      return;
    }

    setState(() => isValidatingToken = true);

    try {
      final response = await apiService.validateInvitation(token);

      if (mounted) {
        setState(() {
          isValidatingToken = false;
          tokenIsValid = response['valid'] == true;
          tokenValidationMessage = response['message'];

          if (tokenIsValid) {
            // Pre-fill email from invitation
            invitedEmail = response['email'];
            emailController.text = invitedEmail ?? '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isValidatingToken = false;
          tokenIsValid = false;
          tokenValidationMessage = 'Error validating invitation';
        });
      }
    }
  }

  Future<void> capturePhoto() async {
    setState(() => isCapturing = true);

    html.MediaStream? stream;
    html.DivElement? cameraDiv;

    try {
      // Access webcam using getUserMedia API
      stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false,
      });

      // Create video element to display camera feed
      final html.VideoElement video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..style.width = '100%'
        ..style.maxWidth = '500px'
        ..style.borderRadius = '8px';

      // Create canvas for capturing the photo
      final html.CanvasElement canvas = html.CanvasElement();

      // Create a div to hold video and buttons
      cameraDiv = html.DivElement()
        ..id = 'camera-overlay-${DateTime.now().millisecondsSinceEpoch}'
        ..style.position = 'fixed'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'rgba(0, 0, 0, 0.9)'
        ..style.display = 'flex'
        ..style.flexDirection = 'column'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.zIndex = '9999'
        ..style.padding = '20px';

      final html.DivElement buttonContainer = html.DivElement()
        ..style.marginTop = '20px'
        ..style.display = 'flex'
        ..style.gap = '10px';

      final html.ButtonElement captureButton = html.ButtonElement()
        ..text = 'Capture Photo'
        ..style.padding = '12px 24px'
        ..style.backgroundColor = '#1E3A8A'
        ..style.color = 'white'
        ..style.border = 'none'
        ..style.borderRadius = '6px'
        ..style.cursor = 'pointer'
        ..style.fontSize = '16px';

      final html.ButtonElement cancelButton = html.ButtonElement()
        ..text = 'Cancel'
        ..style.padding = '12px 24px'
        ..style.backgroundColor = '#6B7280'
        ..style.color = 'white'
        ..style.border = 'none'
        ..style.borderRadius = '6px'
        ..style.cursor = 'pointer'
        ..style.fontSize = '16px';

      buttonContainer.append(captureButton);
      buttonContainer.append(cancelButton);
      cameraDiv!.append(video);
      cameraDiv!.append(buttonContainer);
      html.document.body!.append(cameraDiv!);

      // Wait for button click using Future.any
      bool captured = await Future.any([
        captureButton.onClick.first.then((_) => true),
        cancelButton.onClick.first.then((_) => false),
      ]);

      // If captured, process the image
      if (captured) {
        try {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          final html.CanvasRenderingContext2D context = canvas.context2D;
          context.drawImage(video, 0, 0);

          // Get base64 image
          final String dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
          final String base64Image = dataUrl.split(',')[1];

          // Update state with captured image
          setState(() {
            capturedImageBase64 = base64Image;
            isCapturing = false;
          });
        } catch (e) {
          print('Error capturing image: $e');
          setState(() => isCapturing = false);
        }
      } else {
        // User cancelled
        setState(() => isCapturing = false);
      }

      // Clean up: Stop camera and remove overlay
      try {
        final tracks = stream!.getTracks();
        for (var track in tracks) {
          track.stop();
        }
      } catch (e) {
        print('Error stopping camera: $e');
      }

      try {
        cameraDiv!.remove();
      } catch (e) {
        print('Error removing overlay: $e');
      }

    } catch (e) {
      print('Error capturing photo: $e');
      setState(() => isCapturing = false);

      // Clean up if error occurs
      if (stream != null) {
        try {
          final tracks = stream!.getTracks();
          for (var track in tracks) {
            track.stop();
          }
        } catch (_) {}
      }
      if (cameraDiv != null) {
        try {
          cameraDiv!.remove();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (capturedImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your photo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isRegistering = true);

    try {
      final response = await apiService.registerOnline(
        firstname: firstnameController.text.trim(),
        lastname: lastnameController.text.trim(),
        employeeId: employeeIdController.text.trim(),
        department: departmentController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        imageBase64: capturedImageBase64!,
      );

      setState(() => isRegistering = false);

      if (response['success'] == true) {
        // Mark invitation as used if registration came from invitation
        if (activeToken != null && tokenIsValid) {
          try {
            await apiService.markInvitationUsed(
              activeToken!,
              response['data']['employeeId'] ?? '',
            );
          } catch (e) {
            print('Warning: Failed to mark invitation as used: $e');
          }
        }

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 32),
                SizedBox(width: 12),
                Text('Registration Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(response['message'] ?? 'You are now registered!'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${response['data']['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text('Employee ID: ${response['data']['employeeId']}'),
                      const SizedBox(height: 4),
                      Text('Email: ${response['data']['email']}'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isRegistering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    firstnameController.clear();
    lastnameController.clear();
    employeeIdController.clear();
    departmentController.clear();
    emailController.clear();
    phoneController.clear();
    setState(() {
      capturedImageBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Employee Registration'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 48,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Register for Face Recognition',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fill in your details and capture your photo',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Invitation Status Banner
                      if (activeToken != null) ...[
                        if (isValidatingToken)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Validating invitation...'),
                              ],
                            ),
                          )
                        else if (tokenIsValid)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Invitation accepted for $invitedEmail',
                                    style: TextStyle(color: Colors.green[900]),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tokenValidationMessage ?? 'Invalid invitation',
                                    style: TextStyle(color: Colors.red[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // First Name
                      TextFormField(
                        controller: firstnameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: lastnameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Employee ID
                      TextFormField(
                        controller: employeeIdController,
                        decoration: InputDecoration(
                          labelText: 'Employee ID *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Employee ID is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Department
                      TextFormField(
                        controller: departmentController,
                        decoration: InputDecoration(
                          labelText: 'Department *',
                          prefixIcon: const Icon(Icons.business_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Department is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: tokenIsValid, // Readonly if from invitation
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          suffixIcon: tokenIsValid
                              ? Icon(Icons.lock, size: 18, color: Colors.grey[600])
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: tokenIsValid ? Colors.grey[100] : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone (Optional)
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Photo Capture
                      Text(
                        'Your Photo *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (capturedImageBase64 != null)
                              Column(
                                children: [
                                  Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: MemoryImage(
                                          base64Decode(capturedImageBase64!),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: capturePhoto,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retake Photo'),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: isCapturing ? null : capturePhoto,
                                    icon: const Icon(Icons.camera),
                                    label: Text(isCapturing ? 'Opening camera...' : 'Capture Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please ensure good lighting and face the camera directly',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isRegistering ? null : submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isRegistering
                              ? const Row(
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
                                    Text('Registering...'),
                                  ],
                                )
                              : const Text(
                                  'Complete Registration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info text
                      Center(
                        child: Text(
                          '* Required fields',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
