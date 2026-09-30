import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/pvp_arena_controller.dart';

class PvpArenaScreen extends StatelessWidget {
  final String matchId;
  final List<dynamic> initialPlayersData;
  final int totalQuestions;

  const PvpArenaScreen({
    super.key,
    required this.matchId,
    required this.initialPlayersData,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PvpArenaController(
      matchId: matchId,
      initialPlayersData: initialPlayersData,
      totalQuestions: totalQuestions,
    ));

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AptiquColors.surfaceDim,
        body: SafeArea(
          child: Obx(() {
            if (controller.isMatchCompleted.value) {
              return _buildMatchCompletedView(context, controller);
            }

            final q = controller.currentQuestion.value;
            final curIdx = controller.currentQuestionIndex.value + 1;
            final remainingSec = controller.remainingSeconds.value;
            final isLocked = controller.hasSubmittedAnswer.value;
            final isRoundEnd = controller.isRoundEnded.value;

            return Column(
              children: [
                // Top Arena Scoreboard & Radial Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AptiquColors.surfaceContainerLowest,
                    border: Border(bottom: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // You
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AptiquColors.primary.withValues(alpha: 0.15),
                              border: Border.all(color: AptiquColors.primary),
                            ),
                            child: const Icon(Icons.person, color: AptiquColors.primary, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('You', style: AptiquTypography.labelSmall.copyWith(color: AptiquColors.onSurfaceVariant)),
                              Text(
                                '${controller.myScore.value} pts',
                                style: AptiquTypography.titleSmall.copyWith(
                                  color: AptiquColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Center: Round Progress & 60s Radial Ring
                      Column(
                        children: [
                          Text(
                            'Q $curIdx / $totalQuestions',
                            style: AptiquTypography.labelSmall.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  value: remainingSec / 60.0,
                                  strokeWidth: 3.5,
                                  backgroundColor: AptiquColors.surfaceContainerHigh,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    remainingSec <= 10 ? const Color(0xFFEF4444) : AptiquColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '${remainingSec}s',
                                style: AptiquTypography.labelSmall.copyWith(
                                  color: remainingSec <= 10 ? const Color(0xFFEF4444) : AptiquColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Opponent
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                controller.opponentName.value,
                                style: AptiquTypography.labelSmall.copyWith(color: AptiquColors.onSurfaceVariant),
                              ),
                              Text(
                                '${controller.opponentScore.value} pts',
                                style: AptiquTypography.titleSmall.copyWith(
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B), size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Question Body
                Expanded(
                  child: q == null
                      ? const Center(child: CircularProgressIndicator(color: AptiquColors.primary))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Question Prompt Card
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AptiquColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AptiquColors.outlineVariant),
                                ),
                                child: Text(
                                  q.prompt,
                                  style: AptiquTypography.headlineSmall.copyWith(
                                    color: AptiquColors.onSurface,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 4 Multiple Choice Options
                              ...q.options.map((opt) {
                                final isSelected = controller.selectedOptionId.value == opt.id;
                                Color cardColor = AptiquColors.surfaceContainerHigh;
                                Color borderColor = AptiquColors.outlineVariant;
                                Color textColor = AptiquColors.onSurface;

                                if (isRoundEnd) {
                                  if (opt.id == controller.roundCorrectAnswer.value) {
                                    cardColor = const Color(0xFF10B981).withValues(alpha: 0.2);
                                    borderColor = const Color(0xFF10B981);
                                    textColor = const Color(0xFF10B981);
                                  } else if (isSelected) {
                                    cardColor = const Color(0xFFEF4444).withValues(alpha: 0.2);
                                    borderColor = const Color(0xFFEF4444);
                                    textColor = const Color(0xFFEF4444);
                                  }
                                } else if (isSelected) {
                                  cardColor = AptiquColors.primary.withValues(alpha: 0.2);
                                  borderColor = AptiquColors.primary;
                                  textColor = AptiquColors.primary;
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: isLocked || isRoundEnd ? null : () => controller.selectOption(opt.id),
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: borderColor, width: 1.5),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? borderColor : Colors.transparent,
                                              border: Border.all(color: borderColor, width: 1.5),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              opt.id,
                                              style: AptiquTypography.labelMedium.copyWith(
                                                color: isSelected ? Colors.white : textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              opt.text,
                                              style: AptiquTypography.bodyLarge.copyWith(
                                                color: textColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              if (isLocked && !isRoundEnd) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AptiquColors.primaryDark.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AptiquColors.primary),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Answer locked! Waiting for opponent / round end...',
                                          style: AptiquTypography.bodySmall.copyWith(color: AptiquColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              if (isRoundEnd && controller.roundExplanation.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AptiquColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    'Correct: Option ${controller.roundCorrectAnswer.value}. ${controller.roundExplanation.value}',
                                    style: AptiquTypography.bodySmall.copyWith(color: AptiquColors.onSurface),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMatchCompletedView(BuildContext context, PvpArenaController controller) {
    final isWin = controller.isWinner.value;
    final isTie = controller.isTie.value;
    final xp = controller.xpAwarded.value;
    final isAfk = controller.isOpponentAfk.value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWin
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : isTie
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                border: Border.all(
                  color: isWin
                      ? const Color(0xFF10B981)
                      : isTie
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                  width: 2.5,
                ),
              ),
              child: Icon(
                isWin
                    ? Icons.military_tech_rounded
                    : isTie
                        ? Icons.handshake_rounded
                        : Icons.close_rounded,
                color: isWin
                    ? const Color(0xFF10B981)
                    : isTie
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isWin
                  ? 'VICTORY!'
                  : isTie
                      ? 'STALEMATE TIE'
                      : 'DEFEAT',
              style: AptiquTypography.headlineMedium.copyWith(
                color: isWin
                    ? const Color(0xFF10B981)
                    : isTie
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Final Score: ${controller.myScore.value} - ${controller.opponentScore.value}',
              style: AptiquTypography.titleMedium.copyWith(
                color: AptiquColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isAfk) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Opponent Left / Disconnected Mid-Match',
                  style: AptiquTypography.labelSmall.copyWith(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AptiquColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AptiquColors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: AptiquColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '+$xp XP Earned',
                    style: AptiquTypography.titleMedium.copyWith(
                      color: AptiquColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Exit arena back to lobby
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Return to Arena Lobby'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
