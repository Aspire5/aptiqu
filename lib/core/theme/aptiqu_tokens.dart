import 'package:flutter/material.dart';

/// Shared dimensions for all application surfaces.
abstract final class AptiquSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static double gutter(double width) => width < 390 ? lg : 20;
}

abstract final class AptiquRadius {
  static const double chip = 8, control = 12, panel = 16, sheet = 24;
}

@immutable
class AptiquStatus extends ThemeExtension<AptiquStatus> {
  final Color success, successContainer, warning, warningContainer;
  final Color disabled, disabledContainer;
  const AptiquStatus({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.disabled,
    required this.disabledContainer,
  });

  @override
  AptiquStatus copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? disabled,
    Color? disabledContainer,
  }) => AptiquStatus(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    disabled: disabled ?? this.disabled,
    disabledContainer: disabledContainer ?? this.disabledContainer,
  );

  @override
  AptiquStatus lerp(covariant AptiquStatus? other, double t) {
    if (other == null) return this;
    return AptiquStatus(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      disabledContainer: Color.lerp(
        disabledContainer,
        other.disabledContainer,
        t,
      )!,
    );
  }
}

extension AptiquThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get type => Theme.of(this).textTheme;
  AptiquStatus get status =>
      Theme.of(this).extension<AptiquStatus>() ??
      AptiquStatus(
        success: colors.secondary,
        successContainer: colors.secondaryContainer,
        warning: colors.tertiary,
        warningContainer: colors.tertiaryContainer,
        disabled: colors.onSurfaceVariant,
        disabledContainer: colors.surfaceContainerHigh,
      );
}
