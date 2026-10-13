import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../home/models/home_dashboard_model.dart';
import '../controllers/home_controller.dart';

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final auth = Get.find<AuthController>();
    return Obx(
      () => HomeDashboardContent(
        data: controller.dashboard.value,
        user: auth.currentUser.value,
        loading: controller.isLoadingDashboard.value,
        error: controller.dashboardError.value,
        onRefresh: () async {
          await Future.wait([
            controller.fetchDashboard(),
            auth.fetchUserProfile(),
          ]);
        },
        onResume: controller.resumeFromHome,
        onTopics: controller.selectTopicsTab,
        onRanked: () => controller.selectedNavIndex.value = 3,
        onPractice: () => controller.selectedNavIndex.value = 2,
        onDaily: () => context.push(AppRoutes.dailyStreak).then((_) {
          controller.fetchDashboard();
          auth.fetchUserProfile();
        }),
      ),
    );
  }
}

/// Presentation has no network or navigation dependencies, including empty states.
class HomeDashboardContent extends StatelessWidget {
  final HomeDashboardModel? data;
  final UserModel? user;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(HomeResume) onResume;
  final VoidCallback onTopics;
  final VoidCallback onRanked;
  final VoidCallback onPractice;
  final VoidCallback onDaily;
  const HomeDashboardContent({
    super.key,
    this.data,
    this.user,
    this.loading = false,
    this.error,
    required this.onRefresh,
    required this.onResume,
    required this.onTopics,
    required this.onRanked,
    required this.onPractice,
    required this.onDaily,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    return RefreshIndicator(
      color: AptiquColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(
            'Home',
            style: AptiquTypography.headlineSm.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          _text('A little progress, every day.'),
          const SizedBox(height: 24),
          _progress(),
          const SizedBox(height: 16),
          if (d?.resume != null)
            _action(
              title: d!.resume!.title,
              subtitle: d.resume!.topic ?? 'Your last lesson',
              label: 'Continue learning',
              icon: Icons.play_arrow_rounded,
              onTap: () => onResume(d.resume!),
            )
          else if (!loading || d != null)
            _action(
              title: 'Your next discovery',
              subtitle: 'Choose a topic and build your skills.',
              label: 'Explore topics',
              icon: Icons.explore_outlined,
              onTap: onTopics,
            ),
          const SizedBox(height: 12),
          _daily(),
          if (loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              color: AptiquColors.primary,
              backgroundColor: AptiquColors.outlineVariant,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(error!),
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (d != null) ...[
            const SizedBox(height: 28),
            _heading('Your consistency', 'Learning activity · last 4 weeks'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActivityCalendar(
                    days: d.activity.length > 28
                        ? d.activity.sublist(d.activity.length - 28)
                        : d.activity,
                  ),
                  const SizedBox(height: 12),
                  _text(
                    'Each square is a day. More answers, more colour. Tap for details. Dates use IST.',
                    size: 12,
                  ),
                  const SizedBox(height: 14),
                  _text(
                    '${user?.streak ?? '0d'} Daily Challenge streak',
                    color: AptiquColors.primary,
                  ),
                  const SizedBox(height: 4),
                  if ((user?.highestStreak ?? 0) > 0) ...[
                    _text(
                      'Best Daily Challenge streak: ${user!.highestStreak} days',
                      size: 12,
                    ),
                    const SizedBox(height: 4),
                  ],
                  _text(
                    'Your streak grows when you complete the Daily Challenge correctly.',
                    size: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _heading(
              'Your performance',
              'Answers across lessons, practice and challenges',
            ),
            const SizedBox(height: 12),
            _performance(context, d),
            const SizedBox(height: 28),
            _heading('Achievements', 'Milestones along the way'),
            const SizedBox(height: 12),
            for (final badge in d.badges) ...[
              _badge(badge),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 20),
            _heading('Ranked', 'Test your skills against another learner'),
            const SizedBox(height: 12),
            _action(
              title: d.ranked == null
                  ? 'Ready for your first match?'
                  : 'Last match · ${d.ranked!.result}',
              subtitle: d.ranked == null
                  ? 'Play a match to start your competitive journey.'
                  : '${d.ranked!.correct} of ${d.ranked!.questions} answers correct',
              label: 'Open Ranked',
              icon: Icons.emoji_events_outlined,
              onTap: onRanked,
              primary: false,
            ),
          ] else if (!loading && error == null) ...[
            const SizedBox(height: 16),
            _text('Your activity will appear here after you start learning.'),
          ],
        ],
      ),
    );
  }

  Widget _progress() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: AptiquColors.secondary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _text(
                'Your progress',
                color: AptiquColors.onSurface,
                weight: FontWeight.w600,
              ),
            ),
            _text('Level ${user?.level ?? 1}', color: AptiquColors.primary),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${user?.totalXp ?? 0} XP',
          style: AptiquTypography.headlineSm.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (user?.progress ?? 0).clamp(0, 1),
            minHeight: 6,
            color: AptiquColors.primaryContainer,
            backgroundColor: AptiquColors.outlineVariant,
          ),
        ),
        const SizedBox(height: 10),
        _text(
          '${user?.xpIntoCurrentLevel ?? 0} / ${user?.xpRequiredForNextLevel ?? 20} XP to the next level',
          size: 12,
        ),
      ],
    ),
  );

  Widget _daily() => _card(
    padding: 4,
    child: ListTile(
      onTap: onDaily,
      leading: const Icon(
        Icons.local_fire_department_outlined,
        color: AptiquColors.primary,
      ),
      title: _text(
        'Daily Challenge',
        color: AptiquColors.onSurface,
        weight: FontWeight.w600,
      ),
      subtitle: _text(
        user?.dailyChallengeCompleted == true
            ? 'Completed today · see your streak'
            : user?.dailyChallengeDue == true
            ? 'Available today · keep your streak going'
            : 'See today’s challenge',
        size: 12,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AptiquColors.onSurfaceVariant,
      ),
    ),
  );

  Widget _performance(BuildContext context, HomeDashboardModel d) {
    final p = d.performance;
    if (p.attempted == 0) {
      return _action(
        title: 'Build your first results',
        subtitle: 'Answer a question to see your accuracy and activity here.',
        label: 'Try practice',
        icon: Icons.track_changes_rounded,
        onTap: onPractice,
        primary: false,
      );
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              _stat('${p.correct}', 'Correct answers'),
              _stat('${p.attempted}', 'Submitted'),
              _stat(
                '${((p.accuracy ?? 0) * 100).toStringAsFixed(0)}%',
                'Accuracy',
              ),
              _stat(
                p.averageSolveTimeMs == null
                    ? '—'
                    : '${(p.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s',
                'Avg. correct time',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _text(
            'Retries and replays count as submissions. Time uses correct timed-mode answers only.',
            size: 12,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AptiquColors.surfaceContainerLow,
              builder: (_) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(
                        'By difficulty',
                        'Accuracy = correct answers ÷ submissions',
                      ),
                      const SizedBox(height: 20),
                      for (final level in ['EASY', 'MEDIUM', 'HARD', 'UNKNOWN'])
                        if (d.difficulty[level] != null) ...[
                          _text(
                            level == 'UNKNOWN'
                                ? 'Unclassified history'
                                : '${level[0]}${level.substring(1).toLowerCase()}',
                            color: AptiquColors.primary,
                          ),
                          const SizedBox(height: 6),
                          _text(
                            '${d.difficulty[level]!.correct} correct / ${d.difficulty[level]!.attempted} submitted · ${((d.difficulty[level]!.accuracy ?? 0) * 100).toStringAsFixed(0)}% accuracy',
                          ),
                          const SizedBox(height: 6),
                          _text(
                            d.difficulty[level]!.averageSolveTimeMs == null
                                ? 'No valid timed answers yet'
                                : '${(d.difficulty[level]!.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s average correct time',
                            size: 12,
                          ),
                          const SizedBox(height: 20),
                        ],
                      _text(
                        'Skipped questions and timeouts do not count as submissions. Lesson answers contribute to accuracy, but have no recorded solve time. Late answers are excluded from time averages.',
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.insights_outlined, size: 18),
            label: const Text('View difficulty details'),
          ),
        ],
      ),
    );
  }

  Widget _badge(HomeBadge b) => _card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          b.unlocked
              ? Icons.workspace_premium_rounded
              : Icons.lock_outline_rounded,
          color: b.unlocked
              ? AptiquColors.secondary
              : AptiquColors.onSurfaceVariant,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                b.title,
                color: AptiquColors.onSurface,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 4),
              _text(b.description, size: 12),
              const SizedBox(height: 10),
              if (!b.unlocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: b.target > 0
                        ? (b.progress / b.target).clamp(0, 1)
                        : 0,
                    minHeight: 4,
                    backgroundColor: AptiquColors.outlineVariant,
                    color: AptiquColors.primaryContainer,
                  ),
                ),
              const SizedBox(height: 4),
              _text(
                b.unlocked ? 'Earned' : '${b.progress} / ${b.target}',
                size: 12,
                color: b.unlocked
                    ? AptiquColors.secondary
                    : AptiquColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _action({
    required String title,
    required String subtitle,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = true,
  }) => _card(
    accent: primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(
          title,
          size: 18,
          color: AptiquColors.onSurface,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 6),
        _text(subtitle),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: primary
                  ? AptiquColors.primaryContainer
                  : AptiquColors.buttonDarkBg,
              foregroundColor: AptiquColors.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _text(
        title,
        size: 18,
        color: AptiquColors.onSurface,
        weight: FontWeight.w700,
      ),
      const SizedBox(height: 4),
      _text(subtitle, size: 12),
    ],
  );
  Widget _stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: AptiquTypography.headlineSm.copyWith(
          fontSize: 24,
          color: AptiquColors.secondary,
        ),
      ),
      const SizedBox(height: 3),
      _text(label, size: 12),
    ],
  );
  Widget _card({
    required Widget child,
    bool accent = false,
    double padding = 18,
  }) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: AptiquColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: accent
            ? AptiquColors.primaryContainer.withValues(alpha: .45)
            : AptiquColors.outlineVariant,
      ),
    ),
    child: child,
  );
  Widget _text(
    String text, {
    double size = 14,
    Color color = AptiquColors.onSurfaceVariant,
    FontWeight weight = FontWeight.w400,
  }) => Text(
    text,
    style: AptiquTypography.bodySm.copyWith(
      fontSize: size,
      height: 1.4,
      color: color,
      fontWeight: weight,
    ),
  );
}

