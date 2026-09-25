import 'package:flutter/material.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';

/// Reusable Metric Badge formatted with ICON FIRST, then QUANTITY.
class AptiquBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AptiquBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.onTap,
  });

  /// Preset for Daily Streak (Flame Icon + Count, e.g. "12d" or "0d")
  factory AptiquBadge.streak({required String days, VoidCallback? onTap}) {
    return AptiquBadge(
      icon: Icons.local_fire_department_rounded,
      label: days,
      color: AptiquColors.tertiary,
      onTap: onTap,
    );
  }

  /// Preset for Aptitude Coins (Coins Icon + Count, e.g. "2,450" or "0")
  factory AptiquBadge.coins({required String coins, VoidCallback? onTap}) {
    return AptiquBadge(
      icon: Icons.monetization_on_rounded,
      label: coins,
      color: AptiquColors.tertiary,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? AptiquColors.surfaceContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AptiquColors.outlineVariant.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Icon FIRST
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 5),
            // 2. Quantity SECOND
            Text(
              label,
              style: AptiquTypography.metricMd.copyWith(
                color: color,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
