import '../../../pvp/ranked/ranked_widgets.dart';
import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../../shared/widgets/sheets/app_sheet.dart';
import '../../../../core/network/dio_client.dart';
import 'achievement_browser.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
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
    final today =
        d?.today ??
        DateFormat('yyyy-MM-dd').format(
          DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)),
        );
    return RefreshIndicator(
      color: context.colors.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: AptiquSpace.gutter(MediaQuery.sizeOf(context).width),
          vertical: 24,
        ),
        children: [
          _daily(context),
          const SizedBox(height: 16),
          if (d?.resume != null)
            _action(
              context,
              title: d!.resume!.title,
              subtitle: d.resume!.topic ?? 'Your last lesson',
              label: 'Continue learning',
              icon: Icons.play_arrow_rounded,
              onTap: () => onResume(d.resume!),
            )
          else if (!loading || d != null)
            _action(
              context,
              title: 'Your next discovery',
              subtitle: 'Choose a topic and build your skills.',
              label: 'Explore topics',
              icon: Icons.explore_outlined,
              onTap: onTopics,
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: AppLoader()),
            ),
          if (error != null) ...[
            const SizedBox(height: 16),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(context, error!),
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (d != null) ...[
            const SizedBox(height: 24),
            _heading(
              context,
              'Your performance',
              'Answers across lessons, practice and challenges',
            ),
            const SizedBox(height: 12),
            _performance(context, d),
            const SizedBox(height: 24),
            _heading(context, 'Achievements', 'Milestones along the way'),
            const SizedBox(height: 12),
            if (d.badges.isEmpty)
              _card(
                context,
                child: _text(
                  context,
                  'New achievements will appear here when they are available.',
                ),
              ),
            for (final badge in d.badges.take(2)) ...[
              _badge(context, badge),
              const SizedBox(height: 8),
            ],
            if (d.badges.isNotEmpty)
              TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useSafeArea: true,
                  builder: (_) => AppSheetSurface(
                    builder: (context) => SizedBox(
                      height: MediaQuery.sizeOf(context).height * .85,
                      child: AchievementBrowser(
                        badgeBuilder: (badge) => _badge(context, badge),
                        fetchPage: (page) async {
                          final response = await Get.find<DioClient>().dio.get(
                            '/user/achievements',
                            queryParameters: {'page': page, 'limit': 20},
                          );
                          return Map<String, dynamic>.from(
                            response.data['data'],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                icon: Icon(Icons.workspace_premium_outlined),
                label: Text('View all achievements'),
              ),
            const SizedBox(height: 20),
            _heading(
              context,
              'Ranked',
              'Test your skills against another learner',
            ),
            const SizedBox(height: 12),
            if (d.rankedLeague == null)
              _action(
                context,
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
              )
            else
              RankedSectionView(
                section: d.rankedLeague,
                onOpen: onRanked,
                onRetry: onRefresh,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _heading(
                    context,
                    'Your consistency',
                    'Learning activity · scroll through the months',
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Current year only',
                  child: Chip(
                    label: Text(today.substring(0, 4)),
                    avatar: Icon(Icons.calendar_today_outlined, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YearActivityCalendar(days: d.activity, today: today),
                  const SizedBox(height: 12),
                  _text(
                    context,
                    'More answers, more colour. Tap a date, or use the date list. Swipe the calendar sideways to see all dates. All dates use IST.',
                    size: 12,
                  ),
                ],
              ),
            ),
          ] else if (!loading && error == null) ...[
            const SizedBox(height: 16),
            _text(
              context,
              'Your activity will appear here after you start learning.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _daily(BuildContext context) {
    final streakDays =
        int.tryParse(
          (user?.streak ?? '0d').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    return _card(
      context,
      padding: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onDaily,
            leading: Icon(
              Icons.local_fire_department_rounded,
              color: context.colors.tertiary,
            ),
            title: _text(
              context,
              'Daily Challenge',
              color: context.colors.onSurface,
              weight: FontWeight.w600,
            ),
            subtitle: _text(
              context,
              user?.dailyChallengeCompleted == true
                  ? 'Finished today · see your result'
                  : user?.dailyChallengeDue == true
                  ? 'Available today · keep your streak going'
                  : 'See today’s challenge',
              size: 12,
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _text(
              context,
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
        context,
        title: 'Build your first results',
        subtitle: 'Answer a question to see your accuracy and activity here.',
        label: 'Try practice',
        icon: Icons.track_changes_rounded,
        onTap: onPractice,
        primary: false,
      );
    }
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              _stat(context, '${p.correct}', 'Correct answers'),
              _stat(context, '${p.attempted}', 'Submitted'),
              _stat(
                context,
                '${((p.accuracy ?? 0) * 100).toStringAsFixed(0)}%',
                'Accuracy',
              ),
              _stat(
                context,
                p.averageSolveTimeMs == null
                    ? '—'
                    : '${(p.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s',
                'Avg. correct time',
                secondary: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _text(
            context,
            'Retries and replays count as submissions. Time uses correct timed-mode answers only.',
            size: 12,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => showAppSheet<void>(
              context: context,
              title: 'By difficulty',
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(
                    context,
                    'Accuracy = correct answers ÷ submissions',
                    size: 16,
                  ),
                  const SizedBox(height: 20),
                  for (final level in ['EASY', 'MEDIUM', 'HARD', 'UNKNOWN'])
                    if (d.difficulty[level] != null) ...[
                      _text(
                        context,
                        level == 'UNKNOWN'
                            ? 'Unclassified history'
                            : '${level[0]}${level.substring(1).toLowerCase()}',
                        color: context.colors.primary,
                      ),
                      const SizedBox(height: 6),
                      _text(
                        context,
                        '${d.difficulty[level]!.correct} correct / ${d.difficulty[level]!.attempted} submitted · ${((d.difficulty[level]!.accuracy ?? 0) * 100).toStringAsFixed(0)}% accuracy',
                      ),
                      const SizedBox(height: 6),
                      _text(
                        context,
                        d.difficulty[level]!.averageSolveTimeMs == null
                            ? 'No valid timed answers yet'
                            : '${(d.difficulty[level]!.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s average correct time',
                        size: 12,
                      ),
                      const SizedBox(height: 20),
                    ],
                  _text(
                    context,
                    'Skipped questions and timeouts do not count as submissions. Lesson answers contribute to accuracy, but have no recorded solve time. Late answers are excluded from time averages.',
                    size: 12,
                  ),
                ],
              ),
            ),
            icon: Icon(Icons.insights_outlined, size: 18),
            label: Text('View difficulty details'),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, HomeBadge b) => _card(
    context,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          b.unlocked
              ? Icons.workspace_premium_rounded
              : Icons.lock_outline_rounded,
          color: b.unlocked
              ? context.colors.secondary
              : context.colors.onSurfaceVariant,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(
                context,
                b.title,
                size: 16,
                color: context.colors.onSurface,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 4),
              _text(context, b.description, size: 14),
              const SizedBox(height: 10),
              if (!b.unlocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: b.target > 0
                        ? (b.progress / b.target).clamp(0, 1)
                        : 0,
                    minHeight: 4,
                    backgroundColor: context.colors.outlineVariant,
                    color: context.colors.primary,
                  ),
                ),
              const SizedBox(height: 4),
              _text(
                context,
                b.unlocked ? 'Earned' : '${b.progress} / ${b.target}',
                size: 12,
                color: b.unlocked
                    ? context.colors.secondary
                    : context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _action(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = true,
  }) => _card(
    context,
    accent: primary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(
          context,
          title,
          size: 18,
          color: context.colors.onSurface,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: 6),
        _text(context, subtitle),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: primary
                  ? context.colors.primary
                  : context.colors.surfaceContainer,
              foregroundColor: primary
                  ? context.colors.onPrimary
                  : context.colors.onSurface,
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

  Widget _heading(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text(
            context,
            title,
            size: 18,
            color: context.colors.onSurface,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 4),
          _text(context, subtitle, size: 12),
        ],
      );
  Widget _stat(
    BuildContext context,
    String value,
    String label, {
    bool secondary = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: context.type.bodyLarge!.copyWith(
          fontSize: secondary ? 18 : 24,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: secondary
              ? context.colors.onSurfaceVariant
              : context.colors.onSurface,
        ),
      ),
      const SizedBox(height: 3),
      _text(context, label, size: 12),
    ],
  );
  Widget _card(
    BuildContext context, {
    required Widget child,
    bool accent = false,
    double padding = 16,
  }) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AptiquRadius.panel),
      border: Border.all(
        color: accent
            ? context.colors.primary.withValues(alpha: .45)
            : context.colors.outlineVariant,
      ),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget _text(
    BuildContext context,
    String text, {
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => Text(
    text,
    style: context.type.bodyMedium!.copyWith(
      fontSize: size,
      height: 1.4,
      color: color ?? context.colors.onSurfaceVariant,
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
            style: context.type.bodyMedium!.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth = math.max(336.0, constraints.maxWidth);
              final firstWeekday =
                  DateTime.parse(entries.first.date).weekday - 1;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final label in [
                            'Mo',
                            'Tu',
                            'We',
                            'Th',
                            'Fr',
                            'Sa',
                            'Su',
                          ])
                            Expanded(
                              child: Center(
                                child: Text(
                                  label,
                                  style: context.type.bodyMedium!.copyWith(
                                    fontSize: 12,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        children: [
                          for (var i = 0; i < firstWeekday; i++)
                            SizedBox(width: gridWidth / 7, height: 48),
                          for (final day in entries)
                            _day(context, day, gridWidth / 7),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showDates(context, entries),
              icon: const Icon(Icons.format_list_bulleted, size: 20),
              label: const Text('View dates as list'),
            ),
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
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 17,
                  color: context.colors.tertiary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Daily Challenge completed',
                    style: context.type.bodyMedium!.copyWith(fontSize: 12),
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
                    border: Border.all(color: context.colors.secondary),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Today',
                  style: context.type.bodyMedium!.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDates(
    BuildContext context,
    List<HomeActivityDay> days,
  ) async {
    final selected = await showAppSheet<HomeActivityDay>(
      context: context,
      title: DateFormat('MMMM yyyy').format(DateTime.parse(days.first.date)),
      builder: (context) => Column(
        children: [
          for (final day in days)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateFormat('EEE, d MMM').format(DateTime.parse(day.date)),
              ),
              subtitle: Text(
                '${day.attempted} submissions · ${day.correct} correct${day.dailyChallengeCompleted ? '\nDaily Challenge completed' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(day),
            ),
        ],
      ),
    );
    if (selected != null && context.mounted) await _showDay(context, selected);
  }

  Future<void> _showDay(
    BuildContext context,
    HomeActivityDay day,
  ) => showAppSheet<void>(
    context: context,
    title: DateFormat('EEE, d MMM yyyy').format(DateTime.parse(day.date)),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          day.attempted == 0
              ? 'No recorded question submissions.'
              : '${day.attempted} answers submitted\n${day.correct} correct',
          style: context.type.bodyLarge,
        ),
        if (day.dailyChallengeCompleted) ...[
          const SizedBox(height: 12),
          Text(
            'Daily Challenge completed',
            style: context.type.bodyLarge!.copyWith(
              color: context.status.warning,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Asia/Kolkata · IST',
          style: context.type.bodyMedium!.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

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
          onTap: () => _showDay(context, day),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: day.attempted == 0
                          ? context.colors.surfaceContainer
                          : Color.lerp(
                              context.colors.surfaceContainer,
                              context.colors.primaryContainer,
                              day.attempted < 5
                                  ? .4
                                  : day.attempted < 15
                                  ? .7
                                  : 1,
                            ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isToday
                            ? context.colors.secondary
                            : context.colors.outlineVariant,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (day.dailyChallengeCompleted)
                  Positioned(
                    top: -4,
                    right: -3,
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 17,
                      color: context.colors.tertiary,
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
  final Widget Function(BuildContext, int, List<HomeActivityDay>)? monthBuilder;
  const YearActivityCalendar({
    super.key,
    required this.days,
    required this.today,
    this.monthBuilder,
  });
  @override
  State<YearActivityCalendar> createState() => _YearActivityCalendarState();
}

class _YearActivityCalendarState extends State<YearActivityCalendar> {
  ScrollController? _scroll;
  late int _monthIndex = DateTime.parse(widget.today).month - 1;
  List<double> _heights = [];
  List<double> _starts = [];
  double? _layoutWidth;
  TextScaler? _layoutScaler;
  static const _monthGap = 24.0;

  @override
  void didUpdateWidget(covariant YearActivityCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.today.substring(0, 7) != widget.today.substring(0, 7)) {
      _monthIndex = DateTime.parse(widget.today).month - 1;
      _layoutWidth = null;
    }
  }

  // Mirror the calendar's actual text, grid and legend layout. This avoids
  // reserving a sixth week (or large-text padding) in a five-week month.
  double _height(BuildContext context, double width, int month) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    Size measure(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textScaler: scaler,
        textDirection: direction,
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final year = DateTime.parse(widget.today).year;
    final first = DateTime(year, month);
    final rows = ((first.weekday - 1 + DateTime(year, month + 1, 0).day) / 7)
        .ceil();
    final title = measure(
      DateFormat('MMMM yyyy').format(first),
      context.type.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      width,
    );
    final weekday = measure(
      'Mo',
      context.type.bodyMedium!.copyWith(fontSize: 12),
      math.max(width, 336) / 7,
    );
    final dateListButton = measure(
      'View dates as list',
      context.type.labelLarge!,
      width - 28,
    );
    final buttonHeight = math.max(48.0, dateListButton.height + 24);
    final legendStyle = context.type.bodyMedium!.copyWith(fontSize: 12);
    final challenge = measure(
      'Daily Challenge completed',
      legendStyle,
      width - 21,
    );
    final today = measure('Today', legendStyle, width - 16);
    final firstHeight = challenge.height > 17 ? challenge.height : 17.0;
    final secondHeight = today.height > 12 ? today.height : 12.0;
    final legendHeight = challenge.width + 21 + 14 + today.width + 16 <= width
        ? (firstHeight > secondHeight ? firstHeight : secondHeight)
        : firstHeight + 8 + secondHeight;
    return (8 +
            title.height +
            12 +
            weekday.height +
            4 +
            rows * 48 +
            8 +
            buttonHeight +
            16 +
            legendHeight)
        .ceilToDouble();
  }

  void _onScroll() {
    final offset = _scroll!.offset;
    var index = 0;
    while (index < 11 && offset >= _starts[index + 1] - .5) {
      index++;
    }
    if (index != _monthIndex) setState(() => _monthIndex = index);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final day in widget.days) day.date: day};
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        if (_layoutWidth != constraints.maxWidth || _layoutScaler != scaler) {
          final monthToKeep = _monthIndex;
          _layoutWidth = constraints.maxWidth;
          _layoutScaler = scaler;
          _heights = List.generate(
            12,
            (i) => _height(context, constraints.maxWidth, i + 1),
          );
          var offset = 0.0;
          _starts = List.generate(12, (i) {
            final start = offset;
            offset += _heights[i] + _monthGap;
            return start;
          });
          if (_scroll != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scroll!.hasClients) {
                _scroll!.jumpTo(
                  _starts[monthToKeep].clamp(
                    0.0,
                    _scroll!.position.maxScrollExtent,
                  ),
                );
              }
            });
          }
        }
        _scroll ??= ScrollController(initialScrollOffset: _starts[_monthIndex])
          ..addListener(_onScroll);
        return SizedBox(
          height: _heights[_monthIndex],
          child: Scrollbar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              primary: false,
              // Keep compatibility with Flutter versions before scrollCacheExtent.
              // ignore: deprecated_member_use
              cacheExtent: 0,
              itemExtentBuilder: (index, _) =>
                  _heights[index] + (index == 11 ? 0 : _monthGap),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final year = DateTime.parse(widget.today).year;
                final days = List.generate(DateTime(year, month + 1, 0).day, (
                  i,
                ) {
                  final key = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime(year, month, i + 1));
                  return byDate[key] ?? HomeActivityDay(key, 0, 0);
                });
                return widget.monthBuilder?.call(context, month, days) ??
                    ActivityCalendar(days: days, today: widget.today);
              },
            ),
          ),
        );
      },
    );
  }
}
