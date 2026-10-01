import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';

/// Senior UI/UX Designed Daily Streak Alert Banner
/// Prominently displays:
/// 1. Real-time countdown timer to 12:00 AM IST midnight reset
/// 2. Clear visual risk warning if an active streak is pending completion
/// 3. Protected status when already completed today
/// 4. Direct CTA navigation to the Daily Challenge Arena
class DailyChallengeStreakBanner extends StatefulWidget {
  const DailyChallengeStreakBanner({super.key});

  @override
  State<DailyChallengeStreakBanner> createState() => _DailyChallengeStreakBannerState();
}

class _DailyChallengeStreakBannerState extends State<DailyChallengeStreakBanner>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemainingTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateRemainingTime() {
    final now = DateTime.now().toUtc();
    // 12:00 AM IST = 18:30 UTC of the previous day
    // Find next 18:30 UTC occurrence
    var targetUtc = DateTime.utc(now.year, now.month, now.day, 18, 30);
    if (!now.isBefore(targetUtc)) {
      targetUtc = targetUtc.add(const Duration(days: 1));
    }

    final diff = targetUtc.difference(now);
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  String _formatRemaining() {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Obx(() {
      final user = authController.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      final isCompleted = user.dailyChallengeCompleted;
      final streakStr = user.streak;
      final streakCount = int.tryParse(streakStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (isCompleted) {
        // State 2: Streak Protected for Today
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF071911),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Streak Secured! 🔥 $streakStr",
                      style: AptiquTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Next challenge unlocks in ${_formatRemaining()} (12:00 AM IST)',
                      style: AptiquTypography.bodySmall.copyWith(
                        color: const Color(0xFF6EE7B7),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // State 1: Daily Challenge is DUE & Streak at Risk!
      final hasStreakAtRisk = streakCount > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF221105),
              Color(0xFF160A03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(AppRoutes.dailyStreak),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Animated Flame Icon with subtle glow
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFFF59E0B),
                            Color(0xFFD97706),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Banner Text Info with Space-Between on top row and separate lines for timer & prompt
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasStreakAtRisk
                              ? '$streakStr Streak at Risk!'
                              : 'Daily Challenge is Live!',
                          style: AptiquTypography.labelLarge.copyWith(
                            color: const Color(0xFFFDE68A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Resets in ${_formatRemaining()}',
                          style: AptiquTypography.bodySmall.copyWith(
                            color: const Color(0xFFFDE68A),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Complete challenge to save streak',
                          style: AptiquTypography.bodySmall.copyWith(
                            color: AptiquColors.onSurfaceVariant,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Chevron indicator confirming entire container is tappable
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
