import 'package:flutter/material.dart';

class AppColors {
  static bool _isDarkMode = false;

  static void setDarkMode(bool enabled) {
    _isDarkMode = enabled;
  }

  static bool get isDarkMode => _isDarkMode;

  // Primary colors - Cool blue tones (hydration theme)
  static const Color primary = Color(0xFF2E7D9E); // Deep water blue
  static const Color primaryLight = Color(0xFF4A9FBD); // Lighter blue
  static const Color primaryDark = Color(0xFF1B5B7F); // Darker blue

  // Accent colors - Complementary warm tones
  static const Color accent = Color(0xFFFF6B6B); // Coral red for action/alerts
  static const Color accentLight = Color(0xFFFFE5E5); // Light coral background
  static const Color success = Color(0xFF2ECC71); // Green for success states
  static const Color warning = Color(0xFFF59E0B); // Amber warning accent

  // Neutral colors
    static Color get background => _isDarkMode
      ? const Color(0xFF0F172A)
      : const Color(0xFFFAFCFE); // Very light blue-gray
    static Color get surface => _isDarkMode
      ? const Color(0xFF111827)
      : const Color(0xFFFFFFFF); // White
    static Color get surfaceVariant => _isDarkMode
      ? const Color(0xFF1F2937)
      : const Color(0xFFF5F7FA); // Light gray

  // Text colors
    static Color get textPrimary =>
      _isDarkMode ? const Color(0xFFF3F4F6) : const Color(0xFF1A1A1A);
    static Color get textSecondary =>
      _isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);
    static Color get textTertiary =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF);

  // Border colors
    static Color get border =>
      _isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    static Color get borderFocus => primary; // Blue border on focus

  // Error colors
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        tertiary: AppColors.primaryLight,
        error: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFCFE),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Colors.black,
        secondary: AppColors.accent,
        onSecondary: Colors.black,
        tertiary: AppColors.primary,
        error: AppColors.error,
        surface: Color(0xFF111827),
        onSurface: Color(0xFFF3F4F6),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Color(0xFFF3F4F6),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
