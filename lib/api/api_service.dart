import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../model/employee_match_response.dart';
import '../model/response_model.dart';
import '../services/auth_service.dart';

class ApiService {
  final String baseUrl = 'http://localhost:3000/api';  // Changed to localhost for local backend
  final AuthService _authService = AuthService();

  /// Get headers with authentication token
  Map<String, String> _getHeaders({bool includeAuth = false}) {
    final headers = {"Content-Type": "application/json"};

    if (includeAuth && _authService.token != null) {
      headers['Authorization'] = 'Bearer ${_authService.token}';
    }

    return headers;
  }

  // ========================================
  // AUTHENTICATION ENDPOINTS
  // ========================================

  /// Login user and get JWT token
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final body = {
      "username": username,
      "password": password,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        // Save token and user data
        await _authService.saveAuth(
          jsonData['access_token'],
          jsonData['user'],
        );

        return {"success": true, "user": jsonData['user']};
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Login failed'
        };
      }
    } catch (e) {
      print("❌ Login error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Register first admin user
  Future<Map<String, dynamic>> registerAdmin({
    required String username,
    required String password,
    required String email,
    String? fullName,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');

    final body = {
      "username": username,
      "password": password,
      "email": email,
      if (fullName != null) "full_name": fullName,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        // Save token and user data
        await _authService.saveAuth(
          jsonData['access_token'],
          jsonData['user'],
        );

        return {"success": true, "user": jsonData['user']};
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      print("❌ Registration error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get current user info
  Future<Map<String, dynamic>> getCurrentUser() async {
    final url = Uri.parse('$baseUrl/auth/me');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        return {"success": true, "user": jsonData['user']};
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to get user info'
        };
      }
    } catch (e) {
      print("❌ Get user error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get all users (requires manager role)
  Future<Map<String, dynamic>> getAllUsers() async {
    final url = Uri.parse('$baseUrl/users');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to fetch users'
        };
      }
    } catch (e) {
      print("❌ Get users error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Create new user (requires admin role)
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String email,
    required String role,
    String? fullName,
  }) async {
    final url = Uri.parse('$baseUrl/users');

    final body = {
      "username": username,
      "password": password,
      "email": email,
      "role": role,
      if (fullName != null) "full_name": fullName,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to create user'
        };
      }
    } catch (e) {
      print("❌ Create user error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Update user (requires admin role)
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
    String? password,
  }) async {
    final url = Uri.parse('$baseUrl/users/$userId');

    final body = <String, dynamic>{};
    if (email != null) body['email'] = email;
    if (fullName != null) body['full_name'] = fullName;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    if (password != null) body['password'] = password;

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to update user'
        };
      }
    } catch (e) {
      print("❌ Update user error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Delete user (requires admin role)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final url = Uri.parse('$baseUrl/users/$userId');

    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to delete user'
        };
      }
    } catch (e) {
      print("❌ Delete user error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // QR CODE ATTENDANCE
  // ========================================

  /// Get QR code for an employee
  Future<Map<String, dynamic>> getEmployeeQrCode(String employeeId) async {
    final url = Uri.parse('$baseUrl/employees/$employeeId/qr-code');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to get QR code'
        };
      }
    } catch (e) {
      print("❌ Get QR code error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Mark attendance using QR code token
  Future<Map<String, dynamic>> qrCheckIn({
    required String qrToken,
    String? eventId,
    double? latitude,
    double? longitude,
  }) async {
    final url = Uri.parse('$baseUrl/attendance/qr-check-in');

    final queryParams = <String, String>{'qr_token': qrToken};
    if (eventId != null) queryParams['event_id'] = eventId;
    if (latitude != null) queryParams['latitude'] = latitude.toString();
    if (longitude != null) queryParams['longitude'] = longitude.toString();

    final urlWithParams = url.replace(queryParameters: queryParams);

    try {
      final response = await http.post(urlWithParams).timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Check-in failed'
        };
      }
    } catch (e) {
      print("❌ QR check-in error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Regenerate QR code for an employee
  Future<Map<String, dynamic>> regenerateQrCode(String employeeId) async {
    final url = Uri.parse('$baseUrl/employees/$employeeId/regenerate-qr');

    try {
      final response = await http.post(url).timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to regenerate QR code'
        };
      }
    } catch (e) {
      print("❌ Regenerate QR code error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // LOCATION MANAGEMENT (GEOFENCING)
  // ========================================

  /// Get all locations
  Future<Map<String, dynamic>> getLocations({bool includeInactive = false}) async {
    final url = Uri.parse('$baseUrl/locations').replace(
      queryParameters: {'include_inactive': includeInactive.toString()}
    );

    try {
      final response = await http.get(url, headers: _getHeaders(includeAuth: true))
          .timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to fetch locations'
        };
      }
    } catch (e) {
      print("❌ Get locations error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Create a new location
  Future<Map<String, dynamic>> createLocation({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 100.0,
    String? address,
  }) async {
    final url = Uri.parse('$baseUrl/locations').replace(
      queryParameters: {
        'name': name,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_meters': radiusMeters.toString(),
        if (address != null) 'address': address,
      }
    );

    try {
      final response = await http.post(url, headers: _getHeaders(includeAuth: true))
          .timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to create location'
        };
      }
    } catch (e) {
      print("❌ Create location error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Update a location
  Future<Map<String, dynamic>> updateLocation({
    required String locationId,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? address,
    bool? isActive,
  }) async {
    final queryParams = <String, String>{};
    if (name != null) queryParams['name'] = name;
    if (latitude != null) queryParams['latitude'] = latitude.toString();
    if (longitude != null) queryParams['longitude'] = longitude.toString();
    if (radiusMeters != null) queryParams['radius_meters'] = radiusMeters.toString();
    if (address != null) queryParams['address'] = address;
    if (isActive != null) queryParams['is_active'] = isActive.toString();

    final url = Uri.parse('$baseUrl/locations/$locationId').replace(
      queryParameters: queryParams
    );

    try {
      final response = await http.put(url, headers: _getHeaders(includeAuth: true))
          .timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to update location'
        };
      }
    } catch (e) {
      print("❌ Update location error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Delete a location
  Future<Map<String, dynamic>> deleteLocation(String locationId) async {
    final url = Uri.parse('$baseUrl/locations/$locationId');

    try {
      final response = await http.delete(url, headers: _getHeaders(includeAuth: true))
          .timeout(Duration(seconds: 10));
      final jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return jsonData;
      } else {
        return {
          "success": false,
          "message": jsonData['detail'] ?? 'Failed to delete location'
        };
      }
    } catch (e) {
      print("❌ Delete location error: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // FACE DETECTION & RECOGNITION
  // ========================================

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

  // NEW: Get attendance logs with optional filters and search
  Future<Map<String, dynamic>> getAttendanceLogs({
    String? date,
    String? employeeId,
    String? search,
    String? status,
    String? startDate,
    String? endDate,
    String? method,
  }) async {
    var url = Uri.parse('$baseUrl/attendance');

    // Add query parameters
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    if (employeeId != null) queryParams['employee_id'] = employeeId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null) queryParams['status'] = status;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (method != null) queryParams['method'] = method;

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

  // NEW: Get all employees with optional search and filters
  Future<Map<String, dynamic>> getAllEmployees({
    String? search,
    String? department,
  }) async {
    var url = Uri.parse('$baseUrl/employees');

    // Add query parameters
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (department != null) queryParams['department'] = department;

    if (queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }

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

  // Get event participants
  Future<Map<String, dynamic>> getEventParticipants(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId/participants');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch participants'
        };
      }
    } catch (e) {
      print("❌ Error fetching event participants: $e");
      return {"success": false, "message": "Connection error: $e"};
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

  // ============================================
  // EXPORT METHODS
  // ============================================

  /// Get export URL for attendance data
  String getAttendanceExportUrl({
    required String format,  // csv, excel, pdf
    String? date,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) {
    var url = Uri.parse('$baseUrl/attendance/export');

    final queryParams = <String, String>{'format': format};
    if (date != null) queryParams['date'] = date;
    if (employeeId != null) queryParams['employee_id'] = employeeId;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    return url.replace(queryParameters: queryParams).toString();
  }

  /// Download attendance export file
  Future<Uint8List?> downloadAttendanceExport({
    required String format,  // csv, excel, pdf
    String? date,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    final exportUrl = getAttendanceExportUrl(
      format: format,
      date: date,
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
    );

    try {
      print("📥 Downloading export from: $exportUrl");
      final response = await http.get(Uri.parse(exportUrl)).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ Export downloaded successfully (${response.bodyBytes.length} bytes)");
        return response.bodyBytes;
      } else {
        print("❌ Export failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error downloading export: $e");
      return null;
    }
  }

  /// Get export URL for event attendance
  String getEventExportUrl({
    required String eventId,
    required String format,  // csv, excel, pdf
  }) {
    var url = Uri.parse('$baseUrl/events/$eventId/export');
    return url.replace(queryParameters: {'format': format}).toString();
  }

  /// Download event attendance export
  Future<Uint8List?> downloadEventExport({
    required String eventId,
    required String format,  // csv, excel, pdf
  }) async {
    final exportUrl = getEventExportUrl(eventId: eventId, format: format);

    try {
      print("📥 Downloading event export from: $exportUrl");
      final response = await http.get(Uri.parse(exportUrl)).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        print("✅ Event export downloaded successfully");
        return response.bodyBytes;
      } else {
        print("❌ Event export failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error downloading event export: $e");
      return null;
    }
  }

  // ============================================
  // ANALYTICS METHODS
  // ============================================

  /// Get comprehensive analytics overview
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final url = Uri.parse('$baseUrl/analytics/overview');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Analytics overview error: ${response.statusCode}");
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching analytics overview: $e");
      return {"success": false};
    }
  }

  /// Get attendance trends over specified days
  Future<Map<String, dynamic>> getAttendanceTrends({int days = 30}) async {
    final url = Uri.parse('$baseUrl/analytics/attendance-trends')
        .replace(queryParameters: {'days': days.toString()});

    try {
      final response = await http.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching attendance trends: $e");
      return {"success": false};
    }
  }

  /// Get department-wise statistics
  Future<Map<String, dynamic>> getDepartmentStats() async {
    final url = Uri.parse('$baseUrl/analytics/department-stats');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching department stats: $e");
      return {"success": false};
    }
  }

  /// Get employee performance rankings
  Future<Map<String, dynamic>> getEmployeePerformance({
    int days = 30,
    int limit = 10,
  }) async {
    final url = Uri.parse('$baseUrl/analytics/employee-performance')
        .replace(queryParameters: {
      'days': days.toString(),
      'limit': limit.toString(),
    });

    try {
      final response = await http.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error fetching employee performance: $e");
      return {"success": false};
    }
  }

  // ========================================
  // NOTIFICATION ENDPOINTS
  // ========================================

  /// Get notification system status and settings (Admin only)
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final url = Uri.parse('$baseUrl/notifications/status');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch notification status'
        };
      }
    } catch (e) {
      print("❌ Error fetching notification status: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Send a test email notification (Admin only)
  Future<Map<String, dynamic>> sendTestEmail(String testEmail) async {
    final url = Uri.parse('$baseUrl/notifications/test')
        .replace(queryParameters: {'test_email': testEmail});

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to send test email'
        };
      }
    } catch (e) {
      print("❌ Error sending test email: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Manually trigger daily summary email (Admin only)
  Future<Map<String, dynamic>> sendDailySummary(String adminEmail) async {
    final url = Uri.parse('$baseUrl/notifications/daily-summary')
        .replace(queryParameters: {'admin_email': adminEmail});

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to send daily summary'
        };
      }
    } catch (e) {
      print("❌ Error sending daily summary: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // INVITATION ENDPOINTS
  // ========================================

  /// Send registration invitation to email address (Admin only)
  /// Optional eventId to link invitation to a specific event
  Future<Map<String, dynamic>> sendInvitation(String email, {String? eventId}) async {
    final url = Uri.parse('$baseUrl/invitations/send');

    final body = {
      "email": email,
      if (eventId != null) "event_id": eventId,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to send invitation'
        };
      }
    } catch (e) {
      print("❌ Error sending invitation: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Validate invitation token
  Future<Map<String, dynamic>> validateInvitation(String token) async {
    final url = Uri.parse('$baseUrl/invitations/validate/$token');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "valid": false,
          "message": error['detail'] ?? 'Failed to validate invitation'
        };
      }
    } catch (e) {
      print("❌ Error validating invitation: $e");
      return {"valid": false, "message": "Connection error: $e"};
    }
  }

  /// Mark invitation as used after successful registration
  Future<Map<String, dynamic>> markInvitationUsed(String token, String employeeId) async {
    final url = Uri.parse('$baseUrl/invitations/mark-used/$token')
        .replace(queryParameters: {'employee_id': employeeId});

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to mark invitation as used'
        };
      }
    } catch (e) {
      print("❌ Error marking invitation as used: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // BULK OPERATIONS ENDPOINTS
  // ========================================

  /// Download CSV template for bulk employee import
  Future<Map<String, dynamic>> downloadBulkImportTemplate() async {
    final url = Uri.parse('$baseUrl/employees/bulk-import/template');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        // For web, trigger browser download
        // Note: This is a simplified version. For actual file download in Flutter web,
        // you may need to use additional packages like 'universal_html'
        return {
          "success": true,
          "data": response.body,
          "message": "Template downloaded"
        };
      } else {
        return {"success": false, "message": "Failed to download template"};
      }
    } catch (e) {
      print("❌ Error downloading template: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Bulk import employees from CSV
  Future<Map<String, dynamic>> bulkImportEmployees(String base64CsvData) async {
    final url = Uri.parse('$baseUrl/employees/bulk-import');

    final body = {
      "csv_data": base64CsvData,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Bulk import failed'
        };
      }
    } catch (e) {
      print("❌ Error bulk importing employees: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Bulk delete multiple employees (Admin only)
  Future<Map<String, dynamic>> bulkDeleteEmployees(List<String> employeeIds) async {
    final url = Uri.parse('$baseUrl/employees/bulk-delete');

    final body = {
      "employee_ids": employeeIds,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Bulk delete failed'
        };
      }
    } catch (e) {
      print("❌ Error bulk deleting employees: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Add additional face to existing employee (Multi-face registration)
  Future<Map<String, dynamic>> addFaceToEmployee(
    String employeeId,
    String base64Image,
  ) async {
    final url = Uri.parse('$baseUrl/employees/$employeeId/add-face');

    final body = {
      "image": base64Image,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to add face'
        };
      }
    } catch (e) {
      print("❌ Error adding face: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get face count for an employee
  Future<Map<String, dynamic>> getEmployeeFaceCount(String employeeId) async {
    final url = Uri.parse('$baseUrl/employees/$employeeId/face-count');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false};
      }
    } catch (e) {
      print("❌ Error getting face count: $e");
      return {"success": false};
    }
  }

  // ========================================
  // CAMERA MANAGEMENT ENDPOINTS
  // ========================================

  /// Create a new camera
  Future<Map<String, dynamic>> createCamera({
    required String name,
    required String cameraType,
    String? streamUrl,
    String? username,
    String? password,
    String? location,
  }) async {
    final url = Uri.parse('$baseUrl/cameras');

    final body = {
      "name": name,
      "camera_type": cameraType,
      if (streamUrl != null) "stream_url": streamUrl,
      if (username != null) "username": username,
      if (password != null) "password": password,
      if (location != null) "location": location,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to create camera'
        };
      }
    } catch (e) {
      print("❌ Error creating camera: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get all cameras
  Future<Map<String, dynamic>> getCameras() async {
    final url = Uri.parse('$baseUrl/cameras');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch cameras'
        };
      }
    } catch (e) {
      print("❌ Error fetching cameras: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get camera details
  Future<Map<String, dynamic>> getCamera(String cameraId) async {
    final url = Uri.parse('$baseUrl/cameras/$cameraId');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch camera'
        };
      }
    } catch (e) {
      print("❌ Error fetching camera: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Update camera
  Future<Map<String, dynamic>> updateCamera({
    required String cameraId,
    String? name,
    String? cameraType,
    String? streamUrl,
    String? username,
    String? password,
    String? location,
    bool? isActive,
    String? status,
  }) async {
    final url = Uri.parse('$baseUrl/cameras/$cameraId');

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (cameraType != null) body['camera_type'] = cameraType;
    if (streamUrl != null) body['stream_url'] = streamUrl;
    if (username != null) body['username'] = username;
    if (password != null) body['password'] = password;
    if (location != null) body['location'] = location;
    if (isActive != null) body['is_active'] = isActive;
    if (status != null) body['status'] = status;

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to update camera'
        };
      }
    } catch (e) {
      print("❌ Error updating camera: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Delete camera
  Future<Map<String, dynamic>> deleteCamera(String cameraId) async {
    final url = Uri.parse('$baseUrl/cameras/$cameraId');

    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to delete camera'
        };
      }
    } catch (e) {
      print("❌ Error deleting camera: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Test camera connection
  Future<Map<String, dynamic>> testCameraConnection(String cameraId) async {
    final url = Uri.parse('$baseUrl/cameras/$cameraId/test');

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to test camera'
        };
      }
    } catch (e) {
      print("❌ Error testing camera: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // ========================================
  // EVENT-CAMERA LINKING ENDPOINTS
  // ========================================

  /// Link camera to event
  Future<Map<String, dynamic>> linkCameraToEvent({
    required String eventId,
    required String cameraId,
    bool isPrimary = false,
  }) async {
    final url = Uri.parse('$baseUrl/events/$eventId/cameras');

    final body = {
      "camera_id": cameraId,
      "is_primary": isPrimary,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to link camera to event'
        };
      }
    } catch (e) {
      print("❌ Error linking camera to event: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Get event cameras
  Future<Map<String, dynamic>> getEventCameras(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId/cameras');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch event cameras'
        };
      }
    } catch (e) {
      print("❌ Error fetching event cameras: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Unlink camera from event
  Future<Map<String, dynamic>> unlinkCameraFromEvent({
    required String eventId,
    required String cameraId,
  }) async {
    final url = Uri.parse('$baseUrl/events/$eventId/cameras/$cameraId');

    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to unlink camera from event'
        };
      }
    } catch (e) {
      print("❌ Error unlinking camera from event: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // Camera Streaming Methods

  Future<Map<String, dynamic>> stopCameraStream(String cameraId) async {
    final url = Uri.parse('$baseUrl/cameras/$cameraId/stop-stream');

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Failed to stop stream"};
      }
    } catch (e) {
      print("❌ Error stopping camera stream: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  Future<Map<String, dynamic>> getEventCameraStreams(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId/stream');

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: true),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {
          "success": false,
          "message": error['detail'] ?? 'Failed to fetch camera streams'
        };
      }
    } catch (e) {
      print("❌ Error fetching event camera streams: $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  String getCameraStreamUrl(String cameraId, {bool withRecognition = true}) {
    if (withRecognition) {
      return '$baseUrl/cameras/$cameraId/stream/recognition';
    } else {
      return '$baseUrl/cameras/$cameraId/stream';
    }
  }

  String getCameraSnapshotUrl(String cameraId) {
    return '$baseUrl/cameras/$cameraId/snapshot';
  }

  // Invitation Management

  Future<Map<String, dynamic>> sendEventInvitations({
    required String eventId,
    required List<String> emails,
    String? baseUrl,
  }) async {
    try {
      final url = Uri.parse('$this.baseUrl/events/send-invitations');
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({
          'event_id': eventId,
          'emails': emails,
          'base_url': baseUrl ?? 'http://localhost:8080',
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to send invitations: ${response.statusCode}',
          'successful': [],
          'failed': emails,
        };
      }
    } catch (e) {
      print('❌ Error sending invitations: $e');
      return {
        'success': false,
        'message': 'Error sending invitations: $e',
        'successful': [],
        'failed': emails,
      };
    }
  }

  Future<Map<String, dynamic>> getEventInvitations(String eventId) async {
    final url = Uri.parse('$baseUrl/events/$eventId/invitations');
    final response = await http.get(
      url,
      headers: _getHeaders(includeAuth: true),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> resendInvitation({
    required String invitationId,
    String? baseUrl,
  }) async {
    final url = Uri.parse('$this.baseUrl/invitations/$invitationId/resend?base_url=${baseUrl ?? 'http://localhost:8080'}');
    final response = await http.post(
      url,
      headers: _getHeaders(includeAuth: true),
    );

    return jsonDecode(response.body);
  }
}
