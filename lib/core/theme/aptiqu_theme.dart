import 'package:flutter/material.dart';
import 'aptiqu_colors.dart';
import 'aptiqu_typography.dart';

/// Aptiqu Global Dark Theme
class AptiquTheme {
  AptiquTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AptiquColors.surfaceDim,
      primaryColor: AptiquColors.primaryContainer,
      colorScheme: const ColorScheme.dark(
        primary: AptiquColors.primary,
        primaryContainer: AptiquColors.primaryContainer,
        onPrimary: AptiquColors.onPrimary,
        secondary: AptiquColors.secondary,
        secondaryContainer: AptiquColors.secondaryContainer,
        surface: AptiquColors.surface,
        onSurface: AptiquColors.onSurface,
        outline: AptiquColors.outline,
        outlineVariant: AptiquColors.outlineVariant,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AptiquColors.surfaceDim,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AptiquColors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AptiquColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AptiquColors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AptiquColors.surfaceContainer,
        hintStyle: AptiquTypography.bodyMd.copyWith(
          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        labelStyle: AptiquTypography.bodyMd.copyWith(
          color: AptiquColors.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AptiquColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AptiquColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AptiquColors.primaryContainer, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AptiquColors.surfaceContainer,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AptiquColors.outlineVariant),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AptiquColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
