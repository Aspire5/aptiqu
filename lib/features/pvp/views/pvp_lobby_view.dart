import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../../social/widgets/social_widgets.dart';
import '../controllers/pvp_lobby_controller.dart';
import '../models/pvp_history_model.dart';
import '../ranked/ranked_models.dart';
import '../ranked/ranked_widgets.dart';

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
              cacheExtent: 1500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                // 1. Header Row
                _buildHeader(context),
                const SizedBox(height: 10),

                // 2. Banner on Top: aptiqu_onboarding_compete.webp
                _buildCompeteBanner(context, c),
                const SizedBox(height: 10),

                // 3. Centerpiece: League Badge, Elo details, Matches Count & Stats
                _buildLeagueShowcaseCard(context, c),
                const SizedBox(height: 12),

                // 4. Primary CTA: Find Match (followed at the bottom of the showcase)
                _buildMatchmakingSection(context, c),
                const SizedBox(height: 14),

                // 5. Match rules
                _buildMatchRulesCard(context),
                const SizedBox(height: 18),

                // 6. Recent matches
                _buildRecentMatchesSection(context, c),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top header row with title and action shortcuts
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ranked',
            style: (context.type.titleLarge ?? const TextStyle()).copyWith(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Leaderboard',
          onPressed: () => context.push(AppRoutes.rankedLeaderboard),
          icon: const Icon(Icons.leaderboard_outlined),
        ),
        IconButton(
          tooltip: 'Season history',
          onPressed: () => context.push(AppRoutes.rankedSeasons),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
    );
  }

  /// High-resolution competition banner downsampled for zero jank
  Widget _buildCompeteBanner(BuildContext context, PvpLobbyController c) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale > 1.3) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    const bannerHeight = 110.0;
    final cachePx = (screenWidth * pixelRatio).round().clamp(1, 1080);
    final seasonLabel = c.summary.value?.season.label;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AptiquRadius.panel),
      child: Stack(
        children: [
          Container(
            height: bannerHeight,
            width: double.infinity,
            color: context.colors.surfaceContainerHighest,
            child: Image.asset(
              'assets/images/login/aptiqu_onboarding_compete.webp',
              fit: BoxFit.cover,
              width: double.infinity,
              height: bannerHeight,
              cacheWidth: cachePx,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const SizedBox(height: bannerHeight),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 8,
            right: 10,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'HEAD-TO-HEAD DUEL',
                        style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (seasonLabel != null)
                  Text(
                    seasonLabel,
                    style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Centerpiece card: League icon badge at center, Elo details, match count and standing stats
  Widget _buildLeagueShowcaseCard(BuildContext context, PvpLobbyController c) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isEnlarged = textScale > 1.3;
    final badgeSize = isEnlarged ? 32.0 : 64.0;
    final summary = c.summary.value;
    final standing = summary?.standing;
    final league = standing?.league ?? RankedLeague.unranked;
    final rating = standing?.rating ?? 1200;
    final isUnplayed = standing == null || standing.played == 0;
    final isProvisional = standing?.provisional ?? false;
    final isQualified = standing?.qualified ?? false;
    final played = standing?.played ?? 0;
    final wins = standing?.wins ?? 0;
    final losses = standing?.losses ?? 0;
    final draws = standing?.draws ?? 0;

    final positionLabel = standing?.position != null
        ? '#${standing!.position}'
        : (isQualified ? 'Unranked' : '—');
    final percentileLabel = isEnlarged && !isQualified
        ? '${standing?.completed ?? 0}/${standing?.required ?? 5}'
        : (standing?.globalRankPercentile ??
            (isQualified ? 'Ranked' : (standing?.placementLabel ?? 'Placements 0 of 5')));

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AptiquRadius.panel),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isEnlarged ? 6 : 12,
      ),
      child: Column(
        children: [
          // Centered League Badge
          Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    blurRadius: isEnlarged ? 10 : 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: RankedBadge(
                league: league,
                size: badgeSize,
                decorative: true,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // League Title
          Text(
            league.label,
            style: (context.type.titleLarge ?? const TextStyle()).copyWith(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),

          // Elo rating details badge
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rating Elo',
                  style: (context.type.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (isProvisional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Provisional',
                    style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSecondaryContainer,
                    ),
                  ),
                )
              else if (isUnplayed)
                Text(
                  'Default rating',
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          // Progress to next league or placement qualification
          if (standing != null && standing.nextLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${standing.toNext} Elo to ${standing.nextLabel}',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (standing.progress != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(standing.progress! * 100).toInt()}%',
                    style: context.type.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (standing.progress ?? 0).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: context.colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(context.colors.primary),
              ),
            ),
          ] else if (standing != null && !isQualified) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${standing.remaining} ${standing.remaining == 1 ? 'match' : 'matches'} to qualify',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${standing.completed}/${standing.required}',
                  style: context.type.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: standing.required > 0
                    ? (standing.completed / standing.required).clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 5,
                backgroundColor: context.colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(context.colors.secondary),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 3-Column Stats Row: Global Rank | Standing | Matches
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AptiquRadius.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statColumn(
                    context,
                    label: 'Global Rank',
                    value: positionLabel,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.colors.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _statColumn(
                    context,
                    label: 'Standing',
                    value: percentileLabel,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.colors.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _statColumn(
                    context,
                    label: 'Matches',
                    value: '$played',
                  ),
                ),
              ],
            ),
          ),

          // Win/Loss/Draw summary row (when played > 0 and not enlarged)
          if (played > 0 && !isEnlarged) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$wins W',
                  style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                    color: context.status.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' · ',
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$losses L',
                  style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                    color: context.colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (draws > 0) ...[
                  Text(
                    ' · ',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$draws D',
                    style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                      color: context.status.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (standing?.peakRating != null) ...[
                  Text(
                    ' · Peak ${standing!.peakRating} Elo',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (c.standingStatus.value == 'DISABLED')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Leagues are not available yet',
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),

          if (c.standingError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SessionNotice(
                message: c.standingError.value,
                onRetry: c.fetchSummary,
              ),
            ),
        ],
      ),
    );
  }

  /// Compact, balanced stat column item
  Widget _statColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (context.type.titleSmall ?? const TextStyle()).copyWith(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: context.colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (context.type.bodySmall ?? const TextStyle()).copyWith(
            color: context.colors.onSurfaceVariant,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  /// Matchmaking action zone followed at bottom of showcase
  Widget _buildMatchmakingSection(BuildContext context, PvpLobbyController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: c.resumeMatch,
          )
        else if (c.queueUncertain.value)
          AptiquButton.outline(
            label: 'Check for an existing match',
            icon: const Icon(Icons.sync_rounded),
            onPressed: c.fetchSummary,
          )
        else if (c.isInQueue.value || c.isCancelling.value)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainer,
              borderRadius: BorderRadius.circular(AptiquRadius.control),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          c.statusMessage.value,
                          style: context.type.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${c.secondsInQueue.value}s',
                        style: context.type.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                if (c.searchExpanded.value) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Search widened to include more ratings',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
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
              style: context.type.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        if (c.queueError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                c.queueError.value,
                style: context.type.bodyMedium?.copyWith(
                  color: context.colors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Clean, modern match rules expansion card
  Widget _buildMatchRulesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AptiquRadius.control),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('ranked-match-rules'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Icon(
            Icons.gavel_rounded,
            size: 20,
            color: context.colors.primary,
          ),
          title: Text(
            'Match rules',
            style: (context.type.titleSmall ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '10 questions · 60s timer · Speed tiebreak',
            style: context.type.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '10 questions from the live curriculum.\n60 seconds for each question.\nTap an option to submit immediately.\nEqual scores use lower total server-timed response duration. Exact ties draw.\nThe winner receives a 100 XP victory bonus.\nElo depends on the result and opponent rating. XP is separate.\nComplete placements each month to earn a league. Ratings carry forward; seasons follow IST.\nGlobal positions include qualified players only.',
                style: context.type.bodyMedium?.copyWith(
                  height: 1.5,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent matches section with cards and practice replay
  Widget _buildRecentMatchesSection(BuildContext context, PvpLobbyController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent matches',
                style: (context.type.titleMedium ?? const TextStyle()).copyWith(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh matches',
              onPressed: c.isLoadingHistory.value ? null : c.fetchHistory,
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AptiquRadius.control),
              border: Border.all(
                color: context.colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.sports_esports_outlined,
                  size: 36,
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'No Ranked matches yet',
                  style: context.type.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your completed matches and Practice replays will appear here.',
                  textAlign: TextAlign.center,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (c.isLoadingHistory.value) const LinearProgressIndicator(),
          for (final match in c.matchHistory)
            _buildMatchCard(context, c, match),
          if (c.hasMoreHistory.value)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton(
                onPressed: c.isLoadingHistory.value
                    ? null
                    : () => c.fetchHistory(more: true),
                child: const Text('Load more matches'),
              ),
            ),
        ],
      ],
    );
  }

  /// Individual styled recent match history card
  Widget _buildMatchCard(
    BuildContext context,
    PvpLobbyController c,
    PvpMatchHistoryItemModel match,
  ) {
    final isTie = match.isTie;
    final isWinner = match.isWinner;
    final isVoided = match.voided;

    final resultBg = isVoided
        ? context.colors.surfaceContainerHighest
        : isTie
        ? context.status.warningContainer
        : isWinner
        ? context.status.successContainer
        : context.colors.errorContainer;

    final resultColor = isVoided
        ? context.colors.onSurfaceVariant
        : isTie
        ? context.status.warning
        : isWinner
        ? context.status.success
        : context.colors.error;

    final resultIcon = isVoided
        ? Icons.cancel_outlined
        : isTie
        ? Icons.handshake_outlined
        : isWinner
        ? Icons.emoji_events_outlined
        : Icons.close_rounded;

    final resultText = isVoided
        ? 'Cancelled'
        : isTie
        ? 'Draw'
        : isWinner
        ? 'Victory'
        : 'Defeat';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AptiquRadius.control),
        border: Border.all(
          color: context.colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Match result chip & score
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resultBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(resultIcon, size: 14, color: resultColor),
                    const SizedBox(width: 4),
                    Text(
                      resultText,
                      style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w700,
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${match.xpAwarded} XP · ${match.ratingLabel}',
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${match.score} : ${match.opponentScore}',
                  style: (context.type.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Opponent avatar & speed
          Row(
            children: [
              LearnerAvatar(
                person: {
                  'name': match.opponent.name,
                  'avatarUrl': match.opponent.avatarUrl,
                },
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${match.opponent.name}',
                      style: (context.type.bodyLarge ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(match.avgResponseTimeMs / 1000).toStringAsFixed(1)}s avg speed',
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: match.voided ||
                        match.disposition == 'PENDING' ||
                        c.isReplayingMatch.value ||
                        c.isInQueue.value ||
                        c.isOpeningMatch.value ||
                        c.isCancelling.value
                    ? null
                    : () => c.replayMatchInPractice(match.matchId),
                icon: const Icon(Icons.replay_rounded, size: 15),
                label: const Text('Replay'),
              ),
            ],
          ),
          if (match.seasonId != null) ...[
            const SizedBox(height: 6),
            Text(
              seasonLabel(match.seasonId!),
              style: context.type.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
