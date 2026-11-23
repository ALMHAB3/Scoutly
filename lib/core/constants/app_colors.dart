import 'package:flutter/material.dart';

/// ألوان التطبيق — مصدر الحقيقة الوحيد لكل ألوان Zentrip.
/// استخدم هذه الثوابت مباشرةً في الـ Widgets بدل أي ألوان hardcoded.
abstract class AppColors {
  // ── Primary ──────────────────────────────────────────────
  static const Color primary = Color(0xFF202F96);
  static const Color primaryLight = Color(0xFF5366D5);
  static const Color primarySurface = Color(0xFFE9ECFF);

  // ── Accent ───────────────────────────────────────────────
  static const Color accentTeal = Color(0xFF00B8D9);
  static const Color accentGreen = Color(0xFF00C896);
  static const Color accentOrange = Color(0xFFFF7043);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentYellow = Color(0xFFFFBF00);
  static const Color accentPurple = Color(0xFF7C3AED);

  // ── Neutral ──────────────────────────────────────────────
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF0F4FA);
  static const Color border = Color(0xFFE4EAF2);
  static const Color divider = Color(0xFFEDF0F5);

  // ── Text (Light) ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F1E36);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color textHint = Color(0xFFADB8CC);

  // ── Dark Mode ────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF131D30);
  static const Color darkSurfaceSecondary = Color(0xFF1A2640);
  static const Color darkBorder = Color(0xFF253450);
  static const Color darkTextPrimary = Color(0xFFEFF2F9);
  static const Color darkTextSecondary = Color(0xFF8093B0);

  // ── Basic colours (same values as Flutter's Colors.*) ────
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black54 = Color(0x8A000000);
  static const Color transparent = Color(0x00000000);
  static const Color amber = Color(0xFFFFC107);
  static const Color red = Color(0xFFF44336);
  static const Color grey = Color(0xFF9E9E9E);

  // ── Overlays (black with transparency) ───────────────────
  static const Color overlayClear = Color(0x00000000);
  static const Color shadowSoft = Color(0x1A000000);
  static const Color overlayLight = Color(0x33000000);
  static const Color overlayMedium = Color(0x55000000);
  static const Color overlayStrong = Color(0x99000000);
  static const Color overlayHeavy = Color(0xE6000000);

  // ── Auth screens (login, register, password reset) ───────
  static const Color authNavy = Color(0xFF1F2A9A);
  static const Color authFieldBackground = Color(0xFFF3F5FB);
  static const Color authHint = Color(0xFF9AA3B5);
  static const Color authText = Color(0xFF111827);
  static const Color authLine = Color(0xFFE9ECF3);
  static const Color authError = Color(0xFFE5484D);
  static const Color authSkyTop = Color(0xFF7FB6E8);
  static const Color authSkyBottom = Color(0xFFD6EAF8);
  static const Color authMountainLight = Color(0xFF8E9BE0);
  static const Color authMountainDark = Color(0xFF6F82D6);
  static const Color authSignpost = Color(0xFFF5A623);
  static const Color authSignpostBorder = Color(0xFF7A4A12);
  static const Color authSignpostPole = Color(0xFF9AA3B5);
  static const Color authSheetHandle = Color(0xFFE3E6EE);
  static const Color authCheckboxBorder = Color(0xFFB8BFCE);

  // ── Password strength meter ──────────────────────────────
  static const Color strengthWeak = Color(0xFFE5484D);
  static const Color strengthFair = Color(0xFFF5A623);
  static const Color strengthGood = Color(0xFF3DB26E);
  static const Color strengthStrong = Color(0xFF1F9D55);
  static const Color strengthEmpty = Color(0xFFE3E6EE);

  // ── Google logo ──────────────────────────────────────────
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleBlue = Color(0xFF4285F4);

  // ── Home screen ──────────────────────────────────────────
  static const Color homePrimary = Color(0xFF2B35A8);
  static const Color homeText = Color(0xFF14183A);
  static const Color homeMuted = Color(0xFF8A90A8);
  static const Color homeField = Color(0xFFF6F7FB);
  static const Color homeToggleBackground = Color(0xFFF1F3F9);
  static const Color homeTint = Color(0xFFE9ECFA);
  static const Color homeDivider = Color(0xFFE3E6F0);
  static const Color homeGreeting = Color(0xFFC9D0F5);
  static const Color homeBadge = Color(0xFFF5A524);
  static const Color homeSecondaryText = Color(0xFF5C627A);

  // ── Splash ───────────────────────────────────────────────
  static const Color splashBackground = Color(0xFFF9FAFF);

  // ── Flight seat map ──────────────────────────────────────
  static const Color seatNavy = Color(0xFF1E1B4B);
  static const Color seatInk = Color(0xFF172033);
  static const Color seatMuted = Color(0xFF81899B);
  static const Color seatLine = Color(0xFFE7EAF1);
  static const Color seatMapInk = Color(0xFF20263A);
  static const Color seatMapMuted = Color(0xFF8991A2);
  static const Color seatAvailable = Color(0xFFE8ECF5);
  static const Color seatTaken = Color(0xFFE9EBF0);
  static const Color seatTakenText = Color(0xFFC6CBD4);
  static const Color seatPlaceholder = Color(0xFFE9ECF3);

  // ── Classic booking confirmation (attractions, packages) ─
  static const Color confirmationBackground = Color(0xFF0B1020);
  static const Color confirmationIcon = Color(0xFF8B9BFF);
  static const Color confirmationSubtitle = Color(0xFFB6C0E0);

  // ── My Trips empty-state illustration (map and pins) ─────
  static const Color illustrationPaper = Color(0xFFFDF3E3);
  static const Color illustrationSea = Color(0xFF1A56C4);
  static const Color illustrationSeaLight = Color(0xFF2E6BDB);
  static const Color illustrationLand = Color(0xFF9CC3F5);
  static const Color illustrationFold = Color(0xFFF3E2C7);
  static const Color illustrationFoldLine = Color(0xFFE8D5B5);
  static const Color illustrationStroke = Color(0xFF8A6D3B);
  static const Color illustrationPinYellow = Color(0xFFF5A623);
  static const Color illustrationPinOrange = Color(0xFFF06E1D);
  static const Color illustrationPinShadow = Color(0xFFB74A0A);
  static const Color illustrationSun = Color(0xFFF5C142);
  static const Color illustrationDot = Color(0xFF0B2B66);

  // ── Map layers ───────────────────────────────────────────
  static const Color mapCafe = Color(0xFF8D6E63);

  // ── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF29399F), Color(0xFF18246F)],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF29399F), Color(0xFF5366D5)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7043), Color(0xFFFFBF00)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C896), Color(0xFF00B8D9)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF29399F)],
  );

  // قائمة تدرجات الوجهات — تُستخدم عشوائياً على بطاقات الحزم السياحية
  static const List<LinearGradient> destinationGradients = [
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF29399F), Color(0xFF5366D5)]),
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00C896), Color(0xFF29399F)]),
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7043), Color(0xFFFFBF00)]),
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B255F), Color(0xFF29399F)]),
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00B8D9), Color(0xFF00C896)]),
  ];
}
