import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';

class ChatBubbleWidget extends StatelessWidget {
  final bool isUser;
  final String text, avatarPersona;
  const ChatBubbleWidget({
    super.key,
    required this.isUser,
    required this.text,
    this.avatarPersona = 'TUTOR',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(isUser ? 32 : 0, 0, isUser ? 0 : 16, 12),
    child: Semantics(
      label: isUser
          ? 'Your response'
          : avatarPersona == 'SYSTEM'
          ? 'Lesson information'
          : 'AptiQu tutor',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUser
              ? context.colors.primaryContainer
              : context.colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 16 : 4),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Text(
                  avatarPersona == 'SYSTEM' ? 'Lesson' : 'AptiQu',
                  style: context.type.labelMedium?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                text,
                style: context.type.bodyLarge?.copyWith(
                  color: isUser
                      ? context.colors.onPrimaryContainer
                      : context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
