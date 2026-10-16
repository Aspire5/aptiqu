import 'package:flutter/material.dart';

import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import 'social_widgets.dart';

class LearnerProfileContent extends StatelessWidget {
  final Map<String, dynamic> person;
  final Widget actions, activity;
  const LearnerProfileContent({
    super.key,
    required this.person,
    required this.actions,
    required this.activity,
  });

  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(title, style: AptiquTypography.headlineSm),
  );

  Widget metric(String value, String label, IconData icon, Color color) =>
      SocialSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(value, style: AptiquTypography.headlineMd),
            const SizedBox(height: 4),
            Text(label, style: AptiquTypography.bodySm),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = person;
    final performance = Map<String, dynamic>.from(p['performance']);
    final accuracy = performance['accuracy'] as num?;
    final time = performance['averageSolveTimeMs'] as num?;
    final badges = p['badges'] as List;
    final ranked = p['ranked'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LearnerAvatar(person: p, radius: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'], style: AptiquTypography.headlineMd),
                        const SizedBox(height: 6),
                        Text(
                          'Level ${p['level']} · ${p['totalXp']} XP',
                          style: AptiquTypography.bodyMd.copyWith(
                            color: AptiquColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['online'] == true
                              ? 'Online now'
                              : p['online'] == false
                              ? 'Offline'
                              : 'Status unavailable',
                          style: AptiquTypography.bodySm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              actions,
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in [
                (
                  '${p['currentStreak']} days',
                  'Current streak',
                  Icons.local_fire_department_rounded,
                  AptiquColors.tertiary,
                ),
                (
                  '${p['highestStreak']} days',
                  'Best streak',
                  Icons.bolt_rounded,
                  AptiquColors.secondary,
                ),
                (
                  '${p['coins']}',
                  'Coins',
                  Icons.toll_rounded,
                  AptiquColors.tertiary,
                ),
              ])
                SizedBox(
                  width: (constraints.maxWidth - 20) / 3,
                  child: metric(entry.$1, entry.$2, entry.$3, entry.$4),
                ),
            ],
          ),
        ),
        heading('Performance'),
        SocialSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accuracy == null
                              ? 'N/A'
                              : '${(accuracy * 100).round()}%',
                          style: AptiquTypography.displayHero.copyWith(
                            color: AptiquColors.secondary,
                          ),
                        ),
                        Text('Accuracy', style: AptiquTypography.bodySm),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${performance['correct']} / ${performance['attempted']}',
                          style: AptiquTypography.headlineMd,
                        ),
                        Text('Correct answers', style: AptiquTypography.bodySm),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: AptiquColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      time == null
                          ? 'No timed results yet'
                          : '${(time / 1000).toStringAsFixed(1)} sec · average correct answer',
                      style: AptiquTypography.bodySm,
                    ),
                  ),
                ],
              ),
              if (accuracy == null) ...[
                const SizedBox(height: 8),
                Text('No accuracy results yet', style: AptiquTypography.bodySm),
              ],
              if ((p['difficulty'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                for (final row in p['difficulty'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${row['difficulty']}'
                                    .toLowerCase()
                                    .capitalizeLabel(),
                                style: AptiquTypography.bodySm,
                              ),
                            ),
                            Text(
                              '${row['correct']} / ${row['attempted']} correct',
                              style: AptiquTypography.bodySm,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: row['attempted'] == 0
                                ? 0
                                : (row['correct'] / row['attempted'])
                                      .toDouble(),
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
        ),
        heading('Achievements'),
        if (badges.isEmpty)
          SocialSurface(
            child: Text(
              'Achievements will appear as this learner makes progress.',
              style: AptiquTypography.bodySm,
            ),
          ),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SocialSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    badge['unlocked'] == true
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    size: 26,
                    color: badge['unlocked'] == true
                        ? AptiquColors.tertiary
                        : AptiquColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge['title'],
                          style: AptiquTypography.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['description'],
                          style: AptiquTypography.bodySm,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['unlocked'] == true
                              ? 'Earned'
                              : '${badge['progress']} / ${badge['target']}',
                          style: AptiquTypography.bodySm.copyWith(
                            color: AptiquColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        heading('Latest ranked match'),
        SocialSurface(
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AptiquColors.tertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ranked == null
                      ? 'No completed ranked matches yet'
                      : '${ranked['result']} · ${ranked['correct']} correct',
                  style: AptiquTypography.bodyMd,
                ),
              ),
            ],
          ),
        ),
        heading('Learning activity'),
        Text('Scroll through the months', style: AptiquTypography.bodySm),
        const SizedBox(height: 12),
        SocialSurface(child: activity),
      ],
    );
  }
}

extension on String {
  String capitalizeLabel() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
