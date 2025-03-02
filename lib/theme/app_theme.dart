import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color _primaryColor = Color(0xFF6200EE);
  static const Color _primaryDarkColor = Color(0xFFBB86FC);

  // Background colors
  static const Color _backgroundLight = Color(0xFFF5F7FA);
  static const Color _backgroundDark = Color(0xFF121212);

  // Card and surface colors
  static const Color _surfaceLight = Colors.white;
  static const Color _surfaceDark = Color(0xFF1E1E1E);

  // Error colors
  static const Color _errorColor = Color(0xFFB00020);
  static const Color _errorDarkColor = Color(0xFFCF6679);

  // Get light theme
  static ThemeData light() {
    return ThemeData(
      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        onPrimary: Colors.white,
        secondary: Color(0xFF03DAC6),
        onSecondary: Colors.black,
        error: _errorColor,
        onError: Colors.white,
        background: _backgroundLight,
        onBackground: Colors.black,
        surface: _surfaceLight,
        onSurface: Colors.black,
      ),

      // General theme data
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _backgroundLight,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        color: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // Card theme
      cardTheme: CardTheme(
        color: _surfaceLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Floating Action Button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),

      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Text Button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Input Decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceLight,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _surfaceLight,
        elevation: 24,
      ),
    );
  }

  // Get dark theme
  static ThemeData dark() {
    return ThemeData(
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: _primaryDarkColor,
        onPrimary: Colors.black,
        secondary: Color(0xFF03DAC6),
        onSecondary: Colors.black,
        error: _errorDarkColor,
        onError: Colors.black,
        background: _backgroundDark,
        onBackground: Colors.white,
        surface: _surfaceDark,
        onSurface: Colors.white,
      ),

      // General theme data
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primaryDarkColor,
      scaffoldBackgroundColor: _backgroundDark,

      // AppBar theme
      appBarTheme: AppBarTheme(
        color: _surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // Card theme
      cardTheme: CardTheme(
        color: _surfaceDark,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Floating Action Button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryDarkColor,
        foregroundColor: Colors.black,
      ),

      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: _primaryDarkColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Text Button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryDarkColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Input Decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryDarkColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorDarkColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceDark,
        selectedItemColor: _primaryDarkColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: _surfaceDark,
        elevation: 24,
      ),
    );
  }
}
