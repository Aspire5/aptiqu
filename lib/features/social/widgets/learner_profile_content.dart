import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
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
  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(title, style: context.type.titleMedium),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final badges = person['badges'] as List? ?? [];
    final ranked = person['ranked'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SocialIdentityHeader(person: person, profile: true),
              const SizedBox(height: 20),
              actions,
            ],
          ),
        ),
        const SizedBox(height: 16),
        SocialSurface(
          child: SessionMetrics(
            items: [
              (
                label: 'Current streak',
                value: person['currentStreak'] == null
                    ? 'Unavailable'
                    : '${person['currentStreak']} days',
              ),
              (
                label: 'Best streak',
                value: person['highestStreak'] == null
                    ? 'Unavailable'
                    : '${person['highestStreak']} days',
              ),
              (
                label: 'Coins',
                value: person['coins']?.toString() ?? 'Unavailable',
              ),
            ],
          ),
        ),
        _heading(context, 'Performance'),
        LearnerPerformanceCard(person: person),
        _heading(context, 'Achievements'),
        if (badges.isEmpty)
          Text(
            'Achievements will appear as this learner makes progress.',
            style: context.type.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  badge['unlocked'] == true
                      ? Icons.workspace_premium_outlined
                      : Icons.lock_outline_rounded,
                  color: badge['unlocked'] == true
                      ? context.status.warning
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge['title'], style: context.type.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        badge['description'],
                        style: context.type.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge['unlocked'] == true
                            ? 'Earned'
                            : '${badge['progress']} / ${badge['target']}',
                        style: context.type.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (ranked != null) ...[
          _heading(context, 'Latest ranked match'),
          Text(
            '${ranked['result']} · ${ranked['correct']} correct',
            style: context.type.bodyLarge,
          ),
        ],
        _heading(context, 'Learning activity'),
        SocialSurface(child: activity),
      ],
    );
  }
}
