import 'package:flutter/material.dart';

/// Aptiqu Design System Color Palette
/// Curated for dark cyberpunk aesthetic, high readability, and vibrant neon accents.
class AptiquColors {
  AptiquColors._();

  // Surface & Background Colors
  static const Color surfaceDim = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF0F131C);
  static const Color surfaceContainerLowest = Color(0xFF060910);
  static const Color surfaceContainerLow = Color(0xFF131722);
  static const Color surfaceContainer = Color(0xFF1A1F2C);
  static const Color surfaceContainerHigh = Color(0xFF232838);
  static const Color surfaceContainerHighest = Color(0xFF2E3447);

  // Brand Colors (Violet & Purple spectrum)
  static const Color primary = Color(0xFFD0BCFF);
  static const Color primaryContainer = Color(0xFF8B5CF6);
  static const Color onPrimary = Color(0xFF24005A);
  static const Color primaryDark = Color(0xFF6D28D9);

  // Secondary Accents (Cyan spectrum)
  static const Color secondary = Color(0xFF22D3EE);
  static const Color secondaryContainer = Color(0xFF0891B2);
  static const Color onSecondary = Color(0xFF00363F);

  // Tertiary Accents (Amber / Gold / Fire)
  static const Color tertiary = Color(0xFFFFB95F);
  static const Color tertiaryContainer = Color(0xFFD97706);

  // Text & Content Colors
  static const Color onSurface = Color(0xFFDFE2EF);
  static const Color onSurfaceVariant = Color(0xFF9BA1B6);
  static const Color onSurfaceDisabled = Color(0xFF5E657C);

  // Borders & Outlines
  static const Color outline = Color(0xFF3D445C);
  static const Color outlineVariant = Color(0xFF252B3D);

  // Glow Shadows & Gradients
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primaryContainer.withValues(alpha: 0.4),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get secondaryGlow => [
        BoxShadow(
          color: secondary.withValues(alpha: 0.35),
          blurRadius: 14,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardElevation => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryContainer, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberAccentGradient = LinearGradient(
    colors: [primaryContainer, secondary, Colors.transparent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
