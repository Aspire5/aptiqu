import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../../shared/widgets/feedback/app_state_view.dart';
import '../../../../shared/widgets/questions/question_presentation.dart';
import '../../../../shared/widgets/sheets/app_sheet.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../models/daily_challenge_models.dart';

class DailyStreakHubScreen extends StatefulWidget {
  const DailyStreakHubScreen({super.key});
  @override
  State<DailyStreakHubScreen> createState() => _DailyStreakHubScreenState();
}

class _DailyStreakHubScreenState extends State<DailyStreakHubScreen> {
  final DailyChallengeController controller =
      Get.isRegistered<DailyChallengeController>()
      ? Get.find<DailyChallengeController>()
      : Get.put(DailyChallengeController());
  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Obx(
      () => PopScope(
        canPop: !controller.isStarting.value,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: (MediaQuery.textScalerOf(context).scale(18) * 2.4)
                .clamp(56.0, double.infinity),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: controller.isStarting.value
                  ? null
                  : () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Daily challenge'),
            actions: [
              IconButton(
                tooltip: 'Daily history',
                onPressed: controller.isStarting.value
                    ? null
                    : () => _history(context),
                icon: const Icon(Icons.history_rounded),
              ),
            ],
          ),
          body: SafeArea(top: false, child: _overview(context)),
        ),
      ),
    ),
  );

  Widget _overview(BuildContext context) {
    if (controller.isStarting.value) {
      return Center(
        child: SingleChildScrollView(
          child: AppStateView(
            title: 'Preparing your daily challenge',
            message: controller.startLoadingMessage.value,
            loading: true,
          ),
        ),
      );
    }
    final status = controller.status.value;
    if (controller.isLoadingStatus.value && status == null) {
      return const Center(
        child: AppStateView(title: 'Loading daily challenge', loading: true),
      );
    }
    if (status == null) {
      return SingleChildScrollView(
        child: AppStateView(
          title: controller.statusErrorMessage.isNotEmpty
              ? 'Could not load the challenge'
              : 'Daily challenge unavailable',
          message: controller.statusErrorMessage.value,
          actionLabel: 'Retry',
          onAction: controller.fetchStatus,
        ),
      );
    }
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    return RefreshIndicator(
      onRefresh: controller.fetchStatus,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (controller.isLoadingStatus.value) const LinearProgressIndicator(),
          if (controller.statusErrorMessage.isNotEmpty)
            SessionNotice(
              message: controller.statusErrorMessage.value,
              onRetry: controller.fetchStatus,
            ),
          _availability(context, status),
          const SizedBox(height: 24),
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        color: context.status.warning,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${status.streak} day streak',
                          style: context.type.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SessionMetrics(
                    items: [
                      (
                        label: 'Best streak',
                        value: '${status.highestStreak} days',
                      ),
                      (
                        label: 'Average speed',
                        value: controller.userOverallAvgTimeMs.value > 0
                            ? '${(controller.userOverallAvgTimeMs.value / 1000).toStringAsFixed(1)}s'
                            : 'Unavailable',
                      ),
                      if (auth?.currentUser.value != null)
                        (
                          label: 'Coins',
                          value: '${auth!.currentUser.value!.coins}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('How it works', style: context.type.titleSmall),
          const SizedBox(height: 12),
          Text(
            'Answer every question correctly to increase your streak and earn rewards. Each question has a 60-second limit. No hints.',
            style: context.type.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'The daily cycle ends at midnight IST (UTC+5:30). Review both available methods after answering.',
            style: context.type.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: const Text('Tiers and daily questions'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '0–9 days: 1 Easy question\n10–99 days: 1 Easy + 1 Medium\n100+ days: 1 Easy + 1 Medium + 1 Hard\n\nEveryone in your tier receives the same daily questions.',
                  style: context.type.bodyLarge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _availability(BuildContext context, DailyChallengeStatusModel status) {
    final resume = status.todayParticipation?.status == 'IN_PROGRESS';
    final failed =
        status.todayParticipation?.status == 'FAILED' ||
        status.todayParticipation?.status == 'ABANDONED';
    final finished = status.isCompletedToday || !status.canAttempt;
    final hours = status.msUntilMidnight ~/ 3600000;
    final minutes = status.msUntilMidnight % 3600000 ~/ 60000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          finished
              ? failed
                    ? 'Today’s attempt is finished'
                    : status.isCompletedToday
                    ? 'Completed for today'
                    : 'Challenge unavailable'
              : resume
              ? 'Continue today’s challenge'
              : 'Ready for today?',
          style: context.type.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          finished
              ? failed
                    ? 'All questions must be correct to keep the streak and earn rewards.'
                    : status.isCompletedToday
                    ? 'Your result has been recorded.'
                    : 'You cannot start another attempt right now.'
              : '${status.tierTitle} · ${status.questionCount} ${status.questionCount == 1 ? 'question' : 'questions'}',
          style: context.type.bodyLarge,
        ),
        const SizedBox(height: 16),
        if (finished)
          Text(
            'Next daily cycle in ${hours}h ${minutes}m',
            style: context.type.bodyMedium,
          )
        else
          AptiquButton(
            label: resume ? 'Resume challenge' : 'Start daily challenge',
            icon: Icon(resume ? Icons.play_arrow_rounded : Icons.bolt_rounded),
            onPressed: status.canAttempt && !controller.isLoadingStatus.value
                ? () => controller.startDailyChallenge(context)
                : null,
          ),
        if (controller.startError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              controller.startError.value,
              style: context.type.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _history(BuildContext context) {
    controller.fetchHistory(refresh: true);
    showAppSheet<void>(
      context: context,
      title: 'Daily history',
      builder: (context) => Obx(() {
        if (controller.isLoadingHistory.value &&
            controller.historyList.isEmpty) {
          return const AppStateView(
            title: 'Loading daily history',
            loading: true,
          );
        }
        if (controller.historyList.isEmpty) {
          return AppStateView(
            title: controller.historyError.isNotEmpty
                ? 'Could not load history'
                : 'No daily history yet',
            message: controller.historyError.isNotEmpty
                ? controller.historyError.value
                : 'Your daily attempts will appear here.',
            actionLabel: controller.historyError.isNotEmpty ? 'Retry' : null,
            onAction: controller.historyError.isNotEmpty
                ? () => controller.fetchHistory(refresh: true)
                : null,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.historyError.isNotEmpty)
              SessionNotice(
                message: 'History could not be refreshed',
                onRetry: () => controller.fetchHistory(refresh: true),
              ),
            if (controller.isLoadingHistory.value)
              const LinearProgressIndicator(),
            for (final item in controller.historyList) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(item.dateString, style: context.type.titleSmall),
                        Text(
                          _statusLabel(item.status),
                          style: context.type.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SessionMetrics(
                      items: [
                        (
                          label: 'Correct',
                          value: '${item.correctCount}/${item.totalQuestions}',
                        ),
                        (
                          label: 'Average time',
                          value:
                              '${(item.avgTimeMs / 1000).toStringAsFixed(1)}s',
                        ),
                        (label: 'XP awarded', value: '${item.xpAwarded}'),
                        (label: 'Coins awarded', value: '${item.coinsAwarded}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            if (controller.historyPage.value <
                controller.historyTotalPages.value) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: controller.isLoadingHistory.value
                    ? null
                    : () => controller.fetchHistory(loadMore: true),
                child: const Text('Load more'),
              ),
            ],
          ],
        );
      }),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'COMPLETED' => 'Completed',
    'FAILED' => 'Unsuccessful',
    'ABANDONED' => 'Abandoned',
    'IN_PROGRESS' => 'In progress',
    _ => status,
  };
}
