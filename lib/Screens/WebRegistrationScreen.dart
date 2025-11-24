import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../main.dart';

class WebRegistrationScreen extends StatefulWidget {
  const WebRegistrationScreen({super.key});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen> {
  CameraController? controller;
  final ApiService apiService = ApiService();

  String statusMessage = "Initializing camera...";
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      if (cameras.isEmpty) {
        setState(() {
          statusMessage = "No camera available";
        });
        return;
      }

      final camera = cameras.first;

      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() {
        statusMessage = "Camera ready - Click capture to register";
      });
    } catch (e) {
      print("❌ Camera error: $e");
      setState(() {
        statusMessage = "Camera error: $e";
      });
    }
  }

  Future<void> captureAndRegister() async {
    if (isCapturing || controller == null || !controller!.value.isInitialized) {
      return;
    }

    setState(() {
      isCapturing = true;
      statusMessage = "Capturing image...";
    });

    try {
      final XFile imageFile = await controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Show registration form
      if (!mounted) return;
      showRegistrationDialog(base64Image, imageBytes);
    } catch (e) {
      print("❌ Capture error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Capture failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isCapturing = false;
        statusMessage = "Camera ready - Click capture to register";
      });
    }
  }

  void showRegistrationDialog(String base64Image, Uint8List imageBytes) {
    final nameController = TextEditingController();
    final firstnameController = TextEditingController();
    final lastnameController = TextEditingController();
    final employeeIdController = TextEditingController();
    final departmentController = TextEditingController();
    final emailController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Register Employee",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.memory(
                      imageBytes,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(nameController, "Full Name", Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(firstnameController, "First Name", Icons.badge),
                  const SizedBox(height: 12),
                  _buildTextField(lastnameController, "Last Name", Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _buildTextField(employeeIdController, "Employee ID", Icons.numbers),
                  const SizedBox(height: 12),
                  _buildTextField(departmentController, "Department", Icons.business),
                  const SizedBox(height: 12),
                  _buildTextField(emailController, "Email", Icons.email),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (nameController.text.trim().isEmpty ||
                              firstnameController.text.trim().isEmpty ||
                              lastnameController.text.trim().isEmpty ||
                              employeeIdController.text.trim().isEmpty ||
                              departmentController.text.trim().isEmpty ||
                              emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please fill all fields")),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            print("🚀 Sending registration request...");
                            print("📋 Employee ID: ${employeeIdController.text.trim()}");
                            print("📋 Name: ${nameController.text.trim()}");
                            print("📋 Email: ${emailController.text.trim()}");

                            final response = await apiService.registerEmployeeWithImage(
                              name: nameController.text.trim(),
                              firstname: firstnameController.text.trim(),
                              lastname: lastnameController.text.trim(),
                              employeeId: employeeIdController.text.trim(),
                              department: departmentController.text.trim(),
                              email: emailController.text.trim(),
                              imageBase64: base64Image,
                            );

                            print("📥 Server response: ${response}");
                            setDialogState(() => isSubmitting = false);

                            if (response["success"] == true) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✅ Employee Registered Successfully!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              String errorMsg = response["error"] ?? "Unknown error";
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("❌ $errorMsg"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("❌ Error: ${e.toString()}"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text("Register"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register Face (Web)'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
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

          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: isCapturing ? null : captureAndRegister,
                backgroundColor: Colors.deepPurple,
                icon: isCapturing
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.camera_alt),
                label: Text(isCapturing ? "Capturing..." : "Capture & Register"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}