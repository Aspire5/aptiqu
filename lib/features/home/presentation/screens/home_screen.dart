import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/top_bar_zone.dart';

/// Screen 3: Redesigned Home Screen with 3 Strict Zones
/// - Top 12%: Avatar + First Name & Level | Space | Streak & Points Badges
/// - Center 76%: Conversational AI Playground (Ambient drift, mascot chat bubble, interactive card, right user bubble, action dock, floating input field)
/// - Bottom 12%: Streamlined 4-option Nav (HOME, TOPICS, PRACTICE, RANKED)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            // 3 Zones allocation: 12% Top, 76% Center, 12% Bottom
            final topZoneHeight = (totalHeight * 0.12).clamp(68.0, 92.0);
            final bottomZoneHeight = (totalHeight * 0.12).clamp(62.0, 84.0);
            final centerZoneHeight = totalHeight - topZoneHeight - bottomZoneHeight;

            return Column(
              children: [
                // ZONE 1: TOP 12%
                TopBarZone(height: topZoneHeight),

                // ZONE 2: CENTER 76%
                Expanded(
                  child: Obx(() {
                    final currentTab = controller.selectedNavIndex.value;
                    if (currentTab == 0) {
                      return ChatPlaygroundZone(height: centerZoneHeight);
                    } else {
                      return _buildSecondaryTabPlaceholder(currentTab);
                    }
                  }),
                ),

                // ZONE 3: BOTTOM 12%
                BottomNavZone(height: bottomZoneHeight),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSecondaryTabPlaceholder(int tabIndex) {
    final titles = ['Home', 'Aptitude Topics', 'Speed Practice', 'Ranked Arena'];
    final subtitles = [
      'Conversational AI Playground',
      'Quantitative, Logical & Analytical Reasoning Mastery Tracks',
      'Daily timed drills, formula flashcards & custom speed challenges',
      'Global leaderboard, tier promotions & weekly tournament',
    ];
    final icons = [
      Icons.space_dashboard_rounded,
      Icons.hub_rounded,
      Icons.sports_esports_rounded,
      Icons.emoji_events_rounded,
    ];

    return Container(
      color: AptiquColors.surfaceDim,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AptiquColors.primaryContainer.withValues(alpha: 0.15),
              border: Border.all(
                color: AptiquColors.primaryContainer,
                width: 1.5,
              ),
              boxShadow: AptiquColors.primaryGlow,
            ),
            child: Icon(
              icons[tabIndex],
              size: 34,
              color: AptiquColors.secondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            titles[tabIndex],
            style: AptiquTypography.headlineMd.copyWith(
              color: AptiquColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitles[tabIndex],
            textAlign: TextAlign.center,
            style: AptiquTypography.bodyMd.copyWith(
              color: AptiquColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AptiquColors.outlineVariant),
            ),
            child: Text(
              'COMING SOON IN PHASE 2',
              style: AptiquTypography.labelCapsBold.copyWith(
                fontSize: 10,
                color: AptiquColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
