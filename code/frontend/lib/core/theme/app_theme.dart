import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static const String fontSans = 'DMSans';
  static const String fontMono = 'JetBrainsMono';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryMain,
        surface: AppColors.surfaceCard,
        error: AppColors.expense,
        brightness: Brightness.light,
      ),
      fontFamily: fontSans,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontSans,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -1.0,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        displayMedium: TextStyle(
          fontFamily: fontSans,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.6,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineLarge: TextStyle(
          fontFamily: fontSans,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontSans,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontSans,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: fontSans,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          fontFamily: fontSans,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: fontSans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontSans,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontSans,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: fontSans,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontFamily: fontSans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontFamily: fontSans,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          side: const BorderSide(
            color: AppColors.border,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, AppTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surfaceCard,
          side: const BorderSide(
            color: AppColors.border,
            width: AppTokens.cardBorderWidth,
          ),
          minimumSize: const Size(64, AppTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(
            AppTokens.minTouchTarget,
            AppTokens.minTouchTarget,
          ),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.primaryMain,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.expense,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.expense,
            width: AppTokens.cardBorderWidth,
          ),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceCard,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceCream,
        selectedColor: AppColors.mint,
        labelStyle: const TextStyle(
          fontFamily: fontSans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          side: const BorderSide(
            color: AppColors.border,
            width: AppTokens.cardBorderWidth,
          ),
        ),
      ),
    );
  }
}
