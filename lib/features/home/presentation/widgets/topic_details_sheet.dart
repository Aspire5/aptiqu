import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/roadmap_model.dart';

/// Presentation only: the caller dismisses the sheet before launching an action.
class TopicDetailsSheet extends StatelessWidget {
  final LearningMapTopicItemModel topic;
  final ScrollController scrollController;
  final VoidCallback onPracticeTopic;
  final VoidCallback onPlayTopic;
  final ValueChanged<SubtopicItemModel> onPracticeSubtopic;
  final ValueChanged<SubtopicItemModel> onPlaySubtopic;

  const TopicDetailsSheet({
    super.key,
    required this.topic,
    required this.scrollController,
    required this.onPracticeTopic,
    required this.onPlayTopic,
    required this.onPracticeSubtopic,
    required this.onPlaySubtopic,
  });

  @override
  Widget build(BuildContext context) {
    final playable =
        topic.scriptAvailable && !topic.isLocked && !topic.isComingSoon;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOPIC ${topic.sequence.toString().padLeft(2, '0')}',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        fontSize: 11,
                        color: AptiquColors.secondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close topic details',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AptiquColors.onSurfaceVariant,
                  ),
                ],
              ),
              Text(
                topic.topicName,
                style: AptiquTypography.headlineSm.copyWith(
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${topic.completedSubtopics} of ${topic.totalSubtopics} subtopics completed',
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.secondary,
                  fontSize: 12,
                ),
              ),
              if (topic.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  topic.description!,
                  style: AptiquTypography.bodySm.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Subtopics',
                style: AptiquTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (topic.subtopics.isEmpty)
                Text(
                  'Lessons for this topic are coming soon.',
                  style: AptiquTypography.bodySm.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                  ),
                ),
              for (final subtopic in topic.subtopics) ...[
                _SubtopicCard(
                  subtopic: subtopic,
                  onPractice: () => onPracticeSubtopic(subtopic),
                  onPlay: () => onPlaySubtopic(subtopic),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (playable)
          Container(
            decoration: const BoxDecoration(
              color: AptiquColors.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: AptiquColors.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Whole topic',
                    style: AptiquTypography.bodySm.copyWith(
                      fontSize: 11,
                      color: AptiquColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TopicActionButtons(
                    key: const ValueKey('topic-actions'),
                    onPractice: onPracticeTopic,
                    onPlay: onPlayTopic,
                    playLabel: topic.isCompleted
                        ? 'Replay'
                        : topic.isInProgress
                        ? 'Continue'
                        : 'Start',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SubtopicCard extends StatelessWidget {
  final SubtopicItemModel subtopic;
  final VoidCallback onPractice;
  final VoidCallback onPlay;
  const _SubtopicCard({
    required this.subtopic,
    required this.onPractice,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final done = subtopic.isCompleted;
    return Container(
      key: ValueKey('subtopic-${subtopic.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? AptiquColors.secondary.withValues(alpha: .3)
              : AptiquColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  done ? Icons.check_circle_rounded : Icons.menu_book_outlined,
                  size: 18,
                  color: done
                      ? AptiquColors.secondary
                      : AptiquColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtopic.title,
                  style: AptiquTypography.bodyMd.copyWith(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? 'Completed'
                : subtopic.isLocked
                ? 'Coming soon'
                : 'Ready to learn',
            style: AptiquTypography.bodySm.copyWith(
              fontSize: 11,
              color: done
                  ? AptiquColors.secondary
                  : AptiquColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TopicActionButtons(
            onPractice: onPractice,
            onPlay: subtopic.isLocked ? null : onPlay,
            playLabel: done
                ? 'Replay'
                : subtopic.isLocked
                ? 'Soon'
                : 'Start',
          ),
        ],
      ),
    );
  }
}

/// All lesson and topic actions share the same widths, height and typography.
class TopicActionButtons extends StatelessWidget {
  final VoidCallback onPractice;
  final VoidCallback? onPlay;
  final String playLabel;
  const TopicActionButtons({
    super.key,
    required this.onPractice,
    required this.onPlay,
    required this.playLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = AptiquTypography.bodySm.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.2,
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      elevation: const WidgetStatePropertyAll(0),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: style.copyWith(
              foregroundColor: const WidgetStatePropertyAll(
                AptiquColors.secondary,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: AptiquColors.secondary.withValues(alpha: .5)),
              ),
            ),
            onPressed: onPractice,
            child: const Text('Practice'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: style.copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AptiquColors.onSurfaceVariant
                    : Colors.white,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AptiquColors.surfaceContainerHighest
                    : AptiquColors.primaryContainer,
              ),
            ),
            onPressed: onPlay,
            child: Text(playLabel),
          ),
        ),
      ],
    );
  }
}
