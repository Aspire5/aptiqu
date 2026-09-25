import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'aptiqu_colors.dart';

/// Aptiqu Design System Typography
/// Using Outfit (Headlines), Plus Jakarta Sans (Body), and Space Grotesk (Metrics & Caps).
class AptiquTypography {
  AptiquTypography._();

  // Display & Headlines (Outfit)
  static TextStyle displayHero = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AptiquColors.onSurface,
    letterSpacing: -0.5,
  );

  static TextStyle headlineMd = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AptiquColors.onSurface,
    letterSpacing: -0.3,
  );

  static TextStyle headlineSm = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AptiquColors.onSurface,
    letterSpacing: -0.2,
  );

  // Body Text (Plus Jakarta Sans)
  static TextStyle bodyLg = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AptiquColors.onSurface,
    height: 1.5,
  );

  static TextStyle bodyMd = GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: AptiquColors.onSurface,
    height: 1.45,
  );

  static TextStyle bodySm = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AptiquColors.onSurfaceVariant,
    height: 1.4,
  );

  // Metrics, Numbers & Counters (Space Grotesk)
  static TextStyle metricLg = GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AptiquColors.onSurface,
    letterSpacing: 0.2,
  );

  static TextStyle metricMd = GoogleFonts.spaceGrotesk(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AptiquColors.onSurface,
    letterSpacing: 0.1,
  );

  static TextStyle metricSm = GoogleFonts.spaceGrotesk(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AptiquColors.onSurfaceVariant,
  );

  // Labels & Chips (Space Grotesk Uppercase)
  static TextStyle labelCaps = GoogleFonts.spaceGrotesk(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AptiquColors.onSurfaceVariant,
  );

  static TextStyle labelCapsBold = GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    color: AptiquColors.primary,
  );
}
