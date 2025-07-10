import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  
  // Light theme colors
  final Color _lightPrimaryColor = const Color(0xFFFFDD00); // yellow
  final Color _lightBackgroundColor = Colors.white;
  final Color _lightSurfaceColor = Colors.white;
  final Color _lightCardColor = Colors.white;
  
  // Dark theme colors
  final Color _darkPrimaryColor = const Color(0xFFFFDD00); // Light yellow
  final Color _darkBackgroundColor = const Color(0xFF121212);
  final Color _darkSurfaceColor = const Color(0xFF1E1E1E);
  final Color _darkCardColor = const Color(0xFF252525);
  
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
        backgroundColor: _lightCardColor,
        foregroundColor: _lightPrimaryColor,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightCardColor,
        selectedItemColor: _lightPrimaryColor,
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
        backgroundColor: _darkCardColor,
        foregroundColor: _darkPrimaryColor,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkCardColor,
        selectedItemColor: _darkPrimaryColor,
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

