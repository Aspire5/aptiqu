import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import 'social_widgets.dart';

class LearnerPerformanceCard extends StatelessWidget {
  final Map<String, dynamic> person;
  const LearnerPerformanceCard({super.key, required this.person});
  @override
  Widget build(BuildContext context) {
    final performance = Map<String, dynamic>.from(person['performance'] ?? {});
    final accuracy = performance['accuracy'] as num?;
    final time = performance['averageSolveTimeMs'] as num?;
    return SocialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SessionMetrics(
            items: [
              (
                label: 'Accuracy',
                value: accuracy == null
                    ? 'N/A'
                    : '${(accuracy * 100).round()}%',
              ),
              (
                label: 'Correct answers',
                value:
                    performance['correct'] == null ||
                        performance['attempted'] == null
                    ? 'Unavailable'
                    : '${performance['correct']} / ${performance['attempted']}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            time == null
                ? 'No timed results yet'
                : '${(time / 1000).toStringAsFixed(1)} sec · average correct answer',
            style: context.type.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (accuracy == null) ...[
            const SizedBox(height: 8),
            Text(
              'No accuracy results yet',
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          if ((person['difficulty'] as List? ?? []).isNotEmpty) ...[
            const Divider(height: 32),
            for (final row in person['difficulty'])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          _label(row['difficulty']),
                          style: context.type.bodyMedium,
                        ),
                        Text(
                          '${row['correct']} / ${row['attempted']} correct',
                          style: context.type.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: row['attempted'] == 0
                          ? 0
                          : (row['correct'] / row['attempted'])
                                .toDouble()
                                .clamp(0.0, 1.0),
                      minHeight: 4,
                      semanticsLabel:
                          '${_label(row['difficulty'])} correct answers',
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _label(Object? value) {
    final text = '$value'.toLowerCase();
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
