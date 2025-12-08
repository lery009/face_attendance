import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Current user data
  Map<String, dynamic>? _currentUser;
  String? _token;

  /// Initialize and load saved auth data
  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    final userData = await _storage.read(key: _userKey);

    if (userData != null) {
      try {
        _currentUser = jsonDecode(userData);
      } catch (e) {
        print('Error loading user data: $e');
        await logout();
      }
    }
  }

  /// Save authentication token and user data
  Future<void> saveAuth(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  /// Clear authentication data
  Future<void> logout() async {
    _token = null;
    _currentUser = null;

    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Get current auth token
  String? get token => _token;

  /// Get current user data
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _token != null && _currentUser != null;

  /// Get user role
  String? get userRole => _currentUser?['role'];

  /// Check if user has specific role
  bool hasRole(String role) {
    final currentRole = userRole?.toLowerCase();
    if (currentRole == null) return false;

    // Role hierarchy: admin > manager > viewer
    const roleHierarchy = {
      'admin': 3,
      'manager': 2,
      'viewer': 1,
    };

    final currentLevel = roleHierarchy[currentRole] ?? 0;
    final requiredLevel = roleHierarchy[role.toLowerCase()] ?? 0;

    return currentLevel >= requiredLevel;
  }

  /// Check if user is admin
  bool get isAdmin => hasRole('admin');

  /// Check if user is manager or higher
  bool get isManager => hasRole('manager');

  /// Get user display name
  String get userName => _currentUser?['full_name'] ?? _currentUser?['username'] ?? 'User';

  /// Get user email
  String get userEmail => _currentUser?['email'] ?? '';
}
