import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Initialize theme from saved preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (savedTheme != null) {
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _saveTheme();
    notifyListeners();
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveTheme();
    notifyListeners();
  }

  /// Save theme preference
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  // ========================================
  // LIGHT THEME
  // ========================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1E3A8A), // Navy blue
      scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Light gray

      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1E3A8A), // Navy blue
        secondary: Color(0xFF059669), // Green
        surface: Colors.white,
        error: Color(0xFFF44336), // Red
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1F2937), // Dark gray text
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1E3A8A),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF44336)),
        ),
      ),

      iconTheme: const IconThemeData(
        color: Color(0xFF1E3A8A),
      ),

      dividerColor: Colors.grey[200],
    );
  }

  // ========================================
  // DARK THEME
  // ========================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF3B82F6), // Lighter blue for dark mode
      scaffoldBackgroundColor: const Color(0xFF111827), // Very dark gray

      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6), // Lighter blue
        secondary: Color(0xFF10B981), // Lighter green
        surface: Color(0xFF1F2937), // Dark gray
        error: Color(0xFFEF4444), // Lighter red
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFF9FAFB), // Light gray text
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1F2937),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3B82F6),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF374151),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4B5563)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4B5563)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),

      iconTheme: const IconThemeData(
        color: Color(0xFF3B82F6),
      ),

      dividerColor: const Color(0xFF374151),
    );
  }

  // ========================================
  // CUSTOM COLORS (THEME-AWARE)
  // ========================================

  /// Get appropriate color based on current theme
  Color getStatColor(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case 'green':
        return isDark ? const Color(0xFF10B981) : const Color(0xFF10B981);
      case 'blue':
        return isDark ? const Color(0xFF3B82F6) : const Color(0xFF3B82F6);
      case 'orange':
        return isDark ? const Color(0xFFF59E0B) : const Color(0xFFFF9800);
      case 'red':
        return isDark ? const Color(0xFFEF4444) : const Color(0xFFF44336);
      default:
        return isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E3A8A);
    }
  }

  /// Get card background color
  Color getCardColor(BuildContext context) {
    return Theme.of(context).cardTheme.color ??
           (Theme.of(context).brightness == Brightness.dark
             ? const Color(0xFF1F2937)
             : Colors.white);
  }

  /// Get text color
  Color getTextColor(BuildContext context, {bool secondary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (secondary) {
      return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    }
    return isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
  }

  /// Get border color
  Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF374151)
        : Colors.grey[300]!;
  }
}
