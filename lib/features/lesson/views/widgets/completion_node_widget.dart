import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/lesson_node_model.dart';

class CompletionNodeWidget extends StatelessWidget {
  final LessonNodeModel node;

  const CompletionNodeWidget({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.primaryContainer),
        boxShadow: AptiquColors.primaryGlow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AptiquColors.primaryContainer.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: AptiquColors.tertiary,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lesson Complete!',
            style: AptiquTypography.headlineMd.copyWith(
              color: AptiquColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            node.text,
            textAlign: TextAlign.center,
            style: AptiquTypography.bodyLg.copyWith(
              color: AptiquColors.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AptiquColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.go('/');
              },
              child: Text(
                'Back to Dashboard',
                style: AptiquTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
