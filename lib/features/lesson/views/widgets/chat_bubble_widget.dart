import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';

class ChatBubbleWidget extends StatelessWidget {
  final bool isUser;
  final String text;
  final String avatarPersona;

  const ChatBubbleWidget({
    super.key,
    required this.isUser,
    required this.text,
    this.avatarPersona = 'TUTOR',
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 48, right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AptiquColors.primaryDark,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: AptiquColors.cardElevation,
          ),
          child: Text(
            text,
            style: AptiquTypography.bodyLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Tutor / System Bubble
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AptiquColors.surfaceContainerHigh,
            child: Icon(
              avatarPersona == 'SYSTEM' ? Icons.info_outline : Icons.auto_awesome,
              color: AptiquColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AptiquColors.outlineVariant),
              ),
              child: Text(
                text,
                style: AptiquTypography.bodyLg.copyWith(
                  color: AptiquColors.onSurface,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
