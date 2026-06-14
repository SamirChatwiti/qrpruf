import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.primaryDark : AppColors.primary;
    final Color scaffoldBg = isDark ? AppColors.scaffoldBackgroundDark : AppColors.scaffoldBackground;
    final Color surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final Color textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final Color textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final Color inputBg = isDark ? AppColors.inputBackgroundDark : AppColors.inputBackground;
    final Color divider = isDark ? AppColors.dividerDark : AppColors.divider;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: surface,
      primaryColor: primary,
      dividerColor: divider,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: surface,
        onSurface: textPrimary,
        primary: primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: isDark ? AppColors.secondary : AppColors.secondary,
        error: AppColors.error,
      ),

      textTheme: AppTypography.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: isDark ? textPrimary : textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black, // Background black
          statusBarIconBrightness: Brightness.light, // Android: White icons
          statusBarBrightness: Brightness.dark, // iOS: Light text
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.textOnPrimary,
          textStyle: AppTypography.textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
