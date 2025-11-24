import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../model/employee_match_response.dart';
import '../model/response_model.dart';

class ApiService {
  final String baseUrl = 'http://10.22.0.231:3000/api';

  // NEW: Server-side face detection and recognition for WEB
  Future<Map<String, dynamic>> detectAndRecognizeFaces({
    required String imageBase64,
  }) async {
    final url = Uri.parse('$baseUrl/detect-recognize');

    final body = {
      "image": imageBase64, // Base64 encoded image
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // Expected response format:
        // {
        //   "faces": [
        //     {
        //       "boundingBox": {"x": 100, "y": 50, "width": 200, "height": 250},
        //       "name": "John Doe",
        //       "employeeId": "EMP001",
        //       "confidence": 0.95,
        //       "isLive": true
        //     }
        //   ]
        // }
        return {"success": true, "data": jsonData};
      } else {
        return {"success": false, "faces": []};
      }
    } catch (e) {
      print("❌ Detection error: $e");
      return {"success": false, "faces": []};
    }
  }

  // NEW: Server-side registration with face detection
  Future<Map<String, dynamic>> registerEmployeeWithImage({
    required String name,
    required String firstname,
    required String lastname,
    required String employeeId,
    required String department,
    required String email,
    required String imageBase64,
  }) async {
    final url = Uri.parse('$baseUrl/employees/register-with-image');

    final body = {
      "name": name,
      "firstname": firstname,
      "lastname": lastname,
      "employeeId": employeeId,
      "department": department,
      "email": email,
      "image": imageBase64, // Backend will extract face and generate embeddings
    };

    try {
      print("🚀 Sending registration to: $url");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      print("📡 Response Status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print("✅ Registration successful!");
        return {"success": true, "data": jsonData};
      } else {
        print("❌ Error: ${response.statusCode}");
        print("Response: ${response.body}");
        return {
          "success": false,
          "error": "Server error: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      print("❌ Exception: $e");
      return {
        "success": false,
        "error": "Connection failed: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> sendEmployeeData({    /// THIS IS FOR REGISTRATION
     String? id,
     String? createdAt,
    required String name,
    required String firstname,
    required String lastname,
    required String employeeId,
    required String department,
    required String email,
     String? profile,
    required List<double> embeddings,
  }) async {
    final url = Uri.parse('$baseUrl/employees');

    final body = {
    //  "id": id,
     // "createdAt": createdAt,
      "name": name,
      "firstname": firstname,
      "lastname": lastname,
      "employeeId": employeeId,
      "department": department,
      "email": email,
     // "profile": profile,
      "embeddings": embeddings
    };

    try {
      print("🚀 Sending registration to: $url");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      print("📡 Response Status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print("✅ Registration successful!");
        print(body);
        return {"success": true, "data": jsonData};
      } else {
        print("❌ Error: ${response.statusCode}");
        print("Response: ${response.body}");
        return {
          "success": false,
          "error": "Server error: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      print("❌ Exception: $e");
      return {
        "success": false,
        "error": "Connection failed: ${e.toString()}",
      };
    }
  }



  Future<EmployeeMatchResponse?> matchEmployee({     /// THIS IS FOR MATCHING , FOR VERIFY EMBEDDINGS IF EXIST
    required List<double> embedding,
  }) async {
    final url = Uri.parse('$baseUrl/employees/match');

    final body = {"embedding": embedding};

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return EmployeeMatchResponse.fromJson(jsonData);
      } else {
        // Silent fail for matching
        return null;
      }
    } catch (e) {
      // Silent fail for matching
      return null;
    }
  }









}
