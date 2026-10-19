import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../../social/widgets/social_widgets.dart';
import '../controllers/pvp_lobby_controller.dart';

class PvpLobbyView extends StatelessWidget {
  const PvpLobbyView({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<PvpLobbyController>()
        ? Get.find<PvpLobbyController>()
        : Get.put(PvpLobbyController());
    return AppearanceTheme(
      builder: (context) => Obx(
        () => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: RefreshIndicator(
            onRefresh: c.fetchHistory,
            child: ListView(
              key: const PageStorageKey('ranked-lobby'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text('Ranked', style: context.type.titleLarge),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: context.status.warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Head-to-head practice',
                            style: context.type.titleMedium,
                          ),
                          Text(
                            '10 questions · 60 seconds each',
                            style: context.type.bodyMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (c.isOpeningMatch.value)
                  const AppStateView(
                    title: 'Match found. Opening…',
                    loading: true,
                  )
                else if (c.isInQueue.value || c.isCancelling.value)
                  SocialSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.statusMessage.value,
                            style: context.type.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${c.secondsInQueue.value}s in queue',
                          style: context.type.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        AptiquButton.outline(
                          label: c.isCancelling.value
                              ? 'Cancelling…'
                              : 'Cancel matchmaking',
                          isLoading: c.isCancelling.value,
                          onPressed: c.isCancelling.value
                              ? null
                              : c.cancelMatchmaking,
                        ),
                      ],
                    ),
                  )
                else
                  AptiquButton(
                    label: c.isReplayingMatch.value
                        ? 'Preparing replay…'
                        : 'Find match',
                    icon: const Icon(Icons.bolt_rounded),
                    isLoading: c.isReplayingMatch.value,
                    onPressed: c.isReplayingMatch.value
                        ? null
                        : c.startMatchmaking,
                  ),
                if (c.queueError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        c.queueError.value,
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Winner earns a 100 XP victory bonus. Earlier correct answers have the tie-breaker advantage.',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Match rules'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '10 questions from the live curriculum.\n60 seconds for each question.\nTap an option to submit immediately.\nThe first correct answer has the tie-breaker advantage.\nThe winner receives a 100 XP victory bonus.',
                          style: context.type.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent matches',
                        style: context.type.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh matches',
                      onPressed: c.isLoadingHistory.value
                          ? null
                          : c.fetchHistory,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                if (c.historyError.isNotEmpty)
                  SessionNotice(
                    message: c.historyError.value,
                    onRetry: c.fetchHistory,
                  ),
                if (c.isLoadingHistory.value && c.matchHistory.isEmpty)
                  const AppStateView(
                    title: 'Loading match history',
                    loading: true,
                  )
                else if (c.matchHistory.isEmpty && c.historyError.isEmpty)
                  const AppStateView(
                    title: 'No Ranked matches yet',
                    message:
                        'Your completed matches and Practice replays will appear here.',
                  )
                else ...[
                  if (c.isLoadingHistory.value) const LinearProgressIndicator(),
                  for (final match in c.matchHistory)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                match.isTie
                                    ? Icons.handshake_outlined
                                    : match.isWinner
                                    ? Icons.emoji_events_outlined
                                    : Icons.info_outline,
                                color: match.isTie
                                    ? context.status.warning
                                    : match.isWinner
                                    ? context.status.success
                                    : context.colors.onSurfaceVariant,
                              ),
                              Text(
                                match.isTie
                                    ? 'Draw'
                                    : match.isWinner
                                    ? 'Victory'
                                    : 'Defeat',
                                style: context.type.titleSmall,
                              ),
                              Text(
                                '${match.xpAwarded} XP awarded',
                                style: context.type.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              LearnerAvatar(
                                person: {
                                  'name': match.opponent.name,
                                  'avatarUrl': match.opponent.avatarUrl,
                                },
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'vs ${match.opponent.name}',
                                  style: context.type.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SessionMetrics(
                            items: [
                              (
                                label: 'You : opponent',
                                value:
                                    '${match.score} : ${match.opponentScore}',
                              ),
                              (
                                label: 'Average per question',
                                value:
                                    '${(match.avgResponseTimeMs / 1000).toStringAsFixed(1)}s',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                'Replay · No rewards',
                                style: context.type.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    c.isReplayingMatch.value ||
                                        c.isInQueue.value ||
                                        c.isOpeningMatch.value ||
                                        c.isCancelling.value
                                    ? null
                                    : () => c.replayMatchInPractice(
                                        match.matchId,
                                      ),
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Practice replay'),
                              ),
                            ],
                          ),
                        ],
                      ),
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
