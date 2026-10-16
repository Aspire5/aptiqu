import 'package:flutter/material.dart';

import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import 'learner_performance_card.dart';
import 'social_profile_chrome.dart';
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
    padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
    child: Text(title, style: AptiquTypography.headlineSm),
  );

  @override
  Widget build(BuildContext context) {
    final badges = person['badges'] as List;
    final ranked = person['ranked'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialSurface(
          highlighted: true,
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SocialIdentityHeader(person: person, profile: true),
              const SizedBox(height: 22),
              Align(alignment: Alignment.centerLeft, child: actions),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LearnerStats(person: person),
        heading('Performance'),
        LearnerPerformanceCard(person: person),
        heading('Achievements'),
        if (badges.isEmpty)
          SocialSurface(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const SocialIconPanel(
                  icon: Icons.emoji_events_outlined,
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Achievements will appear as this learner makes progress.',
                    style: AptiquTypography.bodySm.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SocialSurface(
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SocialIconPanel(
                    icon: badge['unlocked'] == true
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline_rounded,
                    size: 40,
                    color: badge['unlocked'] == true
                        ? AptiquColors.tertiary
                        : AptiquColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge['title'],
                          style: AptiquTypography.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          badge['description'],
                          style: AptiquTypography.bodySm.copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 8),
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
        if (ranked != null) ...[
          heading('Latest ranked match'),
          SocialSurface(
            radius: 20,
            child: Row(
              children: [
                const SocialIconPanel(
                  icon: Icons.emoji_events_outlined,
                  color: AptiquColors.tertiary,
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${ranked['result']} · ${ranked['correct']} correct',
                    style: AptiquTypography.bodyMd,
                  ),
                ),
              ],
            ),
          ),
        ],
        heading('Learning activity'),
        Text('Scroll through the months', style: AptiquTypography.bodySm),
        const SizedBox(height: 12),
        SocialSurface(radius: 20, child: activity),
      ],
    );
  }
}

class _LearnerStats extends StatelessWidget {
  final Map<String, dynamic> person;
  const _LearnerStats({required this.person});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(12) > 16;
      final stats = [
        (
          '${person['currentStreak']} days',
          'Current streak',
          Icons.local_fire_department_rounded,
          AptiquColors.tertiary,
        ),
        (
          '${person['highestStreak']} days',
          'Best streak',
          Icons.bolt_rounded,
          AptiquColors.secondary,
        ),
        (
          '${person['coins']}',
          'Coins',
          Icons.toll_rounded,
          AptiquColors.tertiary,
        ),
      ];
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final stat in stats)
            SizedBox(
              width: large
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3,
              child: SocialSurface(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: large
                    ? Row(
                        children: [
                          SocialIconPanel(icon: stat.$3, color: stat.$4),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stat.$2,
                              style: AptiquTypography.bodySm,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              stat.$1,
                              style: AptiquTypography.headlineSm,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SocialIconPanel(icon: stat.$3, color: stat.$4),
                          const SizedBox(height: 12),
                          Text(
                            stat.$1,
                            style: AptiquTypography.headlineSm.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stat.$2,
                            style: AptiquTypography.bodySm.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      );
    },
  );
}
