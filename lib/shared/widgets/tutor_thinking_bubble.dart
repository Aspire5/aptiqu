import 'package:flutter/material.dart';
import '../../core/theme/aptiqu_colors.dart';
import '../../core/theme/aptiqu_typography.dart';

class TutorThinkingBubble extends StatelessWidget {
  final double horizontalPadding;
  final IconData avatarIcon;
  final Color avatarBackgroundColor;
  final Color avatarIconColor;

  const TutorThinkingBubble({
    super.key,
    this.horizontalPadding = 12,
    this.avatarIcon = Icons.school_rounded,
    this.avatarBackgroundColor = AptiquColors.surface,
    this.avatarIconColor = AptiquColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBackgroundColor,
            child: Icon(avatarIcon, size: 20, color: avatarIconColor),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainer.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AptiquColors.outlineVariant.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AptiquColors.secondary),
                ),
                const SizedBox(width: 9),
                Text('Thinking...', style: AptiquTypography.bodyMd.copyWith(
                  fontSize: 13.5,
                  color: AptiquColors.onSurfaceVariant,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
