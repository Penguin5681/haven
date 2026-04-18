import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusSm = 8.0;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14DB2777),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.rosePrimary,
        onPrimary: AppColors.textInverse,
        secondary: AppColors.bluePrimary,
        onSecondary: AppColors.textInverse,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.redPrimary,
        onError: AppColors.textInverse,
        outline: AppColors.divider,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.divider,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rosePrimary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.divider,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: AppTextStyles.buttonPrimary,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.rosePrimary,
          side: const BorderSide(color: AppColors.rosePrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: AppTextStyles.buttonSecondary,
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.rosePrimary,
          textStyle: AppTextStyles.buttonSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.rosePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.redPrimary, width: 2),
        ),
        hintStyle: AppTextStyles.bodyMedium,
        labelStyle: AppTextStyles.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.roseTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: AppColors.divider),
        ),
        labelStyle: AppTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      textTheme: _buildTextTheme(),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge:
          AppTextStyles.displayLarge.copyWith(color: AppColors.textPrimary),
      headlineLarge:
          AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimary),
      headlineMedium:
          AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary),
      bodyLarge:
          AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      bodyMedium:
          AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      bodySmall:
          AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      labelLarge:
          AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
      labelSmall:
          AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
    );
  }
}
