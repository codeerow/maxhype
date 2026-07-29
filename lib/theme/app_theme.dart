import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors from the design
  static const Color backgroundColor = Color(0xFF0A0E27);
  static const Color cardBackground = Color(0xFF1A1F3A);
  static const Color primaryOrange = Color(0xFFFF8A3D);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E92A8);

  // Fitness Plan surface (mirrors the web prototype's settings palette).
  //
  // The web app paints the whole screen a single uniform navy (`#0f172a`) —
  // the "dark navy between the main hubs" — and floats slightly lighter
  // translucent cards on top of it for each sub-section, so section titles
  // sit on the dark navy while their rows live on the lighter card.
  //
  /// Uniform dark-navy background for the Fitness Plan and History screens.
  /// One shade, no per-segment tinting.
  static const Color planBackground = Color(0xFF071223);

  /// Lighter navy card that sub-sections float on. `white @ 4%` over
  /// [planBackground], flattened to an opaque colour for cheap painting.
  static const Color planCardBackground = Color(0xFF181F2E);

  /// Hairline border/divider used on plan cards and between their rows.
  static const Color planCardBorder = Color(0x14FFFFFF); // white @ 8%

  /// Muted uppercase section-label colour ("ROUTINE", "OPTIONAL", …).
  static const Color planSectionLabel = Color(0x61FFFFFF); // white @ 38%

  /// Green used for "Enabled" status badges (text) on the plan screen.
  static const Color planBadgeGreen = Color(0xFF33E39A);

  /// Fill behind the green "Enabled" badge.
  static const Color planBadgeGreenBg = Color(0x2633E39A); // green @ 15%

  /// Orange used for the circular back arrow on the plan screen.
  static const Color planBackArrow = Color(0xFFFF8C42);

  /// Fill for an individual duration segment (the tappable 45/60/… cells),
  /// slightly deeper than the track they sit on ([planCardBackground]).
  static const Color planDurationSegment = Color(0xFF181C2D);

  /// Lighter, warmer peach-orange for the label inside the *selected* duration
  /// segment — softer than [primaryOrange] (used for that segment's border and
  /// glow), matching the picker mockup.
  static const Color planDurationSelectedText = Color(0xFFF3AF76);

  // Recovery status colors
  static const Color recoveryGreen = Color(0xFF4ADE80);
  static const Color recoveryYellow = Color(0xFFFBBF24);
  static const Color recoveryRed = Color(0xFFEF4444);

  // Chart colors
  static const Color chartOrange = Color(0xFFFF8A3D);
  static const Color chartGreen = Color(0xFF22C55E);

  // Workout session palette
  /// Brighter premium-orange variant used for the active-exercise accent bar.
  static const Color activeOrange = Color(0xFFFFB066);

  /// Maroon used for the destructive "Finish" sticky button on the session
  /// main screen. Distinct from `recoveryRed` (bright alert red).
  static const Color finishMaroon = Color(0xFF7E1D1D);

  /// Dark-orange tinted card used for the rest-timer surface.
  static const Color restCardTint = Color(0xFF2A1608);

  /// Brighter card tone used to "lift" an active-exercise card.
  static const Color cardBackgroundLifted = Color(0xFF222845);

  /// Subtle red tint for exercise card thumbnails.
  static const Color thumbnailRedTint = Color(0xFF3A1A1F);

  static ThemeData get darkTheme {
    // Inter is the closest open-source aproximation of SF Pro and gives the
    // app a consistent iOS-like type system on every platform.
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryOrange,

      // Force Cupertino-style horizontal slide on every platform so any
      // MaterialPageRoute (e.g., framework dialogs, third-party plugins)
      // matches the iOS feel of the rest of the app.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),

      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryOrange,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),

      // iOS-style flat AppBar: no shadow, no surface tint, transparent
      // background tied to scaffold.
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  static Color getRecoveryColor(double percentage) {
    if (percentage >= 90) {
      return recoveryGreen;
    } else if (percentage >= 70) {
      return recoveryYellow;
    } else {
      return recoveryRed;
    }
  }
}
