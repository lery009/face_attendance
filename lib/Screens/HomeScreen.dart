/*
import 'package:flutter/material.dart';
import 'WebRecognitionScreen.dart'; // WEB-COMPATIBLE VERSION
import 'RegisteredFacesScreen.dart';
import 'RegistrationScreen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Header Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tag_faces, size: 30, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text(
                    "Face Recognition",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Logo
            Center(
              child: Container(
                width: screenWidth * 0.55,
                height: screenWidth * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withAlpha(80),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage("images/logo.png"),
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Buttons as Cards
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    _actionCard(
                      context,
                      icon: Icons.person_add,
                      title: "Register New Face",
                      subtitle: "Capture and store a new user face",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _actionCard(
                      context,
                      icon: Icons.search,
                      title: "Recognize Face",
                      subtitle: "Web-compatible face recognition",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WebRecognitionScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _actionCard(
                      context,
                      icon: Icons.list,
                      title: "Registered Faces",
                      subtitle: "View all stored face data",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisteredFacesScreen()),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context,
      {required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple.shade50,
                child: Icon(icon, size: 30, color: Colors.deepPurple),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.deepPurple, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
*/



import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'WebRecognitionScreen.dart';
import 'WebRegistrationScreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = kIsWeb;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tag_faces, size: 30, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text(
                    "Face Recognition",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Container(
                width: screenWidth * 0.35,
                height: screenWidth * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.face,
                  size: screenWidth * 0.2,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (isWeb)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.web, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Web Mode - Server-side processing',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    _actionCard(
                      context,
                      icon: Icons.person_add,
                      title: "Register New Face",
                      subtitle: "Capture via webcam",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WebRegistrationScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _actionCard(
                      context,
                      icon: Icons.search,
                      title: "Recognize Face",
                      subtitle: "Real-time face recognition",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WebRecognitionScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context,
      {required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple.shade50,
                child: Icon(icon, size: 30, color: Colors.deepPurple),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.deepPurple, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}