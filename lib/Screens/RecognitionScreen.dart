import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:realtime_face_recognition_2026/Util.dart';

import '../ML/Recognition.dart';
import '../ML/Recognizer.dart';
import '../ML/LivenessDetector.dart';

import '../main.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({super.key});

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
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

  // Liveness detection - PASSIVE WALK-THROUGH DETECTION
  final LivenessDetector livenessDetector = LivenessDetector();
  String livenessStatus = "No face detected";
  bool isLive = false;

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
  List<Recognition>? _scanResults;
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
  //TODO perform Face Recognition
  performFaceRecognition(List<Face> faces) async {
    recognitions.clear();

    // Reset liveness detector if no faces (person walked away)
    if (faces.isEmpty) {
      livenessDetector.reset();
      setState(() {
        livenessStatus = "No face detected";
        isLive = false;
        isBusy = false;
        _scanResults = [];
      });
      return;
    }

    // Run passive liveness detection automatically
    Face primaryFace = faces.first;
    LivenessResult livenessResult = livenessDetector.checkLiveness(primaryFace);

    setState(() {
      livenessStatus = livenessResult.status;
      isLive = livenessResult.isLive;
    });

    // Block recognition if not verified yet
    if (!livenessResult.isLive) {
      setState(() {
        isBusy = false;
        _scanResults = []; // Clear any previous recognitions
      });
      return;
    }

    // Limit to max 3 faces to reduce lag
    final int maxFaces = 3;

    // Sort faces by size (largest first) and take only the biggest ones
    List<Face> sortedFaces = List.from(faces);
    sortedFaces.sort((a, b) {
      double areaA = a.boundingBox.width * a.boundingBox.height;
      double areaB = b.boundingBox.width * b.boundingBox.height;
      return areaB.compareTo(areaA);
    });

    // Only process the largest faces
    List<Face> facesToProcess = sortedFaces.take(maxFaces).toList();

    //TODO convert CameraImage to Image and rotate it so that our frame will be in a portrait
    image = Platform.isIOS
        ? Util.convertBGRA8888ToImage(frame!)
        : Util.convertNV21(frame!);
    image = img.copyRotate(image!, angle: camDirec == CameraLensDirection.front?270:90);

    for (Face face in facesToProcess) {
      Rect faceRect = face.boundingBox;

      // Validate face boundaries
      if (faceRect.left < 0 || faceRect.top < 0 ||
          faceRect.right > image!.width || faceRect.bottom > image!.height) {
        continue;
      }

      //TODO crop face
      img.Image croppedFace = img.copyCrop(image!,
        x: faceRect.left.toInt(),
        y: faceRect.top.toInt(),
        width: faceRect.width.toInt(),
        height: faceRect.height.toInt());

      //TODO pass cropped face to face recognition model
      Recognition recognition = await recognizer.recognize(croppedFace, faceRect);
      recognitions.add(recognition);
    }

    setState(() {
      isBusy  = false;
      _scanResults = recognitions;
    });

  }

  //TODO Face Registration Dialogue
  // TextEditingController textEditingController = TextEditingController();
  // showFaceRegistrationDialogue(img.Image croppedFace, Recognition recognition){
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text("Face Registration",textAlign: TextAlign.center),alignment: Alignment.center,
  //       content: SizedBox(
  //         height: 340,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           children: [
  //             const SizedBox(height: 20,),
  //             Image.memory(Uint8List.fromList(img.encodeBmp(croppedFace!)),width: 200,height: 200,),
  //             SizedBox(
  //               width: 200,
  //               child: TextField(
  //                   controller: textEditingController,
  //                   decoration: const InputDecoration( fillColor: Colors.white, filled: true,hintText: "Enter Name")
  //               ),
  //             ),
  //             const SizedBox(height: 10,),
  //             ElevatedButton(
  //                 onPressed: () {
  //                   recognizer.registerFaceInDB(textEditingController.text, recognition.embeddings,Uint8List.fromList(img.encodeBmp(croppedFace)));
  //                   textEditingController.text = "";
  //                   Navigator.pop(context);
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //                     content: Text("Face Registered"),
  //                   ));
  //                 },style: ElevatedButton.styleFrom(backgroundColor:Colors.blue,minimumSize: const Size(200,40)),
  //                 child: const Text("Register"))
  //           ],
  //         ),
  //       ),contentPadding: EdgeInsets.zero,
  //     ),
  //   );
  // }


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
        _scanResults!.isEmpty ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(child: Text(''));
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = FaceDetectorPainter(imageSize, _scanResults!, camDirec);
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

    // Passive liveness status banner
    stackChildren.add(
      Positioned(
        top: 60,
        left: 20,
        right: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.green.withAlpha(200)
                    : livenessStatus.contains("Analyzing")
                        ? Colors.blue.withAlpha(200)
                        : Colors.orange.withAlpha(180),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLive
                      ? Colors.greenAccent
                      : livenessStatus.contains("Analyzing")
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isLive
                        ? Icons.check_circle
                        : livenessStatus.contains("Analyzing")
                            ? Icons.radar
                            : Icons.face_retouching_natural,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    livenessStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera toggle button
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
  final List<Recognition> faces;
  final CameraLensDirection camDirection;

  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.camDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    for (final face in faces) {
      // Use different colors for known vs unknown faces
      final bool isUnknown = face.name == "Unknown";
      final Color frameColor = isUnknown ? Colors.yellow : Colors.green.shade300;

      final Paint boxPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..color = frameColor;

      final Paint labelBgPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..color = frameColor.withAlpha(180);

      final double left =
          camDirection == CameraLensDirection.front
              ? (absoluteImageSize.width - face.location.right) * scaleX
              : face.location.left * scaleX;
      final double top = face.location.top * scaleY;
      final double right =
          camDirection == CameraLensDirection.front
              ? (absoluteImageSize.width - face.location.left) * scaleX
              : face.location.right * scaleX;
      final double bottom = face.location.bottom * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(rRect, boxPaint);

      // Draw name label
      final String label =
          face.name.isNotEmpty && !isUnknown
              ? '${face.name} (${face.distance.toStringAsFixed(2)})'
              : 'Unknown';

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isUnknown ? Colors.black : Colors.white,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.6);

      final double labelPadding = 6;
      final double labelX = left;
      final double labelY = top - textPainter.height - 8;

      final backgroundRect = Rect.fromLTWH(
        labelX,
        labelY < 0 ? top + 4 : labelY,
        textPainter.width + labelPadding * 2,
        textPainter.height + labelPadding,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(8)),
        labelBgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(
          backgroundRect.left + labelPadding,
          backgroundRect.top + labelPadding / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) => true;
}
