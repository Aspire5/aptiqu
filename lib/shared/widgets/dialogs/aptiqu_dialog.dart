import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../buttons/aptiqu_button.dart';

/// Reusable Glassmorphism Cyber Dialog
class AptiquDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget? content;
  final IconData icon;
  final Color iconColor;
  final String positiveLabel;
  final VoidCallback onPositive;
  final String? negativeLabel;
  final VoidCallback? onNegative;

  const AptiquDialog({
    super.key,
    required this.title,
    required this.message,
    this.content,
    this.icon = Icons.info_outline_rounded,
    this.iconColor = AptiquColors.secondary,
    this.positiveLabel = 'Confirm',
    required this.onPositive,
    this.negativeLabel,
    this.onNegative,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    Widget? content,
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = AptiquColors.secondary,
    String positiveLabel = 'Confirm',
    required VoidCallback onPositive,
    String? negativeLabel,
    VoidCallback? onNegative,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AptiquDialog(
        title: title,
        message: message,
        content: content,
        icon: icon,
        iconColor: iconColor,
        positiveLabel: positiveLabel,
        onPositive: onPositive,
        negativeLabel: negativeLabel,
        onNegative: onNegative,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AptiquColors.surfaceContainer.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AptiquColors.outlineVariant,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: iconColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Glowing Icon Pill
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AptiquTypography.headlineSm.copyWith(
                    color: AptiquColors.onSurface,
                  ),
                ),
                const SizedBox(height: 10),

                // Body Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AptiquTypography.bodyMd.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                  ),
                ),

                if (content != null) ...[
                  const SizedBox(height: 16),
                  content!,
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    if (negativeLabel != null) ...[
                      Expanded(
                        child: AptiquButton.outline(
                          label: negativeLabel!,
                          onPressed: onNegative ?? () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: AptiquButton(
                        label: positiveLabel,
                        onPressed: onPositive,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
