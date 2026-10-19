import 'package:flutter/material.dart';
import '../indicators/app_loader.dart';

enum AptiquButtonVariant { primary, secondary, outline, google }

/// Native Material activation, focus and disabled behavior for shared actions.
class AptiquButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AptiquButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;

  const AptiquButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AptiquButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
    this.borderRadius,
    this.padding,
    this.fontSize,
  });
  const AptiquButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
    this.borderRadius,
    this.padding,
    this.fontSize,
  }) : variant = AptiquButtonVariant.outline;
  const AptiquButton.google({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.borderRadius,
    this.padding,
    this.fontSize,
  }) : variant = AptiquButtonVariant.google,
       icon = null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outlined =
        variant == AptiquButtonVariant.outline ||
        variant == AptiquButtonVariant.google;
    final primary = variant == AptiquButtonVariant.primary;
    final google = variant == AptiquButtonVariant.google;
    final foreground = primary
        ? colors.onPrimary
        : google
        ? const Color(0xFF1F1F1F)
        : outlined
        ? colors.onSurface
        : colors.onSecondaryContainer;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, height < 48 ? 48 : height)),
      padding: WidgetStatePropertyAll(
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        google
            ? const TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
              )
            : Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: fontSize ?? 14),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.onSurfaceVariant
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.surfaceContainerHigh
            : primary
            ? colors.primary
            : google
            ? Colors.white
            : outlined
            ? colors.surface
            : colors.secondaryContainer,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? (google
                    ? const Color(0xFF1F1F1F)
                    : primary
                    ? colors.onPrimary
                    : colors.primary)
              : google
              ? const Color(0xFF747775)
              : outlined
              ? colors.outline
              : Colors.transparent,
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          const AppLoader(size: 20),
          const SizedBox(width: 8),
        ] else if (variant == AptiquButtonVariant.google) ...[
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(2),
              color: Colors.white,
              child: Image.asset(
                'assets/images/google_g.png',
                width: 20,
                height: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return SizedBox(
      width: width,
      child: outlined
          ? OutlinedButton(
              style: style,
              onPressed: isLoading ? null : onPressed,
              child: child,
            )
          : FilledButton(
              style: style,
              onPressed: isLoading ? null : onPressed,
              child: child,
            ),
    );
  }
}
