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


import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:realtime_face_recognition_2026/Screens/DashboardScreen.dart';
import 'package:realtime_face_recognition_2026/Screens/LoginScreen.dart';
import 'package:realtime_face_recognition_2026/services/auth_service.dart';
import 'package:realtime_face_recognition_2026/services/theme_service.dart';

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

  // Initialize services
  await AuthService().init();
  await ThemeService().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    // Listen to theme changes
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition Attendance',
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: _themeService.themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    // Check if user is authenticated
    if (authService.isAuthenticated) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}
