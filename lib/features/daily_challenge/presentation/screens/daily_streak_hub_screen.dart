import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../models/daily_challenge_models.dart';

class DailyStreakHubScreen extends StatefulWidget {
  const DailyStreakHubScreen({super.key});

  @override
  State<DailyStreakHubScreen> createState() => _DailyStreakHubScreenState();
}

class _DailyStreakHubScreenState extends State<DailyStreakHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DailyChallengeController controller = Get.put(DailyChallengeController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      appBar: AppBar(
        backgroundColor: AptiquColors.surfaceDim,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AptiquColors.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Daily Streak Arena',
          style: AptiquTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AptiquColors.onSurface,
          ),
        ),
        actions: [
          Obx(() {
            final auth = Get.find<AuthController>();
            final coins = auth.currentUser.value?.coins ?? 0;
            return Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AptiquColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: AptiquColors.tertiary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$coins',
                    style: AptiquTypography.labelCaps.copyWith(
                      color: AptiquColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Segmented Tabs: OVERVIEW vs STREAK LOGS
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AptiquColors.outlineVariant),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AptiquColors.primary.withValues(alpha: 0.6)),
                  ),
                  labelColor: AptiquColors.primary,
                  unselectedLabelColor: AptiquColors.onSurfaceVariant,
                  labelStyle: AptiquTypography.labelCaps.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                  tabs: const [
                    Tab(text: 'CHALLENGE HUB'),
                    Tab(text: 'STREAK LOGS / HISTORY'),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context),
                    _buildHistoryTab(context),
                  ],
                ),
              ),
            ],
          ),

          // FULL-SCREEN BLOCKING MODAL OVERLAY (Ensures user UI is blocked during AI generation)
          Obx(() {
            if (!controller.isStarting.value) return const SizedBox.shrink();

            return Container(
              color: Colors.black.withValues(alpha: 0.85),
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Circular Pulse
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(AptiquColors.tertiary),
                          backgroundColor: AptiquColors.tertiary.withValues(alpha: 0.2),
                        ),
                      ),
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AptiquColors.tertiary,
                        size: 42,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'INITIALIZING DAILY CHALLENGE',
                    style: AptiquTypography.labelCaps.copyWith(
                      color: AptiquColors.tertiary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(() => Text(
                        controller.startLoadingMessage.value,
                        textAlign: TextAlign.center,
                        style: AptiquTypography.bodyMedium.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      )),
                  const SizedBox(height: 8),
                  Text(
                    'Please hold tight while Gemini AI prepares your unique trick question script...',
                    textAlign: TextAlign.center,
                    style: AptiquTypography.bodySmall.copyWith(
                      color: AptiquColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingStatus.value) {
        return const Center(
          child: CircularProgressIndicator(color: AptiquColors.tertiary),
        );
      }

      if (controller.statusErrorMessage.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AptiquColors.error, size: 40),
                const SizedBox(height: 12),
                Text(
                  controller.statusErrorMessage.value,
                  style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.fetchStatus,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      final status = controller.status.value;
      if (status == null) return const SizedBox.shrink();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Streak Banner Card
            _buildHeroStreakCard(status),

            const SizedBox(height: 16),

            // 2. Action / Due State Card
            _buildActionStateCard(context, status),

            const SizedBox(height: 16),

            // 3. Logic & Rules Showcase Card
            _buildRulesShowcaseCard(status),
          ],
        ),
      );
    });
  }

  Widget _buildHeroStreakCard(DailyChallengeStatusModel status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A1608),
            AptiquColors.surfaceContainerLowest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AptiquColors.tertiary.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AptiquColors.tertiary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT STREAK',
                    style: AptiquTypography.labelCaps.copyWith(
                      color: AptiquColors.tertiary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${status.streak}',
                        style: AptiquTypography.headlineLarge.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 42,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DAYS',
                        style: AptiquTypography.titleSmall.copyWith(
                          color: AptiquColors.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AptiquColors.tertiary.withValues(alpha: 0.15),
                  border: Border.all(color: AptiquColors.tertiary.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AptiquColors.tertiary,
                  size: 38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AptiquColors.outlineVariant, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill(
                icon: Icons.military_tech_rounded,
                label: 'BEST STREAK',
                value: '${status.highestStreak} Days',
              ),
              Container(width: 1, height: 28, color: AptiquColors.outlineVariant),
              _buildStatPill(
                icon: Icons.speed_rounded,
                label: 'AVG SPEED',
                value: controller.userOverallAvgTimeMs.value > 0
                    ? '${(controller.userOverallAvgTimeMs.value / 1000).toStringAsFixed(1)}s'
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: AptiquColors.secondary, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AptiquTypography.labelCaps.copyWith(
                color: AptiquColors.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
            Text(
              value,
              style: AptiquTypography.bodySmall.copyWith(
                color: AptiquColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionStateCard(BuildContext context, DailyChallengeStatusModel status) {
    if (status.isCompletedToday) {
      // Completed State Card
      final hours = status.msUntilMidnight ~/ (1000 * 60 * 60);
      final minutes = (status.msUntilMidnight % (1000 * 60 * 60)) ~/ (1000 * 60);

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completed for Today!',
                        style: AptiquTypography.titleSmall.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your streak is safely locked for the next cycle.',
                        style: AptiquTypography.bodySmall.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, color: AptiquColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Next challenge unlocks in: ${hours}h ${minutes}m',
                    style: AptiquTypography.labelCaps.copyWith(
                      color: AptiquColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Due State: Big Start Button
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AptiquColors.tertiary.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AptiquColors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: AptiquColors.tertiary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Challenge is Due!',
                      style: AptiquTypography.titleSmall.copyWith(
                        color: AptiquColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${status.tierTitle} · ${status.questionCount} Question(s)',
                      style: AptiquTypography.bodySmall.copyWith(
                        color: AptiquColors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => controller.startDailyChallenge(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AptiquColors.tertiary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                const SizedBox(width: 8),
                Text(
                  'START DAILY CHALLENGE',
                  style: AptiquTypography.labelCaps.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesShowcaseCard(DailyChallengeStatusModel status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AptiquColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AptiquColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'How Daily Streak Works',
                style: AptiquTypography.titleSmall.copyWith(
                  color: AptiquColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRuleRow(
            icon: Icons.layers_outlined,
            title: 'Tier-Based Challenge Script',
            desc:
                '• 0–9 Days: 1 Easy Question\n• 10–99 Days: 2 Questions (1 Easy, 1 Medium)\n• 100+ Days: 3 Questions (1 Easy, 1 Medium, 1 Hard)',
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            icon: Icons.timer_outlined,
            title: 'Fixed 60-Second Timer',
            desc:
                'Every question has a strict 60-second limit. Each question has an aptitude shortcut trick solvable within the time limit.',
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            icon: Icons.visibility_off_outlined,
            title: 'Zero Hints Allowed',
            desc: 'No hints are provided during the challenge to test genuine quick-thinking.',
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            icon: Icons.psychology_outlined,
            title: 'Post-Answer Explanation & Tricks',
            desc:
                'Instantly review the mathematical shortcut after each question to learn and level up your speed.',
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            icon: Icons.public_rounded,
            title: 'Global Daily Question',
            desc: 'All aspirants in your tier receive the exact same AI-crafted script for 24 hours.',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AptiquColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AptiquTypography.bodySmall.copyWith(
                  color: AptiquColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AptiquTypography.bodySmall.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingHistory.value && controller.historyList.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: AptiquColors.tertiary));
      }

      if (controller.historyList.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: AptiquColors.onSurfaceVariant, size: 48),
              const SizedBox(height: 12),
              Text(
                'No Daily Challenge History Yet',
                style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete today\'s challenge to build your streak log!',
                style: AptiquTypography.bodySmall.copyWith(color: AptiquColors.outline),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.fetchHistory(refresh: true),
        color: AptiquColors.tertiary,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.historyList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = controller.historyList[index];
            final isCompleted = item.status == 'COMPLETED';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.3)
                      : AptiquColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.dateString,
                        style: AptiquTypography.labelCaps.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.status,
                          style: AptiquTypography.labelCaps.copyWith(
                            color: isCompleted ? Colors.green : Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AptiquColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Score: ${item.correctCount}/${item.totalQuestions}',
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: AptiquColors.secondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Avg: ${(item.avgTimeMs / 1000).toStringAsFixed(1)}s',
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (item.xpAwarded > 0)
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: AptiquColors.tertiary, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              '+${item.xpAwarded} XP',
                              style: AptiquTypography.bodySmall.copyWith(
                                color: AptiquColors.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
