import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A6B72);
  static const Color primaryLight = Color(0xFF2E9EA8);
  static const Color secondaryColor = Color(0xFFF5A623);
  static const Color backgroundColor = Color(0xFFF7F9FC);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF5A623);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A6B72), Color(0xFF2E9EA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, primary: primaryColor),
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Cairo',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(color: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}
