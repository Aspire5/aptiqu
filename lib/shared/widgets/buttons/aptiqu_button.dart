import 'package:flutter/material.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../indicators/aptiqu_loading_indicator.dart';

enum AptiquButtonVariant { primary, secondary, outline, google }

/// Reusable Cyber Glow Button
class AptiquButton extends StatefulWidget {
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
  })  : variant = AptiquButtonVariant.google,
        icon = null;

  @override
  State<AptiquButton> createState() => _AptiquButtonState();
}

class _AptiquButtonState extends State<AptiquButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(16);

    BoxDecoration decoration;
    TextStyle textStyle;

    switch (widget.variant) {
      case AptiquButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: AptiquColors.primaryGradient,
          borderRadius: effectiveRadius,
          boxShadow: widget.onPressed != null && !widget.isLoading
              ? [
                  BoxShadow(
                    color: AptiquColors.primaryContainer.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        textStyle = AptiquTypography.bodyMd.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: widget.fontSize ?? 13.5,
        );
        break;

      case AptiquButtonVariant.outline:
        decoration = BoxDecoration(
          color: AptiquColors.surfaceContainer,
          borderRadius: effectiveRadius,
          border: Border.all(color: AptiquColors.outlineVariant, width: 1.2),
        );
        textStyle = AptiquTypography.bodyMd.copyWith(
          color: AptiquColors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: widget.fontSize ?? 12.5,
        );
        break;

      case AptiquButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AptiquColors.secondary.withValues(alpha: 0.15),
          borderRadius: effectiveRadius,
          border: Border.all(color: AptiquColors.secondary.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: AptiquColors.secondary.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        );
        textStyle = AptiquTypography.bodyMd.copyWith(
          color: AptiquColors.secondary,
          fontWeight: FontWeight.w700,
          fontSize: widget.fontSize ?? 13.5,
        );
        break;

      case AptiquButtonVariant.google:
        decoration = BoxDecoration(
          color: AptiquColors.surfaceContainerHigh,
          borderRadius: effectiveRadius,
          border: Border.all(color: AptiquColors.outlineVariant, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
        textStyle = AptiquTypography.bodyMd.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          fontSize: widget.fontSize ?? 13.5,
        );
        break;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 14),
          decoration: decoration,
          child: Center(
            child: widget.isLoading
                ? const AptiquLoadingIndicator(size: 20)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.variant == AptiquButtonVariant.google) ...[
                        _buildGoogleIcon(),
                        const SizedBox(width: 10),
                      ] else if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15,
          fontFamily: 'sans-serif',
        ),
      ),
    );
  }
}
