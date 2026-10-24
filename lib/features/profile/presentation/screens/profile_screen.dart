import '../../../pvp/ranked/ranked_widgets.dart';
import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../shared/widgets/feedback/app_state_view.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../widgets/appearance_setting.dart';
import '../widgets/feedback_settings.dart';
import '../../../../shared/widgets/layout/text_fit.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/progression/controllers/xp_controller.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  final bool autoFetch;

  const ProfileScreen({super.key, this.autoFetch = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isSigningOut = false;
  bool _logoutDialogOpen = false;
  String? _refreshError;
  String? _logoutError;
  UserStatsModel? _stats;
  late final Future<PackageInfo?> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = _loadPackageInfo();
    if (widget.autoFetch) {
      _fetchFreshProfileAndStats();
    }
  }

  Future<void> _fetchFreshProfileAndStats() async {
    if (_isLoading || _isSigningOut) return;
    final auth = Get.find<AuthController>();
    final accountId = auth.currentUser.value?.id;
    setState(() {
      _isLoading = true;
      _refreshError = null;
    });
    try {
      final dioClient = Get.find<DioClient>();
      final response = await dioClient.dio.get('/user/profile');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final updatedUser = UserModel.fromJson(data);
        if (!mounted || auth.currentUser.value?.id != accountId) return;
        auth.currentUser.value = updatedUser;
        setState(() => _stats = updatedUser.stats);
      } else {
        throw StateError('Profile unavailable');
      }
    } catch (_) {
      if (mounted && auth.currentUser.value?.id == accountId) {
        setState(() => _refreshError = 'Could not refresh your profile.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(builder: _buildProfile);

  Widget _buildProfile(BuildContext context) {
    final authController = Get.find<AuthController>();
    final xpController = Get.isRegistered<XpController>()
        ? Get.find<XpController>()
        : null;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface.withValues(alpha: 0.95),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.colors.onSurface,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Profile'),
        centerTitle: false,
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: AppLoader(size: 18),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.colors.outlineVariant, height: 1),
        ),
      ),
      body: Obx(() {
        final user = authController.currentUser.value;
        final xp = xpController?.progress.value;

        final firstName = user?.firstName.trim().isNotEmpty == true
            ? user!.firstName.trim()
            : 'Student';
        final lastName = user?.lastName.trim() ?? '';
        final fullName = lastName.isNotEmpty
            ? '$firstName $lastName'
            : firstName;
        final avatarUrl = user?.avatarUrl.isNotEmpty == true
            ? user!.avatarUrl
            : '';

        final level = xp != null && xp.level > 0
            ? xp.level
            : (user?.level ?? 1);
        final currXpInLevel = xp != null
            ? xp.xpIntoCurrentLevel
            : (user?.xpIntoCurrentLevel ?? 0);
        final xpForNext = xp != null
            ? xp.xpRequiredForNextLevel
            : (user?.xpRequiredForNextLevel ?? 20);
        final levelProgress = xp != null
            ? xp.progress
            : (user?.progress ?? 0.0);
        final totalXp = xp != null ? xp.total : (user?.totalXp ?? 0);

        final stats = _stats ?? user?.stats;

        return RefreshIndicator(
          color: context.colors.primary,
          backgroundColor: context.colors.surfaceContainerHigh,
          onRefresh: _fetchFreshProfileAndStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_refreshError != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '$_refreshError${stats != null ? ' Showing saved details.' : ''}',
                                style: context.type.bodyMedium!.copyWith(
                                  color: context.colors.onErrorContainer,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _fetchFreshProfileAndStats,
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      context.colors.onErrorContainer,
                                ),
                                child: const Text('Retry refresh'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildUserHeaderCard(
                      context,
                      fullName: fullName,
                      email: user?.email ?? '',
                      avatarUrl: avatarUrl,
                      level: level,
                      levelProgress: levelProgress,
                    ),
                    const SizedBox(height: 20),
                    const AppearanceSetting(),
                    const SizedBox(height: 24),
                    const FeedbackSettings(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'Ranked this season'),
                    RankedSectionView(
                      section: user?.rankedLeague,
                      expanded: true,
                      openLabel: 'Leaderboard',
                      onRetry: _fetchFreshProfileAndStats,
                      onOpen: () => context.push(AppRoutes.rankedLeaderboard),
                      onHistory: () => context.push(AppRoutes.rankedSeasons),
                    ),
                    const SizedBox(height: 24),
                    _buildProgressGroup(
                      context,
                      xp: _buildXpProgression(
                        context,
                        level: level,
                        currXpInLevel: currXpInLevel,
                        xpForNext: xpForNext,
                        levelProgress: levelProgress,
                        totalXp: totalXp,
                      ),
                      topics: stats == null
                          ? null
                          : _buildTopicsProgress(context, stats.topics),
                    ),
                    const SizedBox(height: 24),
                    if (stats == null)
                      AppStateView(
                        title: _isLoading
                            ? 'Loading statistics'
                            : 'Statistics unavailable',
                        message:
                            'Your topic and question totals will appear when your profile is available.',
                        loading: _isLoading,
                        actionLabel: _isLoading || _refreshError != null
                            ? null
                            : 'Refresh statistics',
                        onAction: _isLoading || _refreshError != null
                            ? null
                            : _fetchFreshProfileAndStats,
                      )
                    else ...[
                      _buildSectionHeader(context, 'Questions solved'),
                      const SizedBox(height: 16),
                      _buildQuestionBreakdown(context, stats.questions),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildAccountSettings(context),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        header: true,
        child: Text(title, style: context.type.titleMedium),
      ),
    );
  }

  Widget _profileSurface(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _buildUserHeaderCard(
    BuildContext context, {
    required String fullName,
    required String email,
    required String avatarUrl,
    required int level,
    required double levelProgress,
  }) {
    final avatar = SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: levelProgress.clamp(0, 1),
            strokeWidth: 3,
            backgroundColor: context.colors.outlineVariant,
            semanticsLabel: 'Level $level progress',
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: CircleAvatar(
              backgroundColor: context.colors.primaryContainer,
              foregroundColor: context.colors.onPrimaryContainer,
              foregroundImage: avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              onForegroundImageError: avatarUrl.isEmpty ? null : (_, __) {},
              child: Text(fullName.characters.first.toUpperCase()),
            ),
          ),
        ],
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fullName, style: context.type.titleLarge),
        if (email.isNotEmpty)
          Text(
            email,
            style: context.type.bodyMedium!.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: Get.isRegistered<XpController>()
              ? () =>
                    Get.find<XpController>().triggerCelebrationForCurrentLevel()
              : null,
          style: TextButton.styleFrom(
            backgroundColor: context.colors.primaryContainer,
            foregroundColor: context.colors.onPrimaryContainer,
            disabledBackgroundColor: context.colors.primaryContainer,
            disabledForegroundColor: context.colors.onPrimaryContainer,
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.military_tech_outlined, size: 20),
          label: Text('LEVEL $level'),
        ),
      ],
    );
    return _profileSurface(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final identityWidth = constraints.maxWidth - 80;
          final stacked =
              !textFits(
                context,
                fullName,
                context.type.titleLarge!,
                identityWidth,
                maxLines: 2,
              ) ||
              !textFits(
                context,
                email,
                context.type.bodyMedium!,
                identityWidth,
                maxLines: 2,
              ) ||
              !textFits(
                context,
                'LEVEL $level',
                context.type.labelLarge!,
                identityWidth - 60,
              );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: avatar),
                    const SizedBox(height: 16),
                    identity,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: identity),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildProgressGroup(
    BuildContext context, {
    required Widget xp,
    Widget? topics,
  }) => _profileSurface(
    context,
    LayoutBuilder(
      builder: (context, constraints) {
        if (topics == null) return xp;
        final columns =
            constraints.maxWidth >= 600 &&
            textFits(
              context,
              'Unique Topics Completed',
              context.type.titleSmall!,
              (constraints.maxWidth - 32) / 2,
            );
        return columns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: xp),
                  const SizedBox(width: 24),
                  Expanded(child: topics),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  xp,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  topics,
                ],
              );
      },
    ),
  );

  Widget _buildXpProgression(
    BuildContext context, {
    required int level,
    required int currXpInLevel,
    required int xpForNext,
    required double levelProgress,
    required int totalXp,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text('Level Progression', style: context.type.titleSmall),
          Text(
            '$totalXp Total XP',
            style: context.type.bodyMedium!.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            '$currXpInLevel / $xpForNext XP',
            style: context.type.titleLarge,
          ),
          Text(
            'Next: Level ${level + 1}',
            style: context.type.bodyMedium!.copyWith(
              color: context.colors.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: levelProgress.clamp(0, 1),
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
        semanticsLabel: 'Level progress',
      ),
      const SizedBox(height: 8),
      Text(
        '${math.max(0, xpForNext - currXpInLevel)} XP needed for Level ${level + 1}',
        style: context.type.bodyMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _buildTopicsProgress(BuildContext context, TopicStatsModel topics) {
    final progress = topics.total > 0
        ? (topics.completed / topics.total).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: context.colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unique Topics Completed',
                style: context.type.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: context.type.bodyMedium!.copyWith(
                color: context.colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '${topics.completed} / ${topics.total}',
              style: context.type.titleLarge,
            ),
            Text(
              'Across all roadmaps',
              style: context.type.bodyMedium!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          semanticsLabel: 'Topics completed',
        ),
      ],
    );
  }

  Widget _buildQuestionBreakdown(
    BuildContext context,
    QuestionStatsModel questions,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = [
        _buildDifficultyRow(
          context,
          label: 'Easy',
          solved: questions.easy.solved,
          total: questions.easy.total,
          color: context.status.success,
          icon: Icons.check_circle_outline_rounded,
        ),
        _buildDifficultyRow(
          context,
          label: 'Medium',
          solved: questions.medium.solved,
          total: questions.medium.total,
          color: context.status.warning,
          icon: Icons.speed_rounded,
        ),
        _buildDifficultyRow(
          context,
          label: 'Hard',
          solved: questions.hard.solved,
          total: questions.hard.total,
          color: context.colors.error,
          icon: Icons.local_fire_department_outlined,
        ),
      ];
      if (constraints.maxWidth >= 600) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              Expanded(child: rows[i]),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            rows[i],
          ],
        ],
      );
    },
  );

  Widget _buildDifficultyRow(
    BuildContext context, {
    required String label,
    required int solved,
    required int total,
    required Color color,
    required IconData icon,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(label, style: context.type.titleSmall),
            ],
          ),
          Text('$solved / $total', style: context.type.bodyMedium),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: total > 0 ? (solved / total).clamp(0, 1) : 0,
        color: color,
        borderRadius: BorderRadius.circular(8),
        semanticsLabel: '$label questions solved',
      ),
    ],
  );

  Widget _buildAccountSettings(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_logoutError != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            _logoutError!,
            style: context.type.bodyMedium!.copyWith(
              color: context.colors.error,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App version', style: context.type.bodyMedium),
              const SizedBox(height: 4),
              FutureBuilder<PackageInfo?>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Text(
                    snapshot.connectionState != ConnectionState.done
                        ? 'Loading version…'
                        : info == null || info.version.isEmpty
                        ? 'Version unavailable'
                        : '${info.version}${info.buildNumber.isEmpty ? '' : ' (Build ${info.buildNumber})'}',
                    style: context.type.bodyMedium!.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _isSigningOut
                ? null
                : () => _showLogoutConfirmationDialog(context),
            icon: const Icon(Icons.logout_rounded),
            label: Text(_isSigningOut ? 'Signing out…' : 'Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    if (_logoutDialogOpen || _isSigningOut) return;
    _logoutDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Sign out?'),
          content: const Text(
            'Your saved progress will be available when you sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
    _logoutDialogOpen = false;
    if (confirmed != true || !mounted) return;
    setState(() {
      _isSigningOut = true;
      _logoutError = null;
    });
    try {
      await Get.find<AuthController>().logout();
      if (context.mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        setState(() => _logoutError = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }
}
