import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../../models/roadmap_model.dart';
import '../controllers/home_controller.dart';
import 'daily_challenge_streak_banner.dart';

/// Subject Selection Overlay / View on the Play Screen
/// Displays all active Subject Cards with circular progress rings,
/// sub-topic counts, estimated time, "Start / Continue Playing", and "Details".
class SubjectPlayCardsView extends StatelessWidget {
  const SubjectPlayCardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final subjects = controller.subjects;
      final isLoading = controller.isLoadingMap.value && subjects.isEmpty;

      if (isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: AptiquColors.primary),
        );
      }

      if (subjects.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded, size: 48, color: AptiquColors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No subjects available yet',
                style: AptiquTypography.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => controller.fetchActiveRoadmap(),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                label: const Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.buttonDarkBg,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AptiquColors.buttonDarkBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Senior UI/UX Daily Challenge & Streak Protection Banner
          const DailyChallengeStreakBanner(),

          // Header section
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AptiquColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AptiquColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.play_circle_filled_rounded,
                  color: AptiquColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Subject to Play',
                      style: AptiquTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose a track to start or continue playing',
                      style: AptiquTypography.bodySmall.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subject Cards
          ...subjects.map((subject) => _buildSubjectCard(context, controller, subject)),
        ],
      );
    });
  }

  Widget _buildSubjectCard(
    BuildContext context,
    HomeController controller,
    RoadmapSubjectSummary subject,
  ) {
    final progress = subject.progressPercentage;
    final isCompleted = subject.isCompleted;
    final isStarted = subject.isStarted;
    final hasPlayableContent = subject.hasPlayableContent;

    final subjectIcon = _getSubjectIcon(subject.slug);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStarted
              ? AptiquColors.primary.withValues(alpha: 0.4)
              : AptiquColors.outlineVariant,
          width: isStarted ? 1.2 : 1.0,
        ),
        boxShadow: isStarted
            ? [
                BoxShadow(
                  color: AptiquColors.primary.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Name + Status Tag
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AptiquColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AptiquColors.outlineVariant),
                  ),
                  child: Icon(subjectIcon, color: AptiquColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: AptiquTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subject.description != null && subject.description!.isNotEmpty)
                        Text(
                          subject.description!,
                          style: AptiquTypography.bodySmall.copyWith(
                            color: AptiquColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  hasPlayableContent: hasPlayableContent,
                  isStarted: isStarted,
                  isCompleted: isCompleted,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Middle Section: Progress Ring + Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AptiquColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  // Progress Ring Indicator
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: hasPlayableContent ? progress : 0.0,
                          strokeWidth: 4.5,
                          backgroundColor: AptiquColors.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted
                                ? AptiquColors.secondary
                                : (hasPlayableContent ? AptiquColors.primary : Colors.grey),
                          ),
                        ),
                        Text(
                          hasPlayableContent ? '${(progress * 100).toInt()}%' : '--',
                          style: AptiquTypography.labelCapsBold.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Sub-topic count & Estimated Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.layers_rounded,
                              size: 14,
                              color: AptiquColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              subject.totalSubtopics > 0
                                  ? '${subject.completedSubtopics} / ${subject.totalSubtopics} Sub-topics'
                                  : (subject.totalTopics > 0
                                      ? '${subject.completedTopics} / ${subject.totalTopics} Topics'
                                      : 'Topics Available'),
                              style: AptiquTypography.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AptiquColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${subject.estimatedMinutes} mins to complete',
                              style: AptiquTypography.bodySmall.copyWith(
                                color: AptiquColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions: Play (Start / Continue / Coming Soon) + Details
            Row(
              children: [
                // Primary Action Button: Start Playing / Continue Playing / Coming Soon
                Expanded(
                  child: hasPlayableContent
                      ? ElevatedButton.icon(
                          onPressed: () => controller.playSubject(subject),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                          label: Text(
                            isStarted ? 'Continue Playing' : 'Start Playing',
                            style: AptiquTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AptiquColors.buttonDarkBg,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isStarted
                                    ? AptiquColors.secondary.withValues(alpha: 0.5)
                                    : AptiquColors.primary.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            elevation: 0,
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Topics for "${subject.name}" are coming soon!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AptiquColors.surfaceContainer,
                              ),
                            );
                          },
                          icon: const Icon(Icons.hourglass_top_rounded, size: 16, color: AptiquColors.onSurfaceDisabled),
                          label: Text(
                            'Coming Soon',
                            style: AptiquTypography.labelLarge.copyWith(
                              color: AptiquColors.onSurfaceDisabled,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF131722),
                            side: const BorderSide(color: AptiquColors.outlineVariant),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),

                // Secondary Action Button: Details
                OutlinedButton.icon(
                  onPressed: () => controller.viewSubjectDetails(subject),
                  icon: const Icon(Icons.hub_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Details',
                    style: AptiquTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF131722),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AptiquColors.outlineVariant, width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool hasPlayableContent,
    required bool isStarted,
    required bool isCompleted,
  }) {
    if (!hasPlayableContent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AptiquColors.outlineVariant),
        ),
        child: Text(
          'COMING SOON',
          style: AptiquTypography.labelCapsBold.copyWith(
            color: AptiquColors.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Text(
          'COMPLETED',
          style: AptiquTypography.labelCapsBold.copyWith(
            color: const Color(0xFF10B981),
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (isStarted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AptiquColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AptiquColors.secondary.withValues(alpha: 0.4)),
        ),
        child: Text(
          'IN PROGRESS',
          style: AptiquTypography.labelCapsBold.copyWith(
            color: AptiquColors.secondary,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AptiquColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AptiquColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        'READY',
        style: AptiquTypography.labelCapsBold.copyWith(
          color: AptiquColors.primary,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getSubjectIcon(String slug) {
    final lower = slug.toLowerCase();
    if (lower.contains('quant') || lower.contains('math') || lower.contains('num')) {
      return Icons.calculate_rounded;
    } else if (lower.contains('logic') || lower.contains('reason')) {
      return Icons.psychology_rounded;
    } else if (lower.contains('verb') || lower.contains('english') || lower.contains('lang')) {
      return Icons.translate_rounded;
    } else if (lower.contains('data') || lower.contains('di')) {
      return Icons.insights_rounded;
    }
    return Icons.auto_stories_rounded;
  }
}
