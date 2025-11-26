/*

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:realtime_face_recognition_2026/ML/Recognition.dart';
import 'package:realtime_face_recognition_2026/Screens/HomeScreen.dart';


late List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(
      ),
    );
  }
}
*/


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:realtime_face_recognition_2026/Screens/DashboardScreen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cameras - works on both web (webcam) and mobile
  try {
    cameras = await availableCameras();
    print('✅ Cameras initialized: ${cameras.length} camera(s) found');
  } catch (e) {
    print('⚠️ Camera initialization error: $e');
    cameras = [];
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1E3A8A),
      ),
      home: DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
