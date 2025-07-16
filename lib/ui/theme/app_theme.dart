import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// Available theme colors for the application
enum AppThemeColor {
  @JsonValue('darkGreen')
  darkGreen,
  @JsonValue('blue')
  blue,
  @JsonValue('purple')
  purple,
  @JsonValue('orange')
  orange,
  @JsonValue('red')
  red,
  @JsonValue('teal')
  teal,
}

/// Extension to get color scheme data for each theme color
extension AppThemeColorExtension on AppThemeColor {
  String get displayName {
    switch (this) {
      case AppThemeColor.darkGreen:
        return 'Dark Green';
      case AppThemeColor.blue:
        return 'Blue';
      case AppThemeColor.purple:
        return 'Purple';
      case AppThemeColor.orange:
        return 'Orange';
      case AppThemeColor.red:
        return 'Red';
      case AppThemeColor.teal:
        return 'Teal';
    }
  }

  Color get primaryColor {
    switch (this) {
      case AppThemeColor.darkGreen:
        return const Color(0xFF3A4D2D);
      case AppThemeColor.blue:
        return const Color(0xFF2196F3);
      case AppThemeColor.purple:
        return const Color(0xFF9C27B0);
      case AppThemeColor.orange:
        return const Color(0xFFFF9800);
      case AppThemeColor.red:
        return const Color(0xFFF44336);
      case AppThemeColor.teal:
        return const Color(0xFF009688);
    }
  }

  Color get primaryDarkColor {
    switch (this) {
      case AppThemeColor.darkGreen:
        return const Color(0xFF2D3A21);
      case AppThemeColor.blue:
        return const Color(0xFF1976D2);
      case AppThemeColor.purple:
        return const Color(0xFF7B1FA2);
      case AppThemeColor.orange:
        return const Color(0xFFF57C00);
      case AppThemeColor.red:
        return const Color(0xFFD32F2F);
      case AppThemeColor.teal:
        return const Color(0xFF00796B);
    }
  }

  Color get accentColor {
    switch (this) {
      case AppThemeColor.darkGreen:
        return const Color(0xFF4CAF50);
      case AppThemeColor.blue:
        return const Color(0xFF4CAF50);
      case AppThemeColor.purple:
        return const Color(0xFFE91E63);
      case AppThemeColor.orange:
        return const Color(0xFF4CAF50);
      case AppThemeColor.red:
        return const Color(0xFFFF9800);
      case AppThemeColor.teal:
        return const Color(0xFF4CAF50);
    }
  }
}

class AppTheme {
  // Common colors
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceDark = Color(0xFF121212);
  
  // Additional theme colors used throughout the app
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color accentGreen = Color(0xFF4CAF50);

  /// Creates a light theme with the specified color scheme
  static ThemeData lightTheme(AppThemeColor themeColor) {
    final colors = themeColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primaryColor,
        brightness: Brightness.light,
        primary: colors.primaryColor,
        secondary: colors.accentColor,
        error: errorRed,
        surface: surfaceLight,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentColor,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
    );
  }

  /// Creates a dark theme with the specified color scheme
  static ThemeData darkTheme(AppThemeColor themeColor) {
    final colors = themeColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primaryColor,
        brightness: Brightness.dark,
        primary: colors.primaryColor,
        secondary: colors.accentColor,
        error: errorRed,
        surface: surfaceDark,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.primaryDarkColor,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: surfaceDark,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentColor,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
    );
  }

  /// Default light theme (Dark Green)
  static ThemeData get defaultLightTheme => lightTheme(AppThemeColor.darkGreen);

  /// Default dark theme (Dark Green)
  static ThemeData get defaultDarkTheme => darkTheme(AppThemeColor.darkGreen);
}