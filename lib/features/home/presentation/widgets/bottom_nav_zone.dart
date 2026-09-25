import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';

/// ZONE 3: BOTTOM 12% SECTION - 4 OPTIONS NAVIGATION
/// HOME, TOPICS, PRACTICE, RANKED
class BottomNavZone extends StatelessWidget {
  final double height;

  const BottomNavZone({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final selectedIndex = controller.selectedNavIndex.value;

      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceDim.withValues(alpha: 0.96),
          border: const Border(
            top: BorderSide(
              color: AptiquColors.outlineVariant,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. HOME
            _buildNavItem(
              index: 0,
              selectedIndex: selectedIndex,
              label: 'HOME',
              icon: Icons.space_dashboard_rounded,
              onTap: () => controller.selectedNavIndex.value = 0,
            ),

            // 2. TOPICS
            _buildNavItem(
              index: 1,
              selectedIndex: selectedIndex,
              label: 'TOPICS',
              icon: Icons.hub_rounded,
              onTap: () => controller.selectTopicsTab(),
            ),

            // 3. PRACTICE
            _buildNavItem(
              index: 2,
              selectedIndex: selectedIndex,
              label: 'PRACTICE',
              icon: Icons.sports_esports_rounded,
              onTap: () => controller.selectedNavIndex.value = 2,
            ),

            // 4. RANKED (with cyan notification badge)
            _buildNavItem(
              index: 3,
              selectedIndex: selectedIndex,
              label: 'RANKED',
              icon: Icons.emoji_events_rounded,
              hasBadge: true,
              onTap: () => controller.selectedNavIndex.value = 3,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    final isActive = index == selectedIndex;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Top Active Indicator Bar
            Container(
              height: 2.5,
              width: 24,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isActive ? AptiquColors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive ? AptiquColors.primaryGlow : null,
              ),
            ),

            // Icon Container with Cyber Pill Glow on Active
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AptiquColors.primaryContainer.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AptiquColors.primaryContainer.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: isActive
                        ? AptiquColors.primary
                        : AptiquColors.onSurfaceVariant,
                  ),
                ),

                // Cyan Notification Dot on Ranked
                if (hasBadge)
                  Positioned(
                    top: -1,
                    right: 0,
                    child: Container(
                      width: 7,
                      height: 7,
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
            const SizedBox(height: 3),

            // Text Label
            Text(
              label,
              style: AptiquTypography.labelCaps.copyWith(
                fontSize: 9.5,
                color: isActive
                    ? AptiquColors.primary
                    : AptiquColors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
