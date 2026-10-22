import 'package:flutter/cupertino.dart';

/// Shared spacing / radius / type tokens used across screens.
abstract final class MusynStyle {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;
  static const double radiusPill = 28;

  static const Color oledBlack = Color(0xFF000000);
  static const Color elevated = Color(0xFF0D0D0F);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceHigh = Color(0xFF2C2C2E);
  static const Color hairline = Color(0x33FFFFFF);
  static const Color secondaryLabel = Color(0x99EBEBF5);
  static const Color tertiaryLabel = Color(0x4DEBEBF5);

  /// Musyn player tokens.
  static const Color brandCoral = Color(0xFFFFC5A7);
  static const Color brandCoralLight = Color(0xFFAA4937);
  static const Color appleRed = Color(0xFFFA2D48);
  static const Color darkNearBlack = Color(0xFF0D0D0F);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkSecondary = Color(0xFF8E8E93);

  // Light (Apple Music–like cool white)
  static const Color lightCanvas = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F7F9);
  static const Color lightSurfaceHigh = Color(0xFFE5E5EA);
  static const Color lightHairline = Color(0x33000000);
  static const Color lightSecondaryLabel = Color(0x993C3C43);
  static const Color lightTertiaryLabel = Color(0x4D3C3C43);
  static const Color lightOnSurface = Color(0xFF1C1C1E);

  static const String uiFont = '.SF Pro Text';
  static const String displayFont = '.SF Pro Display';

  /// Brand / large-title wordmark.
  static TextStyle brandTitle(Color color) => TextStyle(
    fontFamily: displayFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle largeTitle(Color color) => TextStyle(
    fontFamily: displayFont,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.15,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle sectionTitle(Color color) => TextStyle(
    fontFamily: displayFont,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle songTitle(Color color) => TextStyle(
    fontFamily: uiFont,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle songSubtitle(Color color) => TextStyle(
    fontFamily: uiFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.25,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle caption(Color color) => TextStyle(
    fontFamily: uiFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.05,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle playerTitle(Color color) => TextStyle(
    fontFamily: displayFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle playerArtist(Color color) => TextStyle(
    fontFamily: uiFont,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: color,
    decoration: TextDecoration.none,
  );

  static BorderSide hairlineBorder([Color? color]) =>
      BorderSide(color: color ?? hairline, width: 0.5);

  /// Solid elevated fill for mini player / sheets — no BackdropFilter.
  static BoxDecoration solidElevated({
    required bool isDark,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: isDark ? surface : lightElevated,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: isDark ? hairline : lightHairline, width: 0.5),
    );
  }
}
