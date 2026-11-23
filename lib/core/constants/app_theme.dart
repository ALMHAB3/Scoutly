import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTheme {
  static ThemeData lightTheme({bool isArabic = false}) {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.accentTeal,
        surface: AppColors.surface,
        // ignore: deprecated_member_use
        background: AppColors.background,
        error: AppColors.accentRed,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: _fontStyle(
          isArabic,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textTheme: _buildTextTheme(
          AppColors.textPrimary, AppColors.textSecondary, isArabic),
      inputDecorationTheme:
          _inputDecorationTheme(isDark: false, isArabic: isArabic),
      elevatedButtonTheme: _elevatedButtonTheme(isArabic),
      outlinedButtonTheme: _outlinedButtonTheme(isArabic),
      textButtonTheme: _textButtonTheme(isArabic),
      cardTheme: _cardTheme(isDark: false),
      chipTheme: _chipTheme(isDark: false, isArabic: isArabic),
      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(elevation: 0),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static ThemeData darkTheme({bool isArabic = false}) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        onPrimary: AppColors.white,
        secondary: AppColors.accentTeal,
        surface: AppColors.darkSurface,
        // ignore: deprecated_member_use
        background: AppColors.darkBackground,
        error: AppColors.accentRed,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: _fontStyle(
          isArabic,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
      ),
      textTheme: _buildTextTheme(
          AppColors.darkTextPrimary, AppColors.darkTextSecondary, isArabic),
      inputDecorationTheme:
          _inputDecorationTheme(isDark: true, isArabic: isArabic),
      elevatedButtonTheme: _elevatedButtonTheme(isArabic),
      outlinedButtonTheme: _outlinedButtonTheme(isArabic),
      textButtonTheme: _textButtonTheme(isArabic),
      cardTheme: _cardTheme(isDark: true),
      chipTheme: _chipTheme(isDark: true, isArabic: isArabic),
      dividerTheme:
          const DividerThemeData(color: AppColors.darkBorder, thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    bool isArabic,
  ) {
    final base = isArabic
        ? GoogleFonts.cairoTextTheme()
        : GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge: _fontStyle(isArabic,
          fontSize: 57, fontWeight: FontWeight.w800, color: primary),
      displayMedium: _fontStyle(isArabic,
          fontSize: 45, fontWeight: FontWeight.w800, color: primary),
      displaySmall: _fontStyle(isArabic,
          fontSize: 36, fontWeight: FontWeight.w700, color: primary),
      headlineLarge: _fontStyle(isArabic,
          fontSize: 32, fontWeight: FontWeight.w700, color: primary),
      headlineMedium: _fontStyle(isArabic,
          fontSize: 26, fontWeight: FontWeight.w700, color: primary),
      headlineSmall: _fontStyle(isArabic,
          fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      titleLarge: _fontStyle(isArabic,
          fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleMedium: _fontStyle(isArabic,
          fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleSmall: _fontStyle(isArabic,
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: _fontStyle(isArabic,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primary,
          height: 1.6),
      bodyMedium: _fontStyle(isArabic,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.6),
      bodySmall: _fontStyle(isArabic,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.5),
      labelLarge: _fontStyle(isArabic,
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: _fontStyle(isArabic,
          fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
      labelSmall: _fontStyle(isArabic,
          fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required bool isDark,
    required bool isArabic,
  }) {
    final fillColor =
        isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentRed)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5)),
      hintStyle: _fontStyle(isArabic, color: textColor, fontSize: 14),
      labelStyle: _fontStyle(isArabic, color: textColor, fontSize: 14),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(bool isArabic) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            _fontStyle(isArabic, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(bool isArabic) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            _fontStyle(isArabic, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(bool isArabic) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle:
            _fontStyle(isArabic, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static CardThemeData _cardTheme({required bool isDark}) {
    return CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static ChipThemeData _chipTheme({
    required bool isDark,
    required bool isArabic,
  }) {
    return ChipThemeData(
      backgroundColor:
          isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
      selectedColor: AppColors.primarySurface,
      labelStyle:
          _fontStyle(isArabic, fontSize: 13, fontWeight: FontWeight.w500),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  static TextStyle _fontStyle(
    bool isArabic, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) =>
      isArabic
          ? GoogleFonts.cairo(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            )
          : GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
}
