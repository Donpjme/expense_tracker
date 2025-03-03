import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Key for storing theme preference
  static const String _themePreferenceKey = 'theme_mode';

  // Current theme mode (light, dark, or system)
  ThemeMode _themeMode = ThemeMode.system;

  // Constructor - loads saved theme preference
  ThemeProvider() {
    _loadThemePreference();
  }

  // Getter for current theme mode
  ThemeMode get themeMode => _themeMode;

  // Load saved theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePreferenceKey);

      if (savedTheme != null) {
        _themeMode = _themeFromString(savedTheme);
        notifyListeners();
      }
    } catch (e) {
      // Fallback to system theme on error
      _themeMode = ThemeMode.system;
      print('Error loading theme preference: $e');
    }
  }

  // Save theme preference to SharedPreferences
  Future<void> _saveThemePreference(ThemeMode theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePreferenceKey, _themeToString(theme));
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Convert ThemeMode to string for storage
  String _themeToString(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // Convert string to ThemeMode
  ThemeMode _themeFromString(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        // This line is redundant and causing the warning
        // as all possible enum values are already handled
        // But keeping a default that returns system is a good practice
        // in case of unexpected values
        return ThemeMode.system;
    }
  }

  // Set theme mode to light
  void setLightMode() {
    _themeMode = ThemeMode.light;
    _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // Set theme mode to dark
  void setDarkMode() {
    _themeMode = ThemeMode.dark;
    _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // Set theme mode to system default
  void setSystemMode() {
    _themeMode = ThemeMode.system;
    _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // Toggle through theme modes (system -> light -> dark -> system)
  void toggleThemeMode() {
    switch (_themeMode) {
      case ThemeMode.system:
        setLightMode();
        break;
      case ThemeMode.light:
        setDarkMode();
        break;
      case ThemeMode.dark:
        setSystemMode();
        break;
    }
  }
}
