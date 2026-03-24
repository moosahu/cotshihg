import 'package:flutter/material.dart';

/// Coaching App — Brand Identity
/// Primary: Deep Teal (نضج، ثقة، نمو)
/// Secondary: Warm Gold (إنجاز، تميز)
/// Accent: Soft Orange (طاقة، حماس)
class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF1A6B72);    // Deep Teal
  static const Color primaryLight = Color(0xFF2E9EA8);   // Light Teal
  static const Color secondaryColor = Color(0xFFF5A623); // Warm Gold
  static const Color accentColor = Color(0xFFFF6B35);    // Energetic Orange

  // UI Colors
  static const Color backgroundColor = Color(0xFFF7F9FC);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF5A623);

  // Gradient — used on splash & hero sections
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A6B72), Color(0xFF2E9EA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Cairo',
        textTheme: const TextTheme().apply(
          fontFamily: 'Cairo',
          fontFamilyFallback: ['SaudiRiyal'],
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
