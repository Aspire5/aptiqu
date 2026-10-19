import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'aptiqu_tokens.dart';
import 'aptiqu_typography.dart';

class AptiquTheme {
  AptiquTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: Color(dark ? 0xFFD0BCFF : 0xFF6D28D9),
      onPrimary: Color(dark ? 0xFF24005A : 0xFFFFFFFF),
      primaryContainer: Color(dark ? 0xFF35234E : 0xFFEDE5FF),
      onPrimaryContainer: Color(dark ? 0xFFEBDDFF : 0xFF3D176C),
      secondary: Color(dark ? 0xFF83CEDD : 0xFF166A80),
      onSecondary: Color(dark ? 0xFF00363F : 0xFFFFFFFF),
      secondaryContainer: Color(dark ? 0xFF17353D : 0xFFE3F3F6),
      onSecondaryContainer: Color(dark ? 0xFF83CEDD : 0xFF166A80),
      tertiary: Color(dark ? 0xFFEBC17B : 0xFF8C4B09),
      onTertiary: Color(dark ? 0xFF3D2D16 : 0xFFFFFFFF),
      tertiaryContainer: Color(dark ? 0xFF3D2D16 : 0xFFFFF3DD),
      onTertiaryContainer: Color(dark ? 0xFFEBC17B : 0xFF8C4B09),
      error: Color(dark ? 0xFFFFB3BB : 0xFFB42335),
      onError: Color(dark ? 0xFF421E28 : 0xFFFFFFFF),
      errorContainer: Color(dark ? 0xFF421E28 : 0xFFFDECEF),
      onErrorContainer: Color(dark ? 0xFFFFB3BB : 0xFFB42335),
      surface: Color(dark ? 0xFF171A25 : 0xFFFFFFFF),
      onSurface: Color(dark ? 0xFFE8E7F0 : 0xFF1C1D29),
      onSurfaceVariant: Color(dark ? 0xFFB4B6C8 : 0xFF5D6073),
      surfaceDim: Color(dark ? 0xFF0F111A : 0xFFF8F7FC),
      surfaceBright: Color(dark ? 0xFF303949 : 0xFFFFFFFF),
      surfaceContainerLowest: Color(dark ? 0xFF0F111A : 0xFFFFFFFF),
      surfaceContainerLow: Color(dark ? 0xFF171A25 : 0xFFFFFFFF),
      surfaceContainer: Color(dark ? 0xFF212532 : 0xFFF1EFF7),
      surfaceContainerHigh: Color(dark ? 0xFF303949 : 0xFFEAE7F2),
      surfaceContainerHighest: Color(dark ? 0xFF303949 : 0xFFEAE7F2),
      outline: Color(dark ? 0xFF85899F : 0xFF7C7F94),
      outlineVariant: Color(dark ? 0xFF363B4D : 0xFFDDD9E8),
      inverseSurface: Color(dark ? 0xFFE8E7F0 : 0xFF212532),
      onInverseSurface: Color(dark ? 0xFF1C1D29 : 0xFFE8E7F0),
      inversePrimary: Color(dark ? 0xFF6D28D9 : 0xFFD0BCFF),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final status = AptiquStatus(
      success: Color(dark ? 0xFF6DD8A9 : 0xFF08734F),
      successContainer: Color(dark ? 0xFF123A2D : 0xFFE6F5ED),
      warning: scheme.tertiary,
      warningContainer: scheme.tertiaryContainer,
      disabled: Color(dark ? 0xFF8C90A4 : 0xFF77788A),
      disabledContainer: Color(dark ? 0xFF252A38 : 0xFFEAE7F2),
    );
    final text = AptiquTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AptiquRadius.control),
    );
    final primary =
        FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          disabledForegroundColor: status.disabled,
          disabledBackgroundColor: status.disabledContainer,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: shape,
          textStyle: text.labelLarge,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: scheme.onPrimary, width: 2)
                : BorderSide.none,
          ),
        );
    final secondary = OutlinedButton.styleFrom(
      foregroundColor: scheme.onSurface,
      disabledForegroundColor: status.disabled,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: shape,
      side: BorderSide(color: scheme.outline),
      textStyle: text.labelLarge,
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceDim,
      textTheme: text,
      extensions: [status],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceDim,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: systemBars(brightness, scheme.surfaceDim),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(style: primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primary.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.all(16),
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.labelMedium!.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium!.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        modalBarrierColor: Colors.black.withValues(alpha: dark ? .6 : .4),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primaryContainer,
        selectionHandleColor: scheme.primary,
      ),
    );
  }

  static SystemUiOverlayStyle systemBars(Brightness brightness, Color page) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: page,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      );
}