class ActivityCalendar extends StatelessWidget {
  final List<HomeActivityDay> days;
  const ActivityCalendar({super.key, required this.days});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 308 ? 308.0 : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Wrap(
            children: [for (final day in days) _day(context, day, width / 7)],
          ),
        ),
      );
    },
  );

  Widget _day(
    BuildContext context,
    HomeActivityDay day,
    double width,
  ) => SizedBox(
    width: width,
    height: 44,
    child: Semantics(
      button: true,
      label:
          '${day.date}: ${day.attempted} submissions, ${day.correct} correct',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: AptiquColors.surfaceContainerLow,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.date, style: AptiquTypography.headlineSm),
                  const SizedBox(height: 12),
                  Text(
                    day.attempted == 0
                        ? 'No recorded question submissions.'
                        : '${day.attempted} answers submitted\n${day.correct} correct',
                    style: AptiquTypography.bodySm,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Asia/Kolkata · IST',
                    style: TextStyle(color: AptiquColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: day.attempted == 0
                  ? AptiquColors.surfaceContainerHigh
                  : AptiquColors.primaryContainer.withValues(
                      alpha: day.attempted < 5
                          ? .4
                          : day.attempted < 15
                          ? .7
                          : 1,
                    ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AptiquColors.outlineVariant),
            ),
            child: Center(
              child: Text(
                day.date.substring(8),
                style: TextStyle(
                  fontSize: 11,
                  color: day.attempted == 0
                      ? AptiquColors.onSurfaceVariant
                      : AptiquColors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
