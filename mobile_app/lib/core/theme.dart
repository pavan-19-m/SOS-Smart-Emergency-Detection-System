import 'package:flutter/material.dart';

class AppTheme {
  static const Color deepNavy = Color(0xFF0F2942);
  static const Color navySurface = Color(0xFF163654);
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color safetyGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color neutralBgLight = Color(0xFFF8FAFC);
  static const Color neutralBgDark = Color(0xFF0B1320);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepNavy,
      primary: deepNavy,
      error: emergencyRed,
      secondary: safetyGreen,
      tertiary: warningAmber,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: neutralBgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepNavy,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA),
      error: const Color(0xFFEF4444),
      secondary: const Color(0xFF22C55E),
      tertiary: const Color(0xFFF59E0B),
      surface: const Color(0xFF111C2D),
    ),
    scaffoldBackgroundColor: neutralBgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF152238),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF24344D)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF152238),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
