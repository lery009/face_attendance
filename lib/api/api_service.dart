import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../model/employee_match_response.dart';
import '../model/response_model.dart';

class ApiService {
  final String baseUrl = 'http://localhost:3000/api';  // Changed to localhost for local backend

  // NEW: Server-side face detection and recognition for WEB
  Future<Map<String, dynamic>> detectAndRecognizeFaces({
    required String imageBase64,
    String? eventId,
  }) async {
    var url = Uri.parse('$baseUrl/detect-recognize');

    // Add event_id as query parameter if provided
    if (eventId != null) {
      url = url.replace(queryParameters: {'event_id': eventId});
    }

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
    required String id,
    required String createdAt,
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
      "id": id,
      "createdAt": createdAt,
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

  // NEW: Get attendance logs with optional filters
  Future<Map<String, dynamic>> getAttendanceLogs({String? date, String? employeeId}) async {
    var url = Uri.parse('$baseUrl/attendance');

    // Add query parameters
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    if (employeeId != null) queryParams['employee_id'] = employeeId;

    if (queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      } else {
        return {"success": false, "logs": []};
      }
    } catch (e) {
      print("❌ Error fetching attendance logs: $e");
      return {"success": false, "logs": []};
    }
  }

  // NEW: Get all employees
  Future<Map<String, dynamic>> getAllEmployees() async {
    final url = Uri.parse('$baseUrl/employees');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      } else {
        return {"success": false, "count": 0, "employees": []};
      }
    } catch (e) {
      print("❌ Error fetching employees: $e");
      return {"success": false, "count": 0, "employees": []};
    }
  }

  // NEW: Delete employee
  Future<Map<String, dynamic>> deleteEmployee(String employeeId) async {
    final url = Uri.parse('$baseUrl/employees/$employeeId');

    try {
      final response = await http.delete(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      } else {
        return {"success": false, "message": "Failed to delete employee"};
      }
    } catch (e) {
      print("❌ Error deleting employee: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // NEW: Online self-registration
  Future<Map<String, dynamic>> registerOnline({
    required String firstname,
    required String lastname,
    required String employeeId,
    required String department,
    required String email,
    String? phone,
    required String imageBase64,
  }) async {
    final url = Uri.parse('$baseUrl/register/online');

    final body = {
      "firstname": firstname,
      "lastname": lastname,
      "employeeId": employeeId,
      "department": department,
      "email": email,
      "phone": phone,
      "image": imageBase64,
    };

    try {
      print("🌐 Sending online registration to: $url");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      print("📡 Response Status: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print("✅ Online registration successful!");
        return jsonData;
      } else if (response.statusCode == 409) {
        // Conflict - duplicate employee ID or email
        final jsonData = jsonDecode(response.body);
        return {
          "success": false,
          "error": jsonData['detail'] ?? "Employee ID or email already exists",
        };
      } else if (response.statusCode == 400) {
        // Bad request - validation error
        final jsonData = jsonDecode(response.body);
        return {
          "success": false,
          "error": jsonData['detail'] ?? "Invalid registration data",
        };
      } else {
        print("❌ Error: ${response.statusCode}");
        print("Response: ${response.body}");
        return {
          "success": false,
          "error": "Registration failed. Please try again.",
          "details": response.body
        };
      }
    } catch (e) {
      print("❌ Exception: $e");
      return {
        "success": false,
        "error": "Connection failed. Please check your internet connection.",
      };
    }
  }

  // ============================================
  // EVENT MANAGEMENT METHODS
  // ============================================

  // Create event
  Future<Map<String, dynamic>> createEvent({
    required String name,
    required String description,
    required String eventDate,  // YYYY-MM-DD format
    required String startTime,  // HH:MM format
    required String endTime,
    required String location,
    required List<String> participantIds,
  }) async {
    final url = Uri.parse('$baseUrl/events');

    final body = {
      "name": name,
      "description": description,
      "event_date": eventDate,
      "start_time": startTime,
      "end_time": endTime,
      "location": location,
      "participant_ids": participantIds,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Failed to create event"};
      }
    } catch (e) {
      print("❌ Error creating event: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // Get all events
  Future<Map<String, dynamic>> getAllEvents({String? status}) async {
    var url = Uri.parse('$baseUrl/events');

    if (status != null) {
      url = url.replace(queryParameters: {'status': status});
    }

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "count": 0, "events": []};
      }
    } catch (e) {
      print("❌ Error fetching events: $e");
      return {"success": false, "count": 0, "events": []};
    }
  }

  // Get event details
  Future<Map<String, dynamic>> getEventDetails(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching event details: $e");
      return {"success": false};
    }
  }

  // Update event
  Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    String? name,
    String? description,
    String? eventDate,
    String? startTime,
    String? endTime,
    String? location,
    String? status,
    List<String>? participantIds,
  }) async {
    final url = Uri.parse('$baseUrl/events/$eventId');

    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (description != null) body["description"] = description;
    if (eventDate != null) body["event_date"] = eventDate;
    if (startTime != null) body["start_time"] = startTime;
    if (endTime != null) body["end_time"] = endTime;
    if (location != null) body["location"] = location;
    if (status != null) body["status"] = status;
    if (participantIds != null) body["participant_ids"] = participantIds;

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Failed to update event"};
      }
    } catch (e) {
      print("❌ Error updating event: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // Delete event
  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId');

    try {
      final response = await http.delete(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Failed to delete event"};
      }
    } catch (e) {
      print("❌ Error deleting event: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // Mark event attendance
  Future<Map<String, dynamic>> markEventAttendance({
    required String eventId,
    required String employeeId,
  }) async {
    final url = Uri.parse('$baseUrl/events/$eventId/attendance');

    final body = {"employee_id": employeeId};

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Failed to mark attendance"};
      }
    } catch (e) {
      print("❌ Error marking event attendance: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  // Get event statistics
  Future<Map<String, dynamic>> getEventStats() async {
    final url = Uri.parse('$baseUrl/events/stats/summary');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching event stats: $e");
      return {"success": false};
    }
  }
}
