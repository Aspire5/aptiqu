import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import 'achievement_browser.dart';
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
          _daily(),
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
          Center(child: AppLoader(loading: loading)),
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
            Row(
              children: [
                Expanded(
                  child: _heading(
                    'Your consistency',
                    'Learning activity · scroll through the months',
                  ),
                ),
                const Tooltip(
                  message: 'Available year',
                  child: Chip(
                    label: Text('2026'),
                    avatar: Icon(Icons.calendar_today, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YearActivityCalendar(
                    days: d.activity,
                    today:
                        d.today ??
                        DateFormat('yyyy-MM-dd').format(
                          DateTime.now().toUtc().add(
                            const Duration(hours: 5, minutes: 30),
                          ),
                        ),
                  ),
                  const SizedBox(height: 12),
                  _text(
                    'More answers, more colour. Tap a date for details. All dates use IST.',
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
            if (d.badges.isEmpty)
              _card(
                child: _text(
                  'New achievements will appear here when they are available.',
                ),
              ),
            for (final badge in d.badges) ...[
              _badge(badge),
              const SizedBox(height: 8),
            ],
            if (d.badges.isNotEmpty)
              TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AptiquColors.surfaceContainerLow,
                  builder: (_) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .85,
                    child: AchievementBrowser(
                      badgeBuilder: _badge,
                      fetchPage: (page) async {
                        final response = await Get.find<DioClient>().dio.get(
                          '/user/achievements',
                          queryParameters: {'page': page, 'limit': 20},
                        );
                        return Map<String, dynamic>.from(response.data['data']);
                      },
                    ),
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('View all achievements'),
              ),
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

  Widget _daily() {
    final streakDays =
        int.tryParse(
          (user?.streak ?? '0d').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    return _card(
      padding: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onDaily,
            leading: const Icon(
              Icons.local_fire_department_rounded,
              color: AptiquColors.tertiary,
            ),
            title: _text(
              'Daily Challenge',
              color: AptiquColors.onSurface,
              weight: FontWeight.w600,
            ),
            subtitle: _text(
              user?.dailyChallengeCompleted == true
                  ? 'Finished today · see your result'
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _text(
              'Current Streak : $streakDays ${streakDays == 1 ? 'Day' : 'Days'}',
              size: 13,
            ),
          ),
        ],
      ),
    );
  }

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
    child: Material(type: MaterialType.transparency, child: child),
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
  final String? today;
  const ActivityCalendar({super.key, required this.days, this.today});

  @override
  Widget build(BuildContext context) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final months = <String, List<HomeActivityDay>>{};
    for (final day in sorted) {
      months.putIfAbsent(day.date.substring(0, 7), () => []).add(day);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entries in months.values) ...[
          Text(
            DateFormat('MMMM yyyy').format(DateTime.parse(entries.first.date)),
            style: AptiquTypography.bodySm.copyWith(
              color: AptiquColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AptiquColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final firstWeekday =
                  DateTime.parse(entries.first.date).weekday - 1;
              return Wrap(
                children: [
                  for (var i = 0; i < firstWeekday; i++)
                    SizedBox(width: constraints.maxWidth / 7, height: 48),
                  for (final day in entries)
                    _day(context, day, constraints.maxWidth / 7),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 17,
                  color: AptiquColors.tertiary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Daily Challenge completed',
                    style: AptiquTypography.bodySm.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border.all(color: AptiquColors.secondary),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Today',
                  style: AptiquTypography.bodySm.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _day(BuildContext context, HomeActivityDay day, double width) {
    final date = DateTime.parse(day.date);
    final isToday = day.date == today;
    return SizedBox(
      width: width,
      height: 48,
      child: Semantics(
        button: true,
        label:
            '${day.date}: ${day.attempted} submissions, ${day.correct} correct${day.dailyChallengeCompleted ? ', Daily Challenge completed' : ''}',
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
                    Text(
                      DateFormat('EEE, d MMM yyyy').format(date),
                      style: AptiquTypography.headlineSm,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      day.attempted == 0
                          ? 'No recorded question submissions.'
                          : '${day.attempted} answers submitted\n${day.correct} correct',
                      style: AptiquTypography.bodySm,
                    ),
                    if (day.dailyChallengeCompleted) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Daily Challenge completed',
                        style: TextStyle(color: AptiquColors.tertiary),
                      ),
                    ],
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
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
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
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isToday
                            ? AptiquColors.secondary
                            : AptiquColors.outlineVariant,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AptiquColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (day.dailyChallengeCompleted)
                  const Positioned(
                    top: -4,
                    right: -3,
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 17,
                      color: AptiquColors.tertiary,
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

class YearActivityCalendar extends StatefulWidget {
  final List<HomeActivityDay> days;
  final String today;
  const YearActivityCalendar({
    super.key,
    required this.days,
    required this.today,
  });
  @override
  State<YearActivityCalendar> createState() => _YearActivityCalendarState();
}

class _YearActivityCalendarState extends State<YearActivityCalendar> {
  late final ScrollController _scroll;
  late double _monthHeight;
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _monthHeight =
        410 +
        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 70) * 6;
    _scroll = ScrollController(
      initialScrollOffset:
          (DateTime.parse(widget.today).month - 1) * _monthHeight,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final day in widget.days) day.date: day};
    return SizedBox(
      height: _monthHeight,
      child: Scrollbar(
        controller: _scroll,
        child: ListView.builder(
          controller: _scroll,
          primary: false,
          // Keep compatibility with Flutter versions before scrollCacheExtent.
          // ignore: deprecated_member_use
          cacheExtent: 0,
          itemExtent: _monthHeight,
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final days = List.generate(DateTime(2026, month + 1, 0).day, (i) {
              final key = DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime(2026, month, i + 1));
              return byDate[key] ?? HomeActivityDay(key, 0, 0);
            });
            return ActivityCalendar(days: days, today: widget.today);
          },
        ),
      ),
    );
  }
}
