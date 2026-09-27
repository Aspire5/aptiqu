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
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: controller.startMatchmaking,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AptiquColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.flash_on_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Find Match (Ranked Duel)',
                                        style: AptiquTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
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
