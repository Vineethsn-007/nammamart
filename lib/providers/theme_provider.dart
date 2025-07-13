import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  // Light theme colors - Yellow top bar, white background
  final Color _lightPrimaryColor = const Color(0xFFFFC107); // Yellow
  final Color _lightBackgroundColor = Colors.white; // White background
  final Color _lightSurfaceColor = Colors.white;
  final Color _lightCardColor = Colors.white;

  // Dark theme colors - Yellow top bar, dark background
  final Color _darkPrimaryColor = const Color(0xFFFFC107); // Yellow
  final Color _darkBackgroundColor =
      const Color(0xFF181A20); // True dark background
  final Color _darkSurfaceColor = const Color(0xFF23262B); // Dark card/surface
  final Color _darkCardColor = const Color(0xFF23262B); // Dark card

  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  // Light theme getters
  Color get lightPrimaryColor => _lightPrimaryColor;
  Color get lightBackgroundColor => _lightBackgroundColor;
  Color get lightSurfaceColor => _lightSurfaceColor;
  Color get lightCardColor => _lightCardColor;

  // Dark theme getters
  Color get darkPrimaryColor => _darkPrimaryColor;
  Color get darkBackgroundColor => _darkBackgroundColor;
  Color get darkSurfaceColor => _darkSurfaceColor;
  Color get darkCardColor => _darkCardColor;

  ThemeData getTheme() {
    return _isDarkMode ? _darkTheme() : _lightTheme();
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _lightPrimaryColor,
      scaffoldBackgroundColor: _lightBackgroundColor,
      cardColor: _lightCardColor,
      colorScheme: ColorScheme.light(
        primary: _lightPrimaryColor,
        secondary: _lightPrimaryColor,
        surface: _lightSurfaceColor,
        background: _lightBackgroundColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightCardColor,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade600,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
      dividerColor: Colors.grey.shade300,
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _darkPrimaryColor,
      scaffoldBackgroundColor: _darkBackgroundColor,
      cardColor: _darkCardColor,
      colorScheme: ColorScheme.dark(
        primary: _darkPrimaryColor,
        secondary: _darkPrimaryColor,
        surface: _darkSurfaceColor,
        background: _darkBackgroundColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkPrimaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkCardColor,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade400,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
      ),
      dividerColor: Colors.grey.shade700,
    );
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference();
    notifyListeners();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }
}
