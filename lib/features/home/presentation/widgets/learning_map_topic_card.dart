import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/roadmap_model.dart';

class LearningMapTopicCard extends StatelessWidget {
  final LearningMapTopicItemModel topic;
  final VoidCallback onTap;

  const LearningMapTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = topic.isAvailable;
    final isInProgress = topic.isInProgress;
    final isCompleted = topic.isCompleted;
    final isComingSoon = topic.isComingSoon;
    final isLocked = topic.isLocked;

    // Card border and shadow styling based on state
    Color borderColor;
    List<BoxShadow>? cardGlow;

    if (isInProgress) {
      borderColor = AptiquColors.secondary;
      cardGlow = [
        BoxShadow(
          color: AptiquColors.secondary.withValues(alpha: 0.25),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    } else if (isAvailable) {
      borderColor = AptiquColors.primary;
      cardGlow = AptiquColors.primaryGlow;
    } else if (isCompleted) {
      borderColor = Colors.greenAccent.withValues(alpha: 0.6);
    } else {
      borderColor = AptiquColors.outlineVariant.withValues(alpha: 0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isInProgress
            ? AptiquColors.surfaceContainerHigh
            : AptiquColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: (isInProgress || isAvailable) ? 1.5 : 1.0),
        boxShadow: cardGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Step Index + Importance + State Badge
                Row(
                  children: [
                    // Step Number Circle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStepIndexBg(topic.state),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP ${topic.sequence.toString().padLeft(2, '0')}',
                        style: AptiquTypography.labelCapsBold.copyWith(
                          color: _getStepIndexTextColor(topic.state),
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Importance Badge
                    _buildImportanceBadge(topic.importance),

                    const Spacer(),

                    // Authoritative State Badge
                    _buildStateBadge(topic.state),
                  ],
                ),
                const SizedBox(height: 10),

                // Topic Title
                Text(
                  topic.topicName,
                  style: AptiquTypography.headlineSm.copyWith(
                    color: (isComingSoon || isLocked)
                        ? Colors.white.withValues(alpha: 0.65)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                if (topic.description != null && topic.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    topic.description!,
                    style: AptiquTypography.bodySm.copyWith(
                      color: AptiquColors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Meta row: Estimated Time & Depth
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 13,
                      color: AptiquColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${topic.teachingMinutes} min guided',
                      style: AptiquTypography.labelCaps.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.insights_outlined,
                      size: 13,
                      color: AptiquColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Depth ${topic.teachingDepth}/5',
                      style: AptiquTypography.labelCaps.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),

                    // Interactive Action Link / Pill
                    _buildActionLabel(topic.state),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportanceBadge(String importance) {
    Color bg;
    Color fg;
    String label;

    switch (importance.toLowerCase()) {
      case 'very_important':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amberAccent;
        label = 'VERY IMPORTANT';
        break;
      case 'important':
        bg = Colors.blueAccent.withValues(alpha: 0.15);
        fg = Colors.lightBlueAccent;
        label = 'IMPORTANT';
        break;
      default:
        bg = AptiquColors.surfaceContainerHighest;
        fg = AptiquColors.onSurfaceVariant;
        label = 'CORE TOPIC';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AptiquTypography.labelCapsBold.copyWith(
          color: fg,
          fontSize: 8.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    switch (state) {
      case 'COMPLETED':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 12),
              const SizedBox(width: 4),
              Text(
                'COMPLETED',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: Colors.greenAccent,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );

      case 'IN_PROGRESS':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AptiquColors.secondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AptiquColors.secondary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: AptiquColors.secondary, size: 12),
              const SizedBox(width: 4),
              Text(
                'IN PROGRESS',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.secondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );

      case 'AVAILABLE':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AptiquColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AptiquColors.primary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: AptiquColors.primary, size: 12),
              const SizedBox(width: 4),
              Text(
                'AVAILABLE',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.primary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );

      case 'COMING_SOON':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AptiquColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AptiquColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, color: AptiquColors.onSurfaceVariant, size: 11),
              const SizedBox(width: 4),
              Text(
                'COMING SOON',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );

      case 'LOCKED':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AptiquColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AptiquColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: AptiquColors.onSurfaceVariant, size: 11),
              const SizedBox(width: 4),
              Text(
                'LOCKED',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActionLabel(String state) {
    if (state == 'IN_PROGRESS') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Resume Lesson',
            style: AptiquTypography.labelCapsBold.copyWith(
              color: AptiquColors.secondary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 12, color: AptiquColors.secondary),
        ],
      );
    } else if (state == 'AVAILABLE') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Start Lesson',
            style: AptiquTypography.labelCapsBold.copyWith(
              color: AptiquColors.primary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 12, color: AptiquColors.primary),
        ],
      );
    } else if (state == 'COMPLETED') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Review',
            style: AptiquTypography.labelCapsBold.copyWith(
              color: Colors.greenAccent,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.replay, size: 12, color: Colors.greenAccent),
        ],
      );
    } else if (state == 'COMING_SOON') {
      return Text(
        'Script In Production',
        style: AptiquTypography.labelCaps.copyWith(
          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 10,
        ),
      );
    } else {
      return Text(
        'Unlock Earlier Topics',
        style: AptiquTypography.labelCaps.copyWith(
          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 10,
        ),
      );
    }
  }

  Color _getStepIndexBg(String state) {
    if (state == 'IN_PROGRESS') return AptiquColors.secondary.withValues(alpha: 0.2);
    if (state == 'AVAILABLE') return AptiquColors.primary.withValues(alpha: 0.2);
    if (state == 'COMPLETED') return Colors.greenAccent.withValues(alpha: 0.2);
    return AptiquColors.surfaceContainerHighest;
  }

  Color _getStepIndexTextColor(String state) {
    if (state == 'IN_PROGRESS') return AptiquColors.secondary;
    if (state == 'AVAILABLE') return AptiquColors.primary;
    if (state == 'COMPLETED') return Colors.greenAccent;
    return AptiquColors.onSurfaceVariant;
  }
}
