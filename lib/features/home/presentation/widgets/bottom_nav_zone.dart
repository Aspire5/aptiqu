import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../../social/social_controller.dart';

/// Home, Topics, Practice, Ranked and Friends navigation.
class BottomNavZone extends StatelessWidget {
  final double height;

  const BottomNavZone({super.key, required this.height});

  static const labels = ['Home', 'Topics', 'Practice', 'Ranked', 'Friends'];
  static bool _twoRows(BuildContext context, double width) {
    if (MediaQuery.textScalerOf(context).scale(12) <= 18) return false;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(fontSize: 12, letterSpacing: 0);
    return labels.any((label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final exceeds = painter.width > width / 5;
      painter.dispose();
      return exceeds;
    });
  }

  static double preferredHeight(BuildContext context, double width) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(fontSize: 12, letterSpacing: 0);
    final twoRows = _twoRows(context, width);
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width / (twoRows ? 3 : 5));
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    return ((labelHeight + 52) * (twoRows ? 2 : 1)).clamp(72, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final selectedIndex = controller.selectedNavIndex.value;

      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: _navigationLayout(context, [
          // 1. HOME
          _buildNavItem(
            context,
            index: 0,
            selectedIndex: selectedIndex,
            label: 'Home',
            icon: Icons.home_rounded,
            onTap: () => controller.selectHomeTab(),
          ),

          // 2. TOPICS
          _buildNavItem(
            context,
            index: 1,
            selectedIndex: selectedIndex,
            label: 'Topics',
            icon: Icons.hub_rounded,
            onTap: () => controller.selectTopicsTab(),
          ),

          // 3. PRACTICE
          _buildNavItem(
            context,
            index: 2,
            selectedIndex: selectedIndex,
            label: 'Practice',
            icon: Icons.sports_esports_rounded,
            onTap: () {
              controller.isFullScreen.value = false;
              controller.selectedNavIndex.value = 2;
            },
          ),

          // 4. RANKED (with cyan notification badge)
          _buildNavItem(
            context,
            index: 3,
            selectedIndex: selectedIndex,
            label: 'Ranked',
            icon: Icons.emoji_events_rounded,
            hasBadge: false,
            onTap: () {
              controller.isFullScreen.value = false;
              controller.selectedNavIndex.value = 3;
            },
          ),
          _buildNavItem(
            context,
            index: 4,
            selectedIndex: selectedIndex,
            label: 'Friends',
            icon: Icons.people_rounded,
            hasBadge:
                Get.isRegistered<SocialController>() &&
                Get.find<SocialController>().friendInvites.isNotEmpty,
            onTap: () {
              controller.isFullScreen.value = false;
              controller.selectedNavIndex.value = 4;
            },
          ),
        ]),
      );
    });
  }

  Widget _navigationLayout(BuildContext context, List<Widget> items) =>
      LayoutBuilder(
        builder: (context, constraints) {
          if (_twoRows(context, constraints.maxWidth)) {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (final item in items.take(3)) Expanded(child: item),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (final item in items.skip(3)) Expanded(child: item),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [for (final item in items) Expanded(child: item)],
          );
        },
      );

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required int selectedIndex,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    final active = index == selectedIndex;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: hasBadge ? '$label, pending friend requests' : label,
      button: true,
      selected: active,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Badge(
                isLabelVisible: hasBadge,
                child: Icon(
                  icon,
                  size: 24,
                  color: active
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
