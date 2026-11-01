import 'package:flutter/material.dart';

/// Spacing, radius, and chunky depth tokens (Duolingo-Inspired Theme).
class AppTokens {
  AppTokens._();

  // ─── Spacing Scale (4/8-pt base) ──────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // ─── Radii System (Approachable & Rounded) ────────────────────────────────
  /// Chips, tags, small icon tiles (10px)
  static const double radiusSmall = 10.0;
  static const Radius rSmall = Radius.circular(radiusSmall);
  static const BorderRadius brSmall = BorderRadius.all(rSmall);

  /// Buttons, textfields, segmented controls (14px)
  static const double radiusMedium = 14.0;
  static const Radius rMedium = Radius.circular(radiusMedium);
  static const BorderRadius brMedium = BorderRadius.all(rMedium);

  /// Cards, modal sheets, hero panels (18px)
  static const double radiusLarge = 18.0;
  static const Radius rLarge = Radius.circular(radiusLarge);
  static const BorderRadius brLarge = BorderRadius.all(rLarge);

  /// Avatars, pill badges, circular buttons
  static const double radiusFull = 999.0;
  static const Radius rFull = Radius.circular(radiusFull);
  static const BorderRadius brFull = BorderRadius.all(rFull);

  // ─── Chunky 3D Tactile Depth (Duolingo signature) ─────────────────────────
  /// Button 3D bottom bevel depth
  static const double buttonDepth = 4.0;
  /// Button pressed down offset
  static const double buttonPressedOffset = 2.0;
  /// Card border thickness
  static const double cardBorderWidth = 2.0;

  // ─── Responsive Bounds ────────────────────────────────────────────────────
  /// Max width for centered tablet/desktop layouts
  static const double maxContentWidth = 640.0;

  // ─── Touch Targets ────────────────────────────────────────────────────────
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 50.0;
}
