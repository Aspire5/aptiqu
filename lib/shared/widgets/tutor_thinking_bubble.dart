import 'package:flutter/material.dart';
import 'indicators/app_loader.dart';

class TutorThinkingBubble extends StatelessWidget {
  final double horizontalPadding;
  final IconData avatarIcon;
  final Color? avatarBackgroundColor, avatarIconColor;
  const TutorThinkingBubble({
    super.key,
    this.horizontalPadding = 12,
    this.avatarIcon = Icons.school_rounded,
    this.avatarBackgroundColor,
    this.avatarIconColor,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarBackgroundColor ?? colors.primaryContainer,
              child: Icon(
                avatarIcon,
                size: 20,
                color: avatarIconColor ?? colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [AppLoader(size: 20), Text('Thinking…')],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
