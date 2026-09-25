import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../controllers/lesson_feed_controller.dart';
import '../../models/lesson_node_model.dart';
import '../../models/lesson_session_model.dart';

class CompletionNodeWidget extends StatelessWidget {
  final LessonNodeModel node;

  const CompletionNodeWidget({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    LessonFeedController? controller;
    try {
      controller = Get.find<LessonFeedController>();
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.primaryContainer),
        boxShadow: AptiquColors.primaryGlow,
      ),
      child: Obx(() {
        final next = controller?.nextStep.value;

        return Column(
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
            const SizedBox(height: 20),

            // Roadmap progression banner
            if (next != null) _buildProgressionSection(context, next, controller!),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AptiquColors.onSurfaceVariant,
                  side: BorderSide(color: AptiquColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  context.go('/');
                },
                child: Text(
                  'Back to Learning Map',
                  style: AptiquTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressionSection(
    BuildContext context,
    NextLearningStepModel next,
    LessonFeedController controller,
  ) {
    if (next.available && (next.scriptSlug != null || next.roadmapStepId != null)) {
      final nextTitle = next.scriptTitle ?? next.topicName ?? 'Next Lesson';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AptiquColors.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AptiquColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AptiquColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'NEXT IN ROADMAP',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: AptiquColors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nextTitle,
              style: AptiquTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.primary,
                  foregroundColor: AptiquColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (next.roadmapStepId != null) {
                    context.push('/lesson-step/${next.roadmapStepId}');
                  } else if (next.scriptSlug != null) {
                    context.push('/lesson/${next.scriptSlug}');
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue to Next Lesson', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (next.reason == 'SCRIPT_NOT_PUBLISHED') {
      final nextTopic = next.topicName ?? 'Next Topic';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AptiquColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_empty, color: AptiquColors.secondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'UP NEXT • COMING SOON',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: AptiquColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nextTopic,
              style: AptiquTypography.bodyLg.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You have completed this step! The interactive lesson script for "$nextTopic" is being crafted and will be available soon.',
              style: AptiquTypography.bodySm.copyWith(
                color: AptiquColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (next.type == 'roadmap_complete') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AptiquColors.tertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AptiquColors.tertiary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.military_tech, color: AptiquColors.tertiary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROADMAP COMPLETED',
                    style: AptiquTypography.labelCapsBold.copyWith(
                      color: AptiquColors.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Congratulations! You have completed all available topics in this roadmap track.',
                    style: AptiquTypography.bodySm.copyWith(
                      color: AptiquColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
