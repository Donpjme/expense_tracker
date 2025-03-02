import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class ThemeProvider with ChangeNotifier {
  // Theme mode key for shared preferences
  static const String _themeKey = 'theme_mode';

  // Initialize logger
  final Logger _logger = Logger();

  // Default to system theme
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  // Load saved theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString(_themeKey);

      if (savedThemeMode != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedThemeMode,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      // Fallback to system theme if loading fails
      _themeMode = ThemeMode.system;
      _logger.e('Error loading theme mode: $e');
    }
  }

  // Toggle between light, dark and system theme
  Future<void> toggleThemeMode() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : _themeMode == ThemeMode.dark
            ? ThemeMode.system
            : ThemeMode.light;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.toString());
    } catch (e) {
      _logger.e('Error saving theme mode: $e');
    }

    notifyListeners();
  }

  // Set a specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.toString());
    } catch (e) {
      _logger.e('Error saving theme mode: $e');
    }

    notifyListeners();
  }
}
