import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/progression/controllers/xp_controller.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  UserStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    _fetchFreshProfileAndStats();
  }

  Future<void> _fetchFreshProfileAndStats() async {
    setState(() => _isLoading = true);
    try {
      final dioClient = Get.find<DioClient>();
      final response = await dioClient.dio.get('/user/profile');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final updatedUser = UserModel.fromJson(data);

        if (Get.isRegistered<AuthController>()) {
          Get.find<AuthController>().currentUser.value = updatedUser;
        }

        if (updatedUser.stats != null) {
          setState(() {
            _stats = updatedUser.stats;
          });
        }
      }
    } catch (_) {
      // Fallback silently to existing local stats in AuthController
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final xpController = Get.isRegistered<XpController>() ? Get.find<XpController>() : null;

    return Scaffold(
      backgroundColor: AptiquColors.surface,
      appBar: AppBar(
        backgroundColor: AptiquColors.surfaceDim.withValues(alpha: 0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'PROFILE',
          style: AptiquTypography.labelCapsBold.copyWith(
            fontSize: 14,
            letterSpacing: 1.5,
            color: AptiquColors.onSurfaceVariant,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AptiquColors.primary),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AptiquColors.outlineVariant,
            height: 1,
          ),
        ),
      ),
      body: Obx(() {
        final user = authController.currentUser.value;
        final xp = xpController?.progress.value;

        final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Student';
        final lastName = user?.lastName ?? '';
        final fullName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
        final avatarUrl = user?.avatarUrl.isNotEmpty == true
            ? user!.avatarUrl
            : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80';

        final level = xp != null && xp.level > 0 ? xp.level : (user?.level ?? 1);
        final currXpInLevel = xp != null ? xp.xpIntoCurrentLevel : (user?.xpIntoCurrentLevel ?? 0);
        final xpForNext = xp != null ? xp.xpRequiredForNextLevel : (user?.xpRequiredForNextLevel ?? 20);
        final levelProgress = xp != null ? xp.progress : (user?.progress ?? 0.0);
        final totalXp = xp != null ? xp.total : (user?.totalXp ?? 0);

        final stats = _stats ?? user?.stats ?? const UserStatsModel();

        return RefreshIndicator(
          color: AptiquColors.primary,
          backgroundColor: AptiquColors.surfaceContainerHigh,
          onRefresh: _fetchFreshProfileAndStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. User Identity Header Card
                _buildUserHeaderCard(
                  fullName: fullName,
                  email: user?.email ?? '',
                  avatarUrl: avatarUrl,
                  level: level,
                  levelProgress: levelProgress,
                ),

                const SizedBox(height: 20),

                // 2. Current Level & XP Progression Card
                _buildXpProgressionCard(
                  level: level,
                  currXpInLevel: currXpInLevel,
                  xpForNext: xpForNext,
                  levelProgress: levelProgress,
                  totalXp: totalXp,
                ),

                const SizedBox(height: 24),

                // 3. Unique Topics Completed Across All Roadmaps
                _buildSectionHeader('ROADMAP PROGRESS'),
                const SizedBox(height: 10),
                _buildTopicsProgressCard(stats.topics),

                const SizedBox(height: 24),

                // 4. Questions Solved By Difficulty (Easy / Medium / Hard)
                _buildSectionHeader('QUESTIONS SOLVED'),
                const SizedBox(height: 10),
                _buildQuestionsSolvedCard(stats.questions),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AptiquTypography.labelCapsBold.copyWith(
          fontSize: 12,
          letterSpacing: 1.2,
          color: AptiquColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard({
    required String fullName,
    required String email,
    required String avatarUrl,
    required int level,
    required double levelProgress,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Avatar with Progress Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  painter: _AvatarProgressRingPainter(
                    progress: levelProgress,
                    strokeWidth: 3.5,
                  ),
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AptiquColors.surfaceDim, width: 2),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AptiquColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.person_rounded,
                        color: AptiquColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: AptiquTypography.headlineMd.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: AptiquTypography.bodyMd.copyWith(
                      fontSize: 13,
                      color: AptiquColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AptiquColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AptiquColors.secondary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 14,
                        color: AptiquColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LEVEL $level',
                        style: AptiquTypography.labelCapsBold.copyWith(
                          fontSize: 11,
                          color: AptiquColors.secondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpProgressionCard({
    required int level,
    required int currXpInLevel,
    required int xpForNext,
    required double levelProgress,
    required int totalXp,
  }) {
    final clampedProgress = levelProgress.clamp(0.0, 1.0);
    final xpNeeded = math.max(0, xpForNext - currXpInLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AptiquColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AptiquColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Level Progression',
                    style: AptiquTypography.headlineSm.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '$totalXp Total XP',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currXpInLevel / $xpForNext XP',
                style: AptiquTypography.headlineMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Next: Level ${level + 1}',
                style: AptiquTypography.labelCapsBold.copyWith(
                  fontSize: 12,
                  color: AptiquColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AptiquColors.surfaceContainerHigh,
                ),
                FractionallySizedBox(
                  widthFactor: clampedProgress,
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AptiquColors.primary,
                          AptiquColors.secondary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$xpNeeded XP needed for Level ${level + 1}',
            style: AptiquTypography.bodyMd.copyWith(
              fontSize: 12,
              color: AptiquColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsProgressCard(TopicStatsModel topics) {
    final progress = topics.total > 0 ? (topics.completed / topics.total).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Color(0xFF818CF8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Unique Topics Completed',
                    style: AptiquTypography.headlineSm.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct%',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${topics.completed}',
                style: AptiquTypography.headlineMd.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${topics.total} Topics across all roadmaps',
                style: AptiquTypography.bodyMd.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AptiquColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSolvedCard(QuestionStatsModel questions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AptiquColors.outlineVariant),
      ),
      child: Column(
        children: [
          _buildDifficultyRow(
            label: 'Easy',
            solved: questions.easy.solved,
            total: questions.easy.total,
            color: const Color(0xFF10B981), // Emerald
            icon: Icons.check_circle_outline_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AptiquColors.outlineVariant, height: 1),
          ),
          _buildDifficultyRow(
            label: 'Medium',
            solved: questions.medium.solved,
            total: questions.medium.total,
            color: const Color(0xFFF59E0B), // Amber
            icon: Icons.speed_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AptiquColors.outlineVariant, height: 1),
          ),
          _buildDifficultyRow(
            label: 'Hard',
            solved: questions.hard.solved,
            total: questions.hard.total,
            color: const Color(0xFFEF4444), // Red
            icon: Icons.local_fire_department_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyRow({
    required String label,
    required int solved,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final progress = total > 0 ? (solved / total).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AptiquTypography.headlineSm.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$solved / $total',
                    style: AptiquTypography.labelCapsBold.copyWith(
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AptiquColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular level progression ring painter around avatar
class _AvatarProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _AvatarProgressRingPainter({
    required this.progress,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = AptiquColors.outlineVariant.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0.0) return;

    // Active progress arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          AptiquColors.primary,
          AptiquColors.secondary,
        ],
        startAngle: 0.0,
        endAngle: 2 * math.pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
