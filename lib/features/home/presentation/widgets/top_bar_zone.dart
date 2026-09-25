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
            // Left Side: Circular Profile Image + First Name & Level
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AptiquColors.primaryContainer.withValues(alpha: 0.8),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                            blurRadius: 12,
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
                              size: 24,
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
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AptiquColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AptiquColors.surfaceDim,
                            width: 2.0,
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
