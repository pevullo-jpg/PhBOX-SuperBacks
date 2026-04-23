import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color panel = Color(0xFF111111);
  static const Color panelSoft = Color(0xFF1A1A1A);
  static const Color yellow = Color(0xFFF6BE0F);
  static const Color coral = Color(0xFFE43D57);
  static const Color pink = Color(0xFFF1B7BD);
  static const Color wine = Color(0xFFB11434);
  static const Color green = Color(0xFF1E6B3A);
  static const Color amber = Color(0xFFA66B00);
  static const Color red = Color(0xFF8F1D1D);
  static const Color blue = Color(0xFF144D7A);
  static const Color border = Color(0xFF2B2B2B);
}

class AppTheme {
  static ThemeData get darkTheme {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      fontFamily: 'Arial',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panelSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.yellow),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
