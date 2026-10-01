import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/pvp_lobby_controller.dart';

class PvpLobbyView extends StatelessWidget {
  const PvpLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PvpLobbyController());

    return Container(
      color: AptiquColors.surfaceDim,
      child: SafeArea(
        child: Column(
          children: [
            // Header Zone
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranked PvP Arena',
                        style: AptiquTypography.titleMedium.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Real-time 1v1 Quantitative Duel',
                        style: AptiquTypography.bodySmall.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Duel Rules Showcase Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AptiquColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AptiquColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: AptiquColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Match Rules',
                                style: AptiquTypography.titleSmall.copyWith(
                                  color: AptiquColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildRuleRow(Icons.pin_rounded, '10 Authoritative Questions per match'),
                          const SizedBox(height: 12),
                          _buildRuleRow(Icons.timer_outlined, '60 Seconds fixed timer per question'),
                          const SizedBox(height: 12),
                          _buildRuleRow(Icons.bolt_rounded, 'First to answer correctly gets tie-breaker advantage'),
                          const SizedBox(height: 12),
                          _buildRuleRow(Icons.military_tech_rounded, '+100 XP Victory Bonus for the winner'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status / Matchmaking Animation Card
                    Obx(() {
                      final inQueue = controller.isInQueue.value;
                      final seconds = controller.secondsInQueue.value;

                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: inQueue
                              ? AptiquColors.primaryDark.withValues(alpha: 0.3)
                              : AptiquColors.surfaceContainerHigh.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: inQueue ? AptiquColors.primary : AptiquColors.outlineVariant,
                            width: inQueue ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (inQueue) ...[
                              const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(AptiquColors.primary),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Finding Ranked Opponent...',
                                style: AptiquTypography.titleSmall.copyWith(
                                  color: AptiquColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Time in Queue: ${seconds}s',
                                style: AptiquTypography.bodyMedium.copyWith(
                                  color: AptiquColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: controller.cancelMatchmaking,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AptiquColors.error,
                                  side: const BorderSide(color: AptiquColors.error),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel Matchmaking'),
                              ),
                            ] else ...[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AptiquColors.primary.withValues(alpha: 0.15),
                                ),
                                child: const Icon(
                                  Icons.sports_esports_rounded,
                                  color: AptiquColors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ready to Test Your Speed?',
                                style: AptiquTypography.titleMedium.copyWith(
                                  color: AptiquColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Compete head-to-head on the live curriculum track.',
                                style: AptiquTypography.bodySmall.copyWith(
                                  color: AptiquColors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: controller.startMatchmaking,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AptiquColors.buttonDarkBg,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: AptiquColors.secondary.withValues(alpha: 0.5),
                                        width: 1.2,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Find Match (Ranked Duel)',
                                        style: AptiquTypography.labelLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 28),

                    // Recent Matches & Practice Replays Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, color: AptiquColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Duels & Replays',
                              style: AptiquTypography.titleSmall.copyWith(
                                color: AptiquColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: controller.fetchHistory,
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: AptiquColors.onSurfaceVariant),
                          tooltip: 'Refresh Matches',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Obx(() {
                      if (controller.isLoadingHistory.value && controller.matchHistory.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AptiquColors.primary),
                          ),
                        );
                      }

                      if (controller.matchHistory.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AptiquColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AptiquColors.outlineVariant),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.sports_kabaddi_rounded, size: 36, color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text(
                                'No Duels Played Yet',
                                style: AptiquTypography.labelMedium.copyWith(
                                  color: AptiquColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete a 1v1 match to view duel history & replay questions.',
                                style: AptiquTypography.bodySmall.copyWith(
                                  color: AptiquColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: controller.matchHistory.map((match) {
                          final isWinner = match.isWinner;
                          final isTie = match.isTie;
                          final badgeColor = isTie
                              ? const Color(0xFFF59E0B)
                              : isWinner
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444);
                          final outcomeText = isTie
                              ? 'TIE'
                              : isWinner
                                  ? 'VICTORY'
                                  : 'DEFEAT';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AptiquColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isWinner
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                    : AptiquColors.outlineVariant,
                                width: isWinner ? 1.2 : 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Match Outcome Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isTie
                                                ? Icons.horizontal_rule_rounded
                                                : isWinner
                                                    ? Icons.emoji_events_rounded
                                                    : Icons.close_rounded,
                                            size: 13,
                                            color: badgeColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            outcomeText,
                                            style: AptiquTypography.labelCaps.copyWith(
                                              color: badgeColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (match.xpAwarded > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AptiquColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${match.xpAwarded} XP',
                                          style: AptiquTypography.labelCaps.copyWith(
                                            color: AptiquColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Duel Competitors & Scoreline
                                Row(
                                  children: [
                                    // Opponent Avatar & Info
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AptiquColors.surfaceContainerHigh,
                                      backgroundImage: match.opponent.avatarUrl != null && match.opponent.avatarUrl!.isNotEmpty
                                          ? NetworkImage(match.opponent.avatarUrl!)
                                          : null,
                                      child: match.opponent.avatarUrl == null || match.opponent.avatarUrl!.isEmpty
                                          ? Text(
                                              match.opponent.name.isNotEmpty
                                                  ? match.opponent.name[0].toUpperCase()
                                                  : 'O',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'vs ${match.opponent.name}',
                                            style: AptiquTypography.bodyMedium.copyWith(
                                              color: AptiquColors.onSurface,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Lvl ${match.opponent.level} Opponent',
                                            style: AptiquTypography.labelSmall.copyWith(
                                              color: AptiquColors.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Score Comparison
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${match.score}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isWinner ? const Color(0xFF10B981) : AptiquColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            ' : ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          Text(
                                            '${match.opponentScore}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: !isWinner && !isTie ? const Color(0xFFEF4444) : AptiquColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: AptiquColors.outlineVariant, height: 1, thickness: 0.6),
                                const SizedBox(height: 10),

                                // Footer: Stats & Replay Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Avg: ${(match.avgResponseTimeMs / 1000).toStringAsFixed(1)}s / Q',
                                      style: AptiquTypography.labelSmall.copyWith(
                                        color: AptiquColors.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: controller.isReplayingMatch.value
                                          ? null
                                          : () => controller.replayMatchInPractice(match.matchId),
                                      icon: const Icon(Icons.fitness_center_rounded, size: 14),
                                      label: const Text(
                                        'Practice Replay (0 XP)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AptiquColors.secondary,
                                        side: const BorderSide(color: AptiquColors.secondary),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AptiquColors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.onSurface),
          ),
        ),
      ],
    );
  }
}
