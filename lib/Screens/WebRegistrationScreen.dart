import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api/api_service.dart';
import '../main.dart';

// WEB-COMPATIBLE Registration Screen
// Works on: Web Browser, Mobile
// Face detection and embedding extraction happens on SERVER-SIDE

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
        statusMessage = "Camera ready - Position your face";
      });
    } catch (e) {
      print("❌ Camera error: $e");
      setState(() {
        statusMessage = "Camera error: $e";
      });
    }
  }

  Future<void> captureAndRegister() async {
    if (isCapturing) return;

    setState(() {
      isCapturing = true;
      statusMessage = "Capturing...";
    });

    try {
      // Capture current frame
      final XFile imageFile = await controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Show registration dialog with captured image
      if (!mounted) return;

      showRegistrationDialog(imageBytes, base64Image);
    } catch (e) {
      print("❌ Capture error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isCapturing = false;
        statusMessage = "Camera ready - Position your face";
      });
    }
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void showRegistrationDialog(Uint8List imageBytes, String base64Image) {
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 60,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Register Employee",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.memory(
                      imageBytes,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 15),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  // Clear controllers
                                  nameController.clear();
                                  firstnameController.clear();
                                  lastnameController.clear();
                                  employeeIdController.clear();
                                  departmentController.clear();
                                  emailController.clear();
                                },
                          child: const Text("Cancel"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (nameController.text.trim().isEmpty ||
                                      firstnameController.text.trim().isEmpty ||
                                      lastnameController.text.trim().isEmpty ||
                                      employeeIdController.text.trim().isEmpty ||
                                      departmentController.text.trim().isEmpty ||
                                      emailController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Please fill all fields"),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);

                                  try {
                                    print("📝 Starting registration...");
                                    print("Employee ID: ${employeeIdController.text.trim()}");
                                    print("Name: ${nameController.text.trim()}");

                                    // Send to API - backend will detect face and extract embeddings
                                    final response = await apiService.registerEmployeeWithImage(
                                      id: const Uuid().v4(),
                                      createdAt: DateTime.now().toIso8601String(),
                                      name: nameController.text.trim(),
                                      firstname: firstnameController.text.trim(),
                                      lastname: lastnameController.text.trim(),
                                      employeeId: employeeIdController.text.trim(),
                                      department: departmentController.text.trim(),
                                      email: emailController.text.trim(),
                                      imageBase64: base64Image,
                                    );

                                    setDialogState(() => isSubmitting = false);

                                    print("🔍 Response received: $response");
                                    print("🔍 Success value: ${response["success"]}");
                                    print("🔍 Success type: ${response["success"].runtimeType}");

                                    if (response["success"] == true) {
                                      // Clear all controllers
                                      nameController.clear();
                                      firstnameController.clear();
                                      lastnameController.clear();
                                      employeeIdController.clear();
                                      departmentController.clear();
                                      emailController.clear();

                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("✅ Employee Registered Successfully!"),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      // Show detailed error
                                      String errorMsg = response["error"] ?? "Unknown error";
                                      print("Error details: ${response["details"]}");

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("❌ $errorMsg"),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    print("❌ Registration exception: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("❌ Error: ${e.toString()}"),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(isSubmitting ? "Registering..." : "Register"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    nameController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    employeeIdController.dispose();
    departmentController.dispose();
    emailController.dispose();
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

            // Status banner
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.face,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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

            // Capture button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  onPressed: isCapturing ? null : captureAndRegister,
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  icon: isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera),
                  label: Text(isCapturing ? "Capturing..." : "Capture & Register"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
