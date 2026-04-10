import 'package:flutter/material.dart';

class AppTheme {
  // Colors from the design
  static const Color backgroundColor = Color(0xFF0A0E27);
  static const Color cardBackground = Color(0xFF1A1F3A);
  static const Color primaryOrange = Color(0xFFFF8A3D);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E92A8);

  // Recovery status colors
  static const Color recoveryGreen = Color(0xFF4ADE80);
  static const Color recoveryYellow = Color(0xFFFBBF24);
  static const Color recoveryRed = Color(0xFFEF4444);

  // Chart colors
  static const Color chartOrange = Color(0xFFFF8A3D);
  static const Color chartGreen = Color(0xFF22C55E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryOrange,
      fontFamily: 'SF Pro Display',

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryOrange,
        ),
        displayMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodyMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Color getRecoveryColor(double percentage) {
    if (percentage >= 90) {
      return recoveryGreen;
    } else if (percentage >= 70) {
      return recoveryYellow;
    } else {
      return recoveryRed;
    }
  }
}
