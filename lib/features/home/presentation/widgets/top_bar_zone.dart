import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/badges/aptiqu_badge.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/routing/app_routes.dart';

/// ZONE 1: TOP 12% SECTION
/// Left: Circular profile image with First Name & Current Level under it
/// Center: Space / between
/// Right: Streak badge (Flame icon first + quantity) & Points badge (Bolt icon first + quantity)
class TopBarZone extends StatelessWidget {
  final double height;

  const TopBarZone({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final xpController = Get.isRegistered<XpController>() ? Get.find<XpController>() : null;

    return Obx(() {
      final user = authController.currentUser.value;
      final xp = xpController?.progress.value;

      final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Shagun';
      final level = xp != null && xp.level > 0 ? xp.level : (user?.level ?? 1);
      final levelProgress = xp != null ? xp.progress : (user?.progress ?? 0.0);
      final streak = user?.streak ?? '0d';
      final coins = user?.coins ?? 0;
      final avatarUrl = user?.avatarUrl.isNotEmpty == true
          ? user!.avatarUrl
          : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80';

      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceDim.withValues(alpha: 0.95),
          border: const Border(
            bottom: BorderSide(
              color: AptiquColors.outlineVariant,
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side: Circular Profile Image with Level Progress Ring + First Name & Level
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.push(AppRoutes.profile);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle circular level progression ring around avatar
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CustomPaint(
                          painter: _AvatarProgressRingPainter(
                            progress: levelProgress,
                          ),
                        ),
                      ),
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AptiquColors.surfaceDim,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
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
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Online Active Indicator Dot
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AptiquColors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AptiquColors.surfaceDim,
                              width: 1.5,
                            ),
                            boxShadow: AptiquColors.secondaryGlow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AptiquTypography.headlineSm.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'LEVEL $level',
                          style: AptiquTypography.labelCaps.copyWith(
                            fontSize: 9,
                            color: AptiquColors.secondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Center: Flexible space automatically handled by spaceBetween

            // Right Side: Streak & Points Badges (both FIRST ICON - then QUANTITY)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Streak Badge (Fire Icon + Quantity)
                AptiquBadge.streak(days: streak),
                const SizedBox(width: 8),
                // Coins Badge (Coins Icon + Quantity)
                AptiquBadge.coins(coins: '$coins'),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Subtle circular progression ring around the avatar
class _AvatarProgressRingPainter extends CustomPainter {
  final double progress;

  _AvatarProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    // Track
    final trackPaint = Paint()
      ..color = AptiquColors.outlineVariant.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, trackPaint);

    // Active Arc
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      final activePaint = Paint()
        ..color = AptiquColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
