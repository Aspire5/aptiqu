import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/questions/question_presentation.dart';
import '../../models/lesson_node_model.dart';

class QuestionNodeWidget extends StatefulWidget {
  final LessonNodeModel node;
  final Function(String answerId, String displayText, int responseTimeMs)
  onAnswerSubmitted;
  final VoidCallback onDoubt;
  final bool isSubmitting;
  final bool canRetry;
  const QuestionNodeWidget({
    super.key,
    required this.node,
    required this.onAnswerSubmitted,
    required this.onDoubt,
    this.isSubmitting = false,
    this.canRetry = false,
  });
  @override
  State<QuestionNodeWidget> createState() => _QuestionNodeWidgetState();
}

class _QuestionNodeWidgetState extends State<QuestionNodeWidget> {
  final _stopwatch = Stopwatch()..start();
  String? _selected;
  bool _waiting = false;
  @override
  void didUpdateWidget(covariant QuestionNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canRetry || oldWidget.isSubmitting && !widget.isSubmitting) {
      _waiting = false;
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inline = widget.node.inlineQuestion;
    final options = inline?.options ?? widget.node.choiceOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inline != null) ...[
          QuestionMetadata(difficulty: inline.difficulty, source: inline.pyq),
          const SizedBox(height: 16),
          if (inline.prompt.isNotEmpty &&
              inline.prompt.trim() != widget.node.text.trim()) ...[
            Text(inline.prompt, style: context.type.bodyLarge),
            const SizedBox(height: 16),
          ],
        ],
        Text(
          'Tap an option to submit your answer.',
          style: context.type.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (options.isEmpty)
          const Text('No answer options are available for this step.'),
        for (var i = 0; i < options.length; i++)
          AnswerOption(
            id: i < 26 ? String.fromCharCode(65 + i) : '${i + 1}',
            text: options[i].label,
            selected: _selected == options[i].id,
            onPressed: widget.isSubmitting || _waiting
                ? null
                : () {
                    setState(() {
                      _selected = options[i].id;
                      _waiting = true;
                    });
                    _stopwatch.stop();
                    widget.onAnswerSubmitted(
                      options[i].id,
                      options[i].label,
                      _stopwatch.elapsedMilliseconds,
                    );
                  },
          ),
      ],
    );
  }
}
