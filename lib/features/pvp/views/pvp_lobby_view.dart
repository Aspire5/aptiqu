import '../ranked/ranked_models.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../ranked/ranked_widgets.dart';
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
            onRefresh: c.refreshRanked,
            child: ListView(
              key: const PageStorageKey('ranked-lobby'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Ranked', style: context.type.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Leaderboard',
                      onPressed: () =>
                          context.push(AppRoutes.rankedLeaderboard),
                      icon: const Icon(Icons.leaderboard_outlined),
                    ),
                    IconButton(
                      tooltip: 'Season history',
                      onPressed: () => context.push(AppRoutes.rankedSeasons),
                      icon: const Icon(Icons.history_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (c.summary.value != null)
                  RankedStandingView(
                    summary: c.summary.value!,
                    showStats: false,
                  )
                else if (c.isLoadingStanding.value)
                  const LinearProgressIndicator()
                else
                  Text(
                    c.standingStatus.value == 'DISABLED'
                        ? 'Leagues are not available yet'
                        : '10 questions · 60 seconds each',
                    style: context.type.bodyMedium,
                  ),
                if (c.standingError.isNotEmpty)
                  SessionNotice(
                    message: c.standingError.value,
                    onRetry: c.fetchSummary,
                  ),
                const SizedBox(height: 16),
                if (c.isOpeningMatch.value)
                  const AppStateView(
                    title: 'Match found. Opening…',
                    loading: true,
                  )
                else if (c.summary.value?.activeMatchId != null)
                  AptiquButton(
                    label: c.summary.value?.recoveryState == 'RESULT_PENDING'
                        ? 'Check pending result'
                        : 'Resume match',
                    onPressed: c.resumeMatch,
                  )
                else if (c.queueUncertain.value)
                  AptiquButton.outline(
                    label: 'Check for an existing match',
                    onPressed: c.fetchSummary,
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
                        if (c.searchExpanded.value)
                          Text(
                            'Search widened to include more ratings',
                            style: context.type.bodyMedium,
                          ),
                        const SizedBox(height: 16),
                        AptiquButton.outline(
                          label: c.isPairing.value
                              ? 'Preparing match…'
                              : c.isCancelling.value
                              ? 'Cancelling…'
                              : 'Cancel matchmaking',
                          isLoading: c.isCancelling.value,
                          onPressed: c.isCancelling.value || c.isPairing.value
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
                if (c.summary.value != null &&
                    !c.summary.value!.ratedAdmission &&
                    !c.isInQueue.value)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      c.summary.value!.admissionPaused
                          ? 'Match search is paused.'
                          : 'Rated matches are not open yet.',
                      style: context.type.bodySmall,
                    ),
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
                if (c.summary.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SessionMetrics(
                      items: [
                        (
                          label: 'Wins',
                          value: '${c.summary.value!.standing.wins}',
                        ),
                        (
                          label: 'Losses',
                          value: '${c.summary.value!.standing.losses}',
                        ),
                        (
                          label: 'Draws',
                          value: '${c.summary.value!.standing.draws}',
                        ),
                        (
                          label: 'Season peak',
                          value: c.summary.value!.standing.peakRating == null
                              ? 'Not qualified yet'
                              : '${c.summary.value!.standing.peakRating} Elo',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'More correct answers wins. Equal scores use total server-timed response duration.',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                ExpansionTile(
                  key: const PageStorageKey('ranked-match-rules'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Match rules'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '10 questions from the live curriculum.\n60 seconds for each question.\nTap an option to submit immediately.\nEqual scores use lower total server-timed response duration. Exact ties draw.\nThe winner receives a 100 XP victory bonus.\nElo depends on the result and opponent rating. XP is separate.\nComplete placements each month to earn a league. Ratings carry forward; seasons follow IST.\nGlobal positions include qualified players only.',
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
                                match.voided
                                    ? 'Match cancelled'
                                    : match.isTie
                                    ? 'Draw'
                                    : match.isWinner
                                    ? 'Victory'
                                    : 'Defeat',
                                style: context.type.titleSmall,
                              ),
                              Text(
                                '${match.xpAwarded} XP awarded · ${match.ratingLabel}',
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
                          if (match.seasonId != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                seasonLabel(match.seasonId!),
                                style: context.type.bodySmall,
                              ),
                            ),
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
                                    match.voided ||
                                        match.disposition == 'PENDING' ||
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
                if (c.hasMoreHistory.value)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton(
                      onPressed: c.isLoadingHistory.value
                          ? null
                          : () => c.fetchHistory(more: true),
                      child: const Text('Load more matches'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
