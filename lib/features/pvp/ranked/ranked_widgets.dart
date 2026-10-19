import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import 'ranked_models.dart';

class RankedBadge extends StatelessWidget {
  final RankedLeague league;
  final double size;
  final bool decorative;
  const RankedBadge({
    super.key,
    required this.league,
    this.size = 48,
    this.decorative = false,
  });
  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      1,
      1254,
    );
    return Semantics(
      label: decorative ? null : '${league.label} league',
      excludeSemantics: true,
      child: Image.asset(
        league.asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: pixels,
        cacheHeight: pixels,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.shield_outlined),
        ),
      ),
    );
  }
}

class RankedStandingView extends StatelessWidget {
  final RankedSummary summary;
  final bool compact, showStats;
  const RankedStandingView({
    super.key,
    required this.summary,
    this.compact = false,
    this.showStats = true,
  });
  @override
  Widget build(BuildContext context) {
    final s = summary.standing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RankedBadge(
              league: s.league,
              size: compact ? 52 : 72,
              decorative: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.league.label, style: context.type.titleMedium),
                  Text(
                    s.qualified
                        ? '${s.rating} Elo · ${s.positionLabel}'
                        : s.placementLabel,
                    style: context.type.bodyMedium,
                  ),
                  if (!s.qualified)
                    Text(
                      '${s.remaining} ${s.remaining == 1 ? 'match' : 'matches'} to qualify',
                      style: context.type.bodySmall,
                    ),
                  if (!compact && !s.qualified && s.hasRecord)
                    Text('${s.rating} Elo${s.provisional ? ' · Provisional' : ''}', style: context.type.bodySmall),
                  if (!compact && s.qualified && s.provisional)
                    Text('Provisional rating', style: context.type.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          summary.season.label,
          style: context.type.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (summary.seedPending)
          Text(
            'Previous result pending · seed may change',
            style: context.type.bodySmall,
          ),
        if (s.nextLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            '${s.toNext} Elo to ${s.nextLabel}',
            style: context.type.bodySmall,
          ),
          if (s.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: s.progress!.clamp(0, 1),
                semanticsLabel: 'Progress to ${s.nextLabel}',
              ),
            ),
        ],
        if (!compact) ...[
          const SizedBox(height: 12),
          Text(summary.season.context, style: context.type.bodySmall),
          const SizedBox(height: 12),
          if (showStats)
            SessionMetrics(
              items: [
                (label: 'Wins', value: '${s.wins}'),
                (label: 'Losses', value: '${s.losses}'),
                (label: 'Draws', value: '${s.draws}'),
                (
                  label: 'Season peak',
                  value: s.peakRating == null
                      ? 'Not qualified yet'
                      : '${s.peakRating} Elo',
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Additive Home/Profile section: absent/disabled data never becomes a fake tier.
class RankedSectionView extends StatelessWidget {
  final RankedSection? section;
  final VoidCallback onOpen;
  final VoidCallback? onHistory, onRetry;
  final String openLabel;
  final bool expanded;
  const RankedSectionView({
    super.key,
    this.section,
    required this.onOpen,
    this.onHistory,
    this.onRetry,
    this.openLabel = 'Open Ranked',
    this.expanded = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (section?.summary case final RankedSummary summary)
        RankedStandingView(summary: summary, compact: !expanded)
      else
        Text(
          section?.status == 'UNAVAILABLE'
              ? 'Ranked standing unavailable'
              : section?.status == 'DISABLED'
              ? 'Leagues are not available yet'
              : 'Play head-to-head in Ranked',
          style: context.type.bodyMedium,
        ),
      Wrap(
        spacing: 12,
        children: [
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(openLabel),
          ),
          if (onHistory != null)
            TextButton(
              onPressed: onHistory,
              child: const Text('Season history'),
            ),
          if (section?.status == 'UNAVAILABLE' && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry standing')),
        ],
      ),
    ],
  );
}
