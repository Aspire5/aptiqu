import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../social/widgets/social_widgets.dart';

/// Decorative device silhouettes sit behind actual, accessible identity/status.
/// This small header is the only arena region rebuilt by the display clock.
class PvpVersusArena extends StatelessWidget {
  const PvpVersusArena({
    super.key,
    required this.me,
    required this.opponent,
    required this.myScore,
    required this.opponentScore,
    required this.remaining,
    required this.locked,
    required this.accepted,
    required this.ended,
    required this.connected,
    this.personalRemaining,
    this.complete = false,
  });
  final Map<String, dynamic> me, opponent;
  final int myScore, opponentScore, remaining;
  final int? personalRemaining;
  final bool locked, accepted, ended, connected, complete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact =
          box.maxWidth < 350 ||
          MediaQuery.sizeOf(context).height < 600 ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      final waiting = locked && !ended && !complete;
      return RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (!compact)
                  Positioned.fill(
                    child: ExcludeSemantics(child: _Devices(waiting: waiting)),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _player(
                          context,
                          me,
                          score: myScore,
                          mine: true,
                          compact: compact,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          compact ? 18 : 30,
                          8,
                          0,
                        ),
                        child: Semantics(
                          label: 'versus',
                          child: ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AptiquRadius.control,
                                ),
                              ),
                              child: Text(
                                'VS',
                                style: context.type.labelLarge?.copyWith(
                                  color: context.colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _player(
                          context,
                          opponent,
                          score: opponentScore,
                          mine: false,
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (waiting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 220,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(AptiquRadius.control),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          accepted
                              ? Icons.lock_outline_rounded
                              : Icons.cloud_upload_outlined,
                          size: 18,
                          color: context.colors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            accepted
                                ? 'Answer locked. Waiting for round to finish…'
                                : 'Choice locked. Confirming your answer…',
                            style: context.type.bodySmall?.copyWith(
                              color: context.colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _player(
    BuildContext context,
    Map<String, dynamic> person, {
    required int score,
    required bool mine,
    required bool compact,
  }) {
    final active = !mine && locked && !ended && !complete;
    final color = mine ? context.colors.primary : context.colors.secondary;
    final status = complete
        ? 'Final score'
        : !connected
        ? 'Reconnecting'
        : ended
        ? 'Round closed'
        : mine && locked
        ? (accepted ? 'Submitted' : 'Confirming')
        : remaining <= 0
        ? 'Time ended'
        : mine
        ? 'Your time'
        : 'Round time';
    final time = complete || ended || !connected
        ? null
        : mine && locked
        ? personalRemaining == null
              ? null
              : '${personalRemaining}s at lock'
        : '${remaining}s';
    return AnimatedContainer(
      key: ValueKey(mine ? 'arena-you' : 'arena-opponent'),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(AptiquRadius.panel),
        border: Border.all(
          color: active ? color : color.withValues(alpha: .25),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LearnerAvatar(person: person, radius: compact ? 16 : 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  mine ? 'YOU' : 'RIVAL',
                  style: context.type.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${person['name'] ?? (mine ? 'You' : 'Opponent')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.type.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (person['level'] is num)
                Text(
                  'Level ${person['level']}',
                  style: context.type.labelMedium,
                ),
              Text(
                '$score pts',
                style: context.type.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: mine && locked
                  ? context.colors.primaryContainer
                  : context.colors.surface,
              borderRadius: BorderRadius.circular(AptiquRadius.chip),
            ),
            child: !locked && time != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        key: ValueKey(mine ? 'personal-clock' : 'round-clock'),
                        style: context.type.titleSmall?.copyWith(
                          color: remaining <= 10 && mine
                              ? context.colors.error
                              : color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          status,
                          style: context.type.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (time != null)
                        Text(
                          time,
                          key: ValueKey(
                            mine ? 'personal-clock' : 'round-clock',
                          ),
                          textAlign: TextAlign.center,
                          style: context.type.titleSmall?.copyWith(
                            color: mine && locked
                                ? context.colors.onPrimaryContainer
                                : remaining <= 10 && mine
                                ? context.colors.error
                                : color,
                          ),
                        ),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: context.type.labelMedium?.copyWith(
                          color: mine && locked
                              ? context.colors.onPrimaryContainer
                              : context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Devices extends StatelessWidget {
  const _Devices({required this.waiting});
  final bool waiting;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        Positioned(
          right: 10,
          top: 6,
          bottom: 12,
          width: box.maxWidth * .54,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(-.18)
              ..rotateZ(.07),
            child: _shell(context, context.colors.secondary, back: true),
          ),
        ),
        Positioned(
          left: 4,
          top: 0,
          bottom: 4,
          width: box.maxWidth * .56,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(.12)
              ..rotateZ(-.04),
            child: _shell(context, context.colors.primary),
          ),
        ),
      ],
    ),
  );
  Widget _shell(BuildContext context, Color accent, {bool back = false}) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: .22),
              context.colors.surfaceContainer,
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: .3)),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: back ? Alignment.topRight : Alignment.topCenter,
        padding: const EdgeInsets.all(7),
        child: Container(
          width: back ? 18 : 28,
          height: back ? 18 : 4,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}
