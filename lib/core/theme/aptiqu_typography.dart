import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Approved Outfit headings and Plus Jakarta Sans reading roles.
class AptiquTypography {
  AptiquTypography._();

  /// Color-free roles inherit the active theme and button foreground.
  static TextTheme get textTheme {
    TextStyle title(double size, FontWeight weight, double height) =>
        GoogleFonts.outfit(fontSize: size, fontWeight: weight, height: height);
    TextStyle body(double size, FontWeight weight, double height) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          height: height,
        );
    return TextTheme(
      displaySmall: title(28, FontWeight.w700, 1.2),
      headlineSmall: title(22, FontWeight.w700, 1.25),
      titleLarge: title(22, FontWeight.w700, 1.25),
      titleMedium: title(18, FontWeight.w600, 1.3),
      titleSmall: title(16, FontWeight.w600, 1.35),
      bodyLarge: body(16, FontWeight.w400, 1.5),
      bodyMedium: body(14, FontWeight.w400, 1.45),
      bodySmall: body(12, FontWeight.w400, 1.4),
      labelLarge: body(14, FontWeight.w600, 1.3),
      labelMedium: body(12, FontWeight.w500, 1.4),
      labelSmall: body(12, FontWeight.w500, 1.4),
    );
  }
}
