import 'package:flutter/material.dart';

abstract final class AppColors {
  static const paper = Color(0xFFF8F4EC);
  static const paperStrong = Color(0xFFFFFCF6);
  static const ink = Color(0xFF171A1D);
  static const inkSoft = Color(0xFF5D6166);
  static const orange = Color(0xFFFF6B35);
  static const orangeDark = Color(0xFFCC3D12);
  static const red = Color(0xFFEE4266);
  static const mint = Color(0xFF06D6A0);
  static const yellow = Color(0xFFFFCC4D);
  static const blue = Color(0xFF3587FF);
  static const line = Color(0xFFE4DED2);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.orange,
    brightness: Brightness.light,
    surface: AppColors.paperStrong,
    primary: AppColors.orange,
    secondary: AppColors.mint,
    error: AppColors.red,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.paper,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.2,
        height: 0.98,
      ),
      headlineLarge: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.paperStrong,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: AppColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paperStrong,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.paperStrong,
      indicatorColor: Color(0xFFFFD9CB),
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
      ),
    ),
  );
}
