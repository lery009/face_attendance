import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../ML/Recognition.dart';
import '../ML/Recognizer.dart';
import '../ML/LivenessDetector.dart';
import '../Util.dart';
import '../main.dart';
import '../api/api_service.dart';
import 'package:uuid/uuid.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RegistrationScreen> {
  dynamic controller;
  bool isBusy = false;
  late Size size;
  late CameraDescription description = cameras[1];
  CameraLensDirection camDirec = CameraLensDirection.front;
  late List<Recognition> recognitions = [];

  //TODO declare face detector
  late FaceDetector faceDetector;

  //TODO declare face recognizer
  late Recognizer recognizer;

  // Frame skipping for better performance
  int frameSkipCounter = 0;
  final int frameSkip = 4; // Process every 5th frame for maximum speed

  // Liveness detection
  final LivenessDetector livenessDetector = LivenessDetector();
  bool canRegister = false;

  @override
  void initState() {
    super.initState();

    //TODO initialize face detector
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false, // Not needed - using head pose tracking
        enableTracking: true, // Enable head pose tracking for liveness
        minFaceSize: 0.25, // Only detect larger faces to reduce lag
      ),
    );

    //TODO initialize face recognizer
    recognizer = Recognizer();

    //TODO initialize camera footage
    initializeCamera();
  }

  //TODO code to initialize the camera feed
  initializeCamera() async {
    controller = CameraController(description, ResolutionPreset.low,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888,
        enableAudio: false); // for iOS);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        controller;
      });
      controller.startImageStream((image) {
        // Skip frames for better performance
        frameSkipCounter++;
        if (frameSkipCounter % (frameSkip + 1) != 0) {
          return;
        }

        if (!isBusy) {
          isBusy = true;
          frame = image;
          doFaceDetectionOnFrame();
        }
      });
    });
  }

  //TODO close all resources
  @override
  void dispose() {
    controller?.dispose();
    faceDetector.close();
    livenessDetector.reset(); // Reset liveness on exit
    super.dispose();
  }

  //TODO face detection on a frame
  dynamic _scanResults;
  CameraImage? frame;
  doFaceDetectionOnFrame() async {
    //TODO convert frame into InputImage format
    InputImage? inputImage = getInputImage();
    if (inputImage == null) {
      setState(() {
        isBusy = false;
      });
      return;
    }

    //TODO pass InputImage to face detection model and detect faces
    List<Face> faces = await faceDetector.processImage(inputImage);

    //TODO perform face recognition on detected faces
    await performFaceRecognition(faces);

    setState(() {
      isBusy = false;
    });
  }

  img.Image? image;
  bool register = false;
  //TODO perform Face Recognition
  performFaceRecognition(List<Face> faces) async {
    recognitions.clear();

    // Early exit if no faces detected
    if (faces.isEmpty) {
      livenessDetector.reset(); // Reset liveness state
      setState(() {
        isBusy = false;
        _scanResults = faces;
        canRegister = false;
      });
      return;
    }

    // Check liveness with the first face
    Face primaryFace = faces.first;
    LivenessResult livenessResult = livenessDetector.checkLiveness(primaryFace);

    setState(() {
      canRegister = livenessResult.isLive;
    });

    //TODO convert CameraImage to Image and rotate it so that our frame will be in a portrait
    image = Platform.isIOS
        ? Util.convertBGRA8888ToImage(frame!)
        : Util.convertNV21(frame!);
    image = img.copyRotate(image!, angle: camDirec == CameraLensDirection.front?270:90);

    if(register && canRegister){
      // Only register if liveness is confirmed
      Rect faceRect = primaryFace.boundingBox;

      // Validate face boundaries
      if (faceRect.left >= 0 && faceRect.top >= 0 &&
          faceRect.right <= image!.width && faceRect.bottom <= image!.height) {
        //TODO crop face
        img.Image croppedFace = img.copyCrop(image!,
          x: faceRect.left.toInt(),
          y: faceRect.top.toInt(),
          width: faceRect.width.toInt(),
          height: faceRect.height.toInt());

        //TODO pass cropped face to face recognition model
        Recognition recognition = await recognizer.recognize(croppedFace, faceRect);
        recognitions.add(recognition);

        //TODO show face registration dialogue
        showFaceRegistrationDialogue(croppedFace, recognition);
      }

      register = false;
    } else if (register && !canRegister) {
      // Show warning if trying to register without liveness
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Liveness check failed! Please blink and move slightly."),
          backgroundColor: Colors.orange,
        ),
      );
      register = false;
    }

    setState(() {
      isBusy  = false;
      _scanResults = faces;
    });

  }

  //TODO Face Registration Dialogue
  final TextEditingController nameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final ApiService apiService = ApiService();
  bool isSubmitting = false;

  showFaceRegistrationDialogue(img.Image croppedFace, Recognition recognition){
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 60,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              child: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Register Employee",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.memory(
                          Uint8List.fromList(img.encodeBmp(croppedFace)),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
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

                            setState(() => isSubmitting = true);

                            try {
                              // Convert image to base64
                              String profileBase64 = base64Encode(img.encodeBmp(croppedFace));

                              print("📝 Starting registration...");
                              print("Employee ID: ${employeeIdController.text.trim()}");
                              print("Name: ${nameController.text.trim()}");

                              // Send to API
                              final response = await apiService.sendEmployeeData(
                                id: const Uuid().v4(),
                                createdAt: DateTime.now().toIso8601String(),
                                name: nameController.text.trim(),
                                firstname: firstnameController.text.trim(),
                                lastname: lastnameController.text.trim(),
                                employeeId: employeeIdController.text.trim(),
                                department: departmentController.text.trim(),
                                email: emailController.text.trim(),
                                profile: profileBase64,
                                embeddings: recognition.embeddings,
                              );

                              setState(() => isSubmitting = false);

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
                              setState(() => isSubmitting = false);
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
                            backgroundColor: Colors.deepPurple.shade300,
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
                ),
              ),
            ),
          ),
        ),
      )
    );
  }

  // Helper method to build text fields
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withAlpha(80),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // //TODO convert CameraImage to InputImage
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  InputImage? getInputImage() {
    final camera =
    camDirec == CameraLensDirection.front ? cameras[1] : cameras[0];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
      _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(frame!.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (frame!.planes.length != 1) return null;
    final plane = frame!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(frame!.width.toDouble(), frame!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // TODO Show rectangles around detected faces
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(child: Text('Camera is not initialized'));
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = FaceDetectorPainter(imageSize, _scanResults, camDirec);
    return CustomPaint(
      painter: painter,
    );
  }

  //TODO toggle camera direction
  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      camDirec = CameraLensDirection.front;
      description = cameras[1];
    } else {
      camDirec = CameraLensDirection.back;
      description = cameras[0];
    }
    await controller.stopImageStream();
    setState(() {
      controller;
    });
    initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      //TODO View for displaying the live camera footage
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child:
                (controller.value.isInitialized)
                    ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    )
                    : Container(),
          ),
        ),
      );

      //TODO View for displaying rectangles around detected aces
      stackChildren.add(
        Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: buildResult()),
      );
    }

    //TODO View for displaying the bar to switch camera direction or for registering faces
    stackChildren.add(
      Positioned(
        bottom: 40,
        left: 20,
        right: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withAlpha(80),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      icon: Icon(Icons.cached, color: Colors.white),
                      iconSize: 40,
                      color: Colors.black,
                      onPressed: () {
                        _toggleCameraDirection();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.face_retouching_natural,
                            color: canRegister ? Colors.greenAccent : Colors.grey,
                          ),
                          iconSize: 40,
                          color: Colors.black,
                          onPressed: () {
                            setState(() {
                              register = true;
                            });
                          },
                        ),
                        if (canRegister)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          margin: const EdgeInsets.only(top: 0),
          color: Colors.black,
          child: Stack(children: stackChildren),
        ),
      ),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  final Size absoluteImageSize;
  final List<Face> faces;
  final CameraLensDirection camDirection;

  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.camDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blue.shade300;

    final Paint labelBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.shade300.withAlpha(150);

    for (final face in faces) {
      final double left = camDirection == CameraLensDirection.front
          ? (absoluteImageSize.width - face.boundingBox.right) * scaleX
          : face.boundingBox.left * scaleX;
      final double top = face.boundingBox.top * scaleY;
      final double right = camDirection == CameraLensDirection.front
          ? (absoluteImageSize.width - face.boundingBox.left) * scaleX
          : face.boundingBox.right * scaleX;
      final double bottom = face.boundingBox.bottom * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(rRect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) => true;
}
