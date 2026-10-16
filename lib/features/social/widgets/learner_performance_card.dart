import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import 'social_profile_chrome.dart';
import 'social_widgets.dart';

class LearnerPerformanceCard extends StatelessWidget {
  final Map<String, dynamic> person;
  const LearnerPerformanceCard({super.key, required this.person});

  Widget figure(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: AptiquTypography.displayHero.copyWith(
          color: color,
          fontSize: 28,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: AptiquTypography.bodySm),
    ],
  );

  Widget status(IconData icon, String text) => Row(
    children: [
      SocialIconPanel(icon: icon, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: AptiquTypography.bodySm.copyWith(height: 1.5)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final performance = Map<String, dynamic>.from(person['performance']);
    final accuracy = performance['accuracy'] as num?;
    final time = performance['averageSolveTimeMs'] as num?;
    return SocialSurface(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: figure(
                  accuracy == null ? 'N/A' : '${(accuracy * 100).round()}%',
                  'Accuracy',
                  AptiquColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: figure(
                  '${performance['correct']} / ${performance['attempted']}',
                  'Correct answers',
                  AptiquColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          status(
            Icons.timer_outlined,
            time == null
                ? 'No timed results yet'
                : '${(time / 1000).toStringAsFixed(1)} sec · average correct answer',
          ),
          if (accuracy == null) ...[
            const SizedBox(height: 12),
            status(Icons.track_changes_rounded, 'No accuracy results yet'),
          ],
          if ((person['difficulty'] as List).isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final row in person['difficulty'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _label(row['difficulty']),
                            style: AptiquTypography.bodySm,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${row['correct']} / ${row['attempted']} correct',
                            style: AptiquTypography.bodySm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: row['attempted'] == 0
                            ? 0
                            : (row['correct'] / row['attempted']).toDouble(),
                        color: AptiquColors.primaryContainer,
                        backgroundColor: AptiquColors.surfaceContainerHigh,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _label(Object? difficulty) {
    final text = '$difficulty'.toLowerCase();
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
