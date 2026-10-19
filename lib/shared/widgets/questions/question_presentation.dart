import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';

/// Presentation only. Callers own selection, submission, timing and feedback.
class AnswerOption extends StatelessWidget {
  final String id, text;
  final bool selected, correct, incorrect;
  final VoidCallback? onPressed;
  const AnswerOption({
    super.key,
    required this.id,
    required this.text,
    required this.selected,
    required this.onPressed,
    this.correct = false,
    this.incorrect = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? context.status.success
        : incorrect
        ? context.colors.error
        : selected
        ? context.colors.onPrimaryContainer
        : context.colors.onSurface;
    final fill = correct
        ? context.status.successContainer
        : incorrect
        ? context.colors.errorContainer
        : selected
        ? context.colors.primaryContainer
        : context.colors.surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MergeSemantics(
        child: Semantics(
          selected: selected,
          label: correct
              ? 'Correct answer'
              : incorrect
              ? 'Incorrect answer'
              : null,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              disabledForegroundColor: color,
              backgroundColor: fill,
              minimumSize: const Size(double.infinity, 56),
              padding: const EdgeInsets.all(16),
              side: BorderSide(
                color: selected || correct || incorrect
                    ? color
                    : context.colors.outlineVariant,
                width: selected || correct || incorrect ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: context.type.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: context.type.bodyLarge?.copyWith(color: color),
                    textAlign: TextAlign.start,
                  ),
                ),
                if (selected || correct || incorrect) ...[
                  const SizedBox(width: 8),
                  Icon(
                    correct
                        ? Icons.check_circle_outline
                        : incorrect
                        ? Icons.cancel_outlined
                        : Icons.radio_button_checked,
                    size: 20,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestionMetadata extends StatelessWidget {
  final String difficulty;
  final String? mode, source;
  const QuestionMetadata({
    super.key,
    required this.difficulty,
    this.mode,
    this.source,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _tag(context, difficulty, Icons.signal_cellular_alt),
      if (mode != null && mode!.trim().isNotEmpty)
        _tag(context, mode!, Icons.bolt_outlined),
      if (source != null && source!.trim().isNotEmpty)
        _tag(context, source!, Icons.menu_book_outlined),
    ],
  );
  Widget _tag(BuildContext context, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                icon,
                size: 16,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          TextSpan(text: label),
        ],
      ),
      style: context.type.labelMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

class AnswerFeedback extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final bool mayBeTimeout;
  const AnswerFeedback({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    this.mayBeTimeout = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isCorrect ? Icons.check_circle_outline : Icons.info_outline,
          color: isCorrect ? context.status.success : context.colors.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCorrect
                    ? 'Correct!'
                    : mayBeTimeout
                    ? 'Incorrect or timed out'
                    : 'Incorrect',
                style: context.type.titleSmall?.copyWith(
                  color: isCorrect
                      ? context.status.success
                      : context.colors.error,
                ),
              ),
              Text(
                'Correct answer: $correctAnswer',
                style: context.type.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class QuestionSolutions extends StatelessWidget {
  final String explanation, method;
  final String? alternativeExplanation, preferredSolution, preferredReason;
  final void Function(String title, String? reason)? onPreferredReason;
  const QuestionSolutions({
    super.key,
    required this.explanation,
    required this.method,
    this.alternativeExplanation,
    this.preferredSolution,
    this.preferredReason,
    this.onPreferredReason,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _method(
        context,
        'Book method',
        explanation.trim().isEmpty
            ? 'An explanation is not available for this question.'
            : explanation,
        'BOOK',
        formula: method,
      ),
      if (alternativeExplanation?.trim().isNotEmpty ?? false) ...[
        const Divider(height: 32),
        _method(
          context,
          'Alternative method',
          alternativeExplanation!,
          'ALTERNATIVE',
        ),
      ],
      if (onPreferredReason == null &&
          (preferredReason?.trim().isNotEmpty ?? false)) ...[
        const SizedBox(height: 16),
        Text('Why this method is preferred', style: context.type.titleSmall),
        const SizedBox(height: 8),
        Text(preferredReason!, style: context.type.bodyLarge),
      ],
    ],
  );
  Widget _method(
    BuildContext context,
    String title,
    String body,
    String code, {
    String? formula,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(title, style: context.type.titleSmall),
          if (preferredSolution == code)
            onPreferredReason == null
                ? Text(
                    'AI preferred',
                    style: context.type.labelMedium?.copyWith(
                      color: context.colors.primary,
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => onPreferredReason!(title, preferredReason),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('AI preferred'),
                  ),
        ],
      ),
      if (formula?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: 8),
        Text('Method: $formula', style: context.type.bodyLarge),
      ],
      const SizedBox(height: 8),
      Text(body, style: context.type.bodyLarge),
    ],
  );
}

/// Compact metrics reflow as whole values instead of squeezing equal columns.
class SessionMetrics extends StatelessWidget {
  final List<({String label, String value})> items;
  const SessionMetrics({super.key, required this.items});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 16,
    children: [
      for (final item in items)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.value, style: context.type.titleMedium),
            Text(
              item.label,
              style: context.type.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
    ],
  );
}

/// A refresh failure stays beside the retained content without taking over it.
class SessionNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const SessionNotice({
    super.key,
    required this.message,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            message,
            style: context.type.bodyMedium?.copyWith(
              color: context.colors.error,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
