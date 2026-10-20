import '../../../pvp/ranked/ranked_widgets.dart';
import '../../../pvp/ranked/ranked_models.dart';
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
    final completed = user?.dailyChallengeCompleted == true;
    return _card(
      context,
      padding: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onDaily,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.tertiary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: context.colors.tertiary,
            size: 24,
          ),
        ),
        title: _text(
          context,
          completed ? 'Daily Challenge completed!' : 'Daily Challenge is up!',
          color: context.colors.onSurface,
          weight: FontWeight.w600,
          size: 15,
        ),
        subtitle: _text(
          context,
          completed
              ? 'Finished today · see your result'
              : 'Keep your streak going..',
          size: 12,
          color: context.colors.onSurfaceVariant,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _performance(BuildContext context, HomeDashboardModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.performance.attempted == 0)
          _action(
            context,
            title: 'Build your first results',
            subtitle: 'Answer a question to see your accuracy and activity here.',
            label: 'Try practice',
            icon: Icons.track_changes_rounded,
            onTap: onPractice,
            primary: false,
          )
        else
          _QuestionsAndDifficultyCard(
            dashboard: d,
            disableAnimations: MediaQuery.disableAnimationsOf(context),
          ),
        const SizedBox(height: 12),
        _rankedSubSection(context, d),
      ],
    );
  }

  Widget _rankedSubSection(BuildContext context, HomeDashboardModel d) {
    final standing = d.rankedLeague?.summary?.standing;
    final league = standing?.league ?? RankedLeague.unranked;
    final rating = standing?.rating ?? d.rankedDefaultRating ?? 1200;
    final played = standing?.played ?? 0;
    final positionLabel = standing?.position != null
        ? '#${standing!.position}'
        : (d.rankedGlobalRank ?? 'Unranked');
    final percentileLabel = standing?.globalRankPercentile ??
        d.rankedPercentile ??
        (standing?.position != null ? 'Top 15%' : 'Top 50%');

    final isUnplayed = played == 0;

    return _card(
      context,
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RankedBadge(
                league: league,
                size: 52,
                decorative: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          league.label,
                          style: (context.type.titleMedium ?? const TextStyle()).copyWith(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: context.colors.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$rating Elo',
                            style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isUnplayed ? 'Default rating' : 'Ranked rating',
                      style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AptiquRadius.control),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _rankedStatColumn(
                    context,
                    label: 'Global Rank',
                    value: positionLabel,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: context.colors.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _rankedStatColumn(
                    context,
                    label: 'Standing',
                    value: percentileLabel,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: context.colors.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _rankedStatColumn(
                    context,
                    label: 'Matches',
                    value: '$played',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: FilledButton.icon(
              onPressed: onRanked,
              icon: const Icon(Icons.sports_kabaddi_rounded, size: 18),
              label: const Text('Play Ranked Duel'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                minimumSize: const Size(190, 42),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AptiquRadius.control),
                ),
                textStyle: (context.type.labelLarge ?? const TextStyle()).copyWith(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankedStatColumn(
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
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: context.colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (context.type.labelSmall ?? const TextStyle()).copyWith(
            fontSize: 11,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
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

class _QuestionsAndDifficultyCard extends StatefulWidget {
  final HomeDashboardModel dashboard;
  final bool disableAnimations;

  const _QuestionsAndDifficultyCard({
    required this.dashboard,
    this.disableAnimations = false,
  });

  @override
  State<_QuestionsAndDifficultyCard> createState() =>
      _QuestionsAndDifficultyCardState();
}

class _QuestionsAndDifficultyCardState
    extends State<_QuestionsAndDifficultyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;
  bool _hasStarted = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    if (widget.disableAnimations) {
      _animController.value = 1.0;
      _hasStarted = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStart());
    }
  }

  void _checkAndStart() {
    if (_hasStarted || !mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.sizeOf(context).height;
      if (position.dy < screenHeight - 20) {
        _hasStarted = true;
        _scrollPosition?.removeListener(_checkAndStart);
        _scrollPosition = null;
        _animController.forward();
        return;
      }
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null && _scrollPosition != scrollable.position) {
      _scrollPosition?.removeListener(_checkAndStart);
      _scrollPosition = scrollable.position;
      _scrollPosition!.addListener(_checkAndStart);
    } else {
      _hasStarted = true;
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _QuestionsAndDifficultyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations && !_hasStarted) {
      _animController.value = 1.0;
      _hasStarted = true;
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_checkAndStart);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dashboard;
    final p = d.performance;
    final accuracy =
        p.accuracy ?? (p.attempted > 0 ? p.correct / p.attempted : 0.0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = widget.disableAnimations ? 1.0 : _animation.value;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AptiquRadius.panel),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Question Accuracy',
                      style:
                          (context.type.titleSmall ?? const TextStyle()).copyWith(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1.0);
                  final isCompact = constraints.maxWidth < 290 || scale > 1.25;

                  if (isCompact) {
                    return Column(
                      children: [
                        Center(
                          child: AnimatedAccuracyDonutChart(
                            accuracy: accuracy,
                            correct: p.correct,
                            total: p.attempted,
                            size: 96,
                            animationProgress: progress,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _chartStatRow(
                              context,
                              indicatorColor: const Color(0xFF10B981),
                              value: '${p.correct}',
                              label: 'Correct',
                            ),
                            _chartStatRow(
                              context,
                              indicatorColor: context.colors.primary,
                              value: '${p.attempted}',
                              label: 'Submitted',
                            ),
                            _chartStatRow(
                              context,
                              indicatorColor: const Color(0xFFF59E0B),
                              value: p.averageSolveTimeMs == null
                                  ? '—'
                                  : '${(p.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s',
                              label: 'Avg. time',
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      AnimatedAccuracyDonutChart(
                        accuracy: accuracy,
                        correct: p.correct,
                        total: p.attempted,
                        size: 104,
                        animationProgress: progress,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _chartStatRow(
                              context,
                              indicatorColor: const Color(0xFF10B981),
                              value: '${p.correct}',
                              label: 'Correct answers',
                            ),
                            const SizedBox(height: 10),
                            _chartStatRow(
                              context,
                              indicatorColor: context.colors.primary,
                              value: '${p.attempted}',
                              label: 'Total submitted',
                            ),
                            const SizedBox(height: 10),
                            _chartStatRow(
                              context,
                              indicatorColor: const Color(0xFFF59E0B),
                              value: p.averageSolveTimeMs == null
                                  ? '—'
                                  : '${(p.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s',
                              label: 'Avg. solve time',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Divider(
                color: context.colors.outlineVariant.withValues(alpha: 0.35),
                height: 1,
              ),
              const SizedBox(height: 14),
              _difficultyBreakdown(
                context,
                d,
                animationProgress: progress,
              ),
              const SizedBox(height: 10),
              Text(
                'Retries and replays count as submissions · Timed mode only',
                style: (context.type.bodySmall ?? const TextStyle()).copyWith(
                  fontSize: 11,
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chartStatRow(
    BuildContext context, {
    required Color indicatorColor,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: (context.type.titleMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                color: context.colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _difficultyBreakdown(
    BuildContext context,
    HomeDashboardModel d, {
    required double animationProgress,
  }) {
    const levels = ['EASY', 'MEDIUM', 'HARD'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Difficulty Breakdown',
                style: (context.type.titleSmall ?? const TextStyle()).copyWith(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Accuracy · Time',
              style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                fontSize: 11,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final level in levels) ...[
          _difficultyBarRow(
            context,
            level: level,
            data: d.difficulty[level],
            animationProgress: animationProgress,
          ),
          if (level != levels.last) const SizedBox(height: 10),
        ],
        if (d.difficulty['UNKNOWN'] != null &&
            d.difficulty['UNKNOWN']!.attempted > 0) ...[
          const SizedBox(height: 10),
          _difficultyBarRow(
            context,
            level: 'UNKNOWN',
            data: d.difficulty['UNKNOWN'],
            animationProgress: animationProgress,
          ),
        ],
      ],
    );
  }

  Widget _difficultyBarRow(
    BuildContext context, {
    required String level,
    required HomePerformance? data,
    required double animationProgress,
  }) {
    final String label;
    final Color accent;
    switch (level) {
      case 'EASY':
        label = 'Easy';
        accent = const Color(0xFF10B981);
      case 'MEDIUM':
        label = 'Medium';
        accent = const Color(0xFFF59E0B);
      case 'HARD':
        label = 'Hard';
        accent = const Color(0xFFF43F5E);
      default:
        label = level;
        accent = context.colors.onSurfaceVariant;
    }

    final attempted = data?.attempted ?? 0;
    final correct = data?.correct ?? 0;
    final accuracy =
        data?.accuracy ?? (attempted > 0 ? correct / attempted : 0.0);
    final timeStr = data?.averageSolveTimeMs != null
        ? '${(data!.averageSolveTimeMs! / 1000).toStringAsFixed(1)}s'
        : '—';

    final targetValue = accuracy.clamp(0.0, 1.0);
    final animatedValue = targetValue * animationProgress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 54),
              child: Text(
                label,
                style: (context.type.labelMedium ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: animatedValue,
                    backgroundColor: context.colors.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 38,
              child: Text(
                attempted > 0 ? '${(accuracy * 100).toInt()}%' : '—',
                textAlign: TextAlign.right,
                style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: context.colors.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Text(
            attempted > 0
                ? '$correct of $attempted correct · $timeStr avg'
                : 'No submissions yet',
            style: (context.type.bodySmall ?? const TextStyle()).copyWith(
              fontSize: 11,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}


class ActivityCalendar extends StatelessWidget {
  final List<HomeActivityDay> days;
  final String? today;
  final bool showMonthHeader;

  const ActivityCalendar({
    super.key,
    required this.days,
    this.today,
    this.showMonthHeader = true,
  });

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
          if (showMonthHeader) ...[
            Text(
              DateFormat('MMMM yyyy').format(DateTime.parse(entries.first.date)),
              style: context.type.bodyMedium!.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final firstWeekday =
                  DateTime.parse(entries.first.date).weekday - 1;
              final cells = <Widget>[
                for (var i = 0; i < firstWeekday; i++)
                  const SizedBox(height: 44),
                for (final day in entries)
                  _day(context, day),
              ];
              while (cells.length % 7 != 0) {
                cells.add(const SizedBox(height: 44));
              }
              final weeks = <List<Widget>>[];
              for (var i = 0; i < cells.length; i += 7) {
                weeks.add(cells.sublist(i, i + 7));
              }

              final isSmallScreen = constraints.maxWidth <= 320.0;
              final gridWidth = isSmallScreen ? 336.0 : constraints.maxWidth;

              Widget content = SizedBox(
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
                    for (final week in weeks)
                      Row(
                        children: [
                          for (final cell in week)
                            Expanded(child: cell),
                        ],
                      ),
                  ],
                ),
              );

              if (isSmallScreen) {
                content = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: content,
                );
              }
              return content;
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

  Widget _day(BuildContext context, HomeActivityDay day) {
    final date = DateTime.parse(day.date);
    final isToday = day.date == today;
    return SizedBox(
      height: 44,
      child: Semantics(
        button: true,
        label:
            '${day.date}: ${day.attempted} submissions, ${day.correct} correct${day.dailyChallengeCompleted ? ', Daily Challenge completed' : ''}',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showDay(context, day),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
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
                      size: 16,
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
  final Axis? scrollDirection;

  const YearActivityCalendar({
    super.key,
    required this.days,
    required this.today,
    this.monthBuilder,
    this.scrollDirection,
  });

  @override
  State<YearActivityCalendar> createState() => _YearActivityCalendarState();
}

class _YearActivityCalendarState extends State<YearActivityCalendar> {
  ScrollController? _scroll;
  PageController? _pageController;
  late int _monthIndex = DateTime.parse(widget.today).month - 1;
  List<double> _heights = [];
  List<double> _starts = [];
  double? _layoutWidth;
  TextScaler? _layoutScaler;
  static const _monthGap = 24.0;

  bool get _isVertical =>
      (widget.scrollDirection ??
          (widget.monthBuilder != null ? Axis.vertical : Axis.horizontal)) ==
      Axis.vertical;

  @override
  void didUpdateWidget(covariant YearActivityCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.today.substring(0, 7) != widget.today.substring(0, 7)) {
      _monthIndex = DateTime.parse(widget.today).month - 1;
      _layoutWidth = null;
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.jumpToPage(_monthIndex);
      }
    }
  }

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
    final isVertical = _isVertical;
    final titleHeight = isVertical
        ? (measure(
            DateFormat('MMMM yyyy').format(first),
            context.type.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
            width,
          ).height + 12)
        : 0.0;

    final colWidth = width > 320.0 ? width / 7 : 336.0 / 7;
    final weekday = measure(
      'Mo',
      context.type.bodyMedium!.copyWith(fontSize: 12),
      colWidth,
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
    return (titleHeight +
            weekday.height +
            4 +
            rows * 44 +
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

  void _goToMonth(int index) {
    if (index < 0 || index > 11) return;
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scroll?.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final day in widget.days) day.date: day};
    final year = DateTime.parse(widget.today).year;

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

        if (_isVertical) {
          _scroll ??=
              ScrollController(initialScrollOffset: _starts[_monthIndex])
                ..addListener(_onScroll);
          return SizedBox(
            height: _heights[_monthIndex],
            child: Scrollbar(
              controller: _scroll,
              child: ListView.builder(
                controller: _scroll,
                primary: false,
                cacheExtent: 0,
                itemExtentBuilder: (index, _) =>
                    _heights[index] + (index == 11 ? 0 : _monthGap),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
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
        }

        // Horizontal scrolling with month navigation header
        _pageController ??= PageController(initialPage: _monthIndex);

        final monthTitle = DateFormat('MMMM yyyy').format(
          DateTime(year, _monthIndex + 1),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous month',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: _monthIndex > 0
                      ? () => _goToMonth(_monthIndex - 1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    monthTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyMedium!.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next month',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: _monthIndex < 11
                      ? () => _goToMonth(_monthIndex + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _heights[_monthIndex],
              child: PageView.builder(
                controller: _pageController,
                itemCount: 12,
                onPageChanged: (index) {
                  if (mounted && _monthIndex != index) {
                    setState(() => _monthIndex = index);
                  }
                },
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final days = List.generate(DateTime(year, month + 1, 0).day, (
                    i,
                  ) {
                    final key = DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime(year, month, i + 1));
                    return byDate[key] ?? HomeActivityDay(key, 0, 0);
                  });
                  final monthWidget =
                      widget.monthBuilder?.call(context, month, days) ??
                      ActivityCalendar(
                        days: days,
                        today: widget.today,
                        showMonthHeader: false,
                      );
                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: monthWidget,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AnimatedAccuracyDonutChart extends StatelessWidget {
  final double accuracy; // 0.0 to 1.0
  final int correct;
  final int total;
  final double size;
  final double? animationProgress;
  final bool animate;

  const AnimatedAccuracyDonutChart({
    super.key,
    required this.accuracy,
    required this.correct,
    required this.total,
    this.size = 104,
    this.animationProgress,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final targetValue = accuracy.clamp(0.0, 1.0);
    final progress = disableAnimations
        ? 1.0
        : (animationProgress ?? (animate ? 1.0 : 0.0)).clamp(0.0, 1.0);
    final animatedAccuracy = targetValue * progress;
    final percentText = '${(animatedAccuracy * 100).round()}%';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutChartPainter(
              accuracy: animatedAccuracy,
              trackColor: context.colors.surfaceContainerHighest,
              correctColor: context.colors.primary,
              incorrectColor: context.colors.error.withValues(alpha: 0.5),
              hasAttempts: total > 0,
              strokeWidth: 10,
            ),
          ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        percentText,
                        style: (context.type.titleLarge ?? const TextStyle()).copyWith(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: context.colors.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Accuracy',
                        style: (context.type.labelSmall ?? const TextStyle()).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double accuracy;
  final Color trackColor;
  final Color correctColor;
  final Color incorrectColor;
  final bool hasAttempts;
  final double strokeWidth;

  _DonutChartPainter({
    required this.accuracy,
    required this.trackColor,
    required this.correctColor,
    required this.incorrectColor,
    required this.hasAttempts,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (!hasAttempts || accuracy <= 0) return;

    // Correct arc
    final sweepAngle = 2 * math.pi * accuracy;
    final correctPaint = Paint()
      ..color = correctColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      correctPaint,
    );
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      oldDelegate.accuracy != accuracy ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.correctColor != correctColor;
}
