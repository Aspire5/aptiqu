import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../models/lesson_node_model.dart';
import '../../models/lesson_session_model.dart';

class CompletionNodeWidget extends StatefulWidget {
  final LessonNodeModel node;
  final NextLearningStepModel? next;
  const CompletionNodeWidget({super.key, required this.node, this.next});
  @override
  State<CompletionNodeWidget> createState() => _CompletionNodeWidgetState();
}

class _CompletionNodeWidgetState extends State<CompletionNodeWidget> {
  bool _opening = false, _returning = false;
  Future<void> _next() async {
    final next = widget.next;
    if (_opening || next == null) return;
    setState(() => _opening = true);
    try {
      if (next.roadmapStepId != null) {
        await context.push('/lesson-step/${next.roadmapStepId}');
      } else if (next.scriptSlug != null) {
        await context.push('/lesson/${next.scriptSlug}');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.task_alt_rounded, size: 40, color: context.status.success),
        const SizedBox(height: 16),
        Text(
          'Lesson complete',
          style: context.type.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(widget.node.text, style: context.type.bodyLarge),
        if (next != null) ...[
          const SizedBox(height: 24),
          if (next.available &&
              (next.roadmapStepId != null || next.scriptSlug != null)) ...[
            Text('Next lesson', style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(
              next.scriptTitle ?? next.topicName ?? 'Next lesson',
              style: context.type.bodyLarge,
            ),
            const SizedBox(height: 16),
            AptiquButton(
              label: _opening
                  ? 'Opening next lesson…'
                  : 'Continue to next lesson',
              isLoading: _opening,
              onPressed: _opening ? null : _next,
            ),
          ] else if (next.reason == 'SCRIPT_NOT_PUBLISHED') ...[
            Text('Coming soon', style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${next.topicName ?? 'The next lesson'} is not available yet.',
              style: context.type.bodyLarge,
            ),
          ] else if (next.type == 'roadmap_complete') ...[
            Text('Roadmap complete', style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(
              'You have completed all available topics in this roadmap.',
              style: context.type.bodyLarge,
            ),
          ],
        ],
        const SizedBox(height: 24),
        AptiquButton.outline(
          label: 'Return to Home',
          onPressed: _opening || _returning
              ? null
              : () {
                  _returning = true;
                  context.go('/');
                },
        ),
      ],
    );
  }
}
