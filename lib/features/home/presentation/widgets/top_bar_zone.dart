import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/badges/aptiqu_badge.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';

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

    return Obx(() {
      final user = authController.currentUser.value;
      final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'Shagun';
      final level = user?.level ?? 1;
      final streak = user?.streak ?? '0d';
      final coins = user?.coins ?? 0;
      final avatarUrl = user?.avatarUrl.isNotEmpty == true
          ? user!.avatarUrl
          : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80';

      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceDim.withValues(alpha: 0.92),
          border: const Border(
            bottom: BorderSide(
              color: AptiquColors.outlineVariant,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side: Circular Profile Image with Level Progress Ring + First Name & Level
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle circular level progression ring around avatar
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: CustomPaint(
                        painter: _AvatarProgressRingPainter(
                          progress: user?.progress ?? 0.0,
                        ),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AptiquColors.surfaceDim,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                            blurRadius: 10,
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
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Online Active Indicator Dot
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 9,
                        height: 9,
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
                const SizedBox(width: 10),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LEVEL $level',
                        style: AptiquTypography.labelCaps.copyWith(
                          fontSize: 10,
                          color: AptiquColors.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
