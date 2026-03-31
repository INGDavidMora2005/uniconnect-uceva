import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen    = Color(0xFF085041);
  static const Color accentGreen     = Color(0xFF1D9E75);
  static const Color lightGreen      = Color(0xFF5DCAA5);
  static const Color backgroundApp   = Color(0xFFF7F8F5);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color borderDefault   = Color(0xFFD3D1C7);
  static const Color textDark        = Color(0xFF1C1B1F);
  static const Color textMedium      = Color(0xFF5A5A56);
  static const Color textLight       = Color(0xFF888780);
  static const Color textPlaceholder = Color(0xFF9A9893);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
    ),
    scaffoldBackgroundColor: AppColors.backgroundApp,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundWhite,
      hintStyle: const TextStyle(
        color: AppColors.textPlaceholder,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    ),
  );
}