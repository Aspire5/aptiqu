import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/layout/text_fit.dart';
import '../../models/roadmap_model.dart';
import '../../../../shared/widgets/sheets/app_sheet.dart';

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
    return LayoutBuilder(
      builder: (context, box) {
        // Keep a useful reading viewport when enlarged controls consume the sheet.
        final compact =
            box.maxHeight < 184 * MediaQuery.textScalerOf(context).scale(1);
        return Column(
          children: [
            AppSheetHeader(
              title: 'TOPIC ${topic.sequence.toString().padLeft(2, '0')}',
              closeLabel: 'Close topic details',
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    topic.topicName,
                    style: context.type.titleLarge!.copyWith(
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${topic.completedSubtopics} of ${topic.totalSubtopics} subtopics completed',
                    style: context.type.bodyMedium!.copyWith(
                      color: context.colors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  if (topic.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      topic.description!,
                      style: context.type.bodyMedium!.copyWith(
                        color: context.colors.onSurfaceVariant,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Subtopics',
                    style: context.type.titleSmall!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (topic.subtopics.isEmpty)
                    Text(
                      'Lessons for this topic are coming soon.',
                      style: context.type.bodyMedium!.copyWith(
                        color: context.colors.onSurfaceVariant,
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
                  if (playable && compact)
                    _topicActions(context, embedded: true),
                ],
              ),
            ),
            if (playable && !compact) _topicActions(context),
          ],
        );
      },
    );
  }

  Widget _topicActions(BuildContext context, {bool embedded = false}) =>
      Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(
          embedded ? 0 : 20,
          12,
          embedded ? 0 : 20,
          12,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Whole topic',
                style: context.type.bodyMedium!.copyWith(
                  fontSize: 12,
                  color: context.colors.onSurfaceVariant,
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
      );
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
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? context.colors.secondary.withValues(alpha: .3)
              : context.colors.outlineVariant,
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
                      ? context.colors.secondary
                      : context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtopic.title,
                  style: context.type.titleSmall!.copyWith(
                    fontSize: 16,
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
            style: context.type.bodyMedium!.copyWith(
              fontSize: 12,
              color: done
                  ? context.colors.secondary
                  : context.colors.onSurfaceVariant,
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
    final practice = OutlinedButton(
      onPressed: onPractice,
      child: const Text('Practice'),
    );
    final play = FilledButton(onPressed: onPlay, child: Text(playLabel));
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = (constraints.maxWidth - 12) / 2 - 32;
        final fits = ['Practice', playLabel].every(
          (label) =>
              textFits(context, label, context.type.labelLarge!, labelWidth),
        );
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [practice, const SizedBox(height: 12), play],
          );
        }
        return Row(
          children: [
            Expanded(child: practice),
            const SizedBox(width: 12),
            Expanded(child: play),
          ],
        );
      },
    );
  }
}
