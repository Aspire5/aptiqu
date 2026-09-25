import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/top_bar_zone.dart';
import '../widgets/constellation_roadmap_view.dart';

/// Screen 3: Redesigned Home Screen with 3 Strict Zones
/// - Top 12%: Avatar + First Name & Level | Space | Streak & Points Badges
/// - Center 76%: Conversational AI Playground / Topics Directory
/// - Bottom 12%: Streamlined 4-option Nav (HOME, TOPICS, PRACTICE, RANKED)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Obx(() {
      final isFullScreen = controller.isFullScreen.value;

      return Scaffold(
        backgroundColor: AptiquColors.surfaceDim,
        body: SafeArea(
          top: !isFullScreen,
          bottom: !isFullScreen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalHeight = constraints.maxHeight;
              // 3 Zones allocation: 12% Top, 76% Center, 12% Bottom
              final topZoneHeight = (totalHeight * 0.12).clamp(68.0, 92.0);
              final bottomZoneHeight = (totalHeight * 0.12).clamp(62.0, 84.0);

              return Column(
                children: [
                  // ZONE 1: TOP 12% - Slides & Fades UPWARDS in Fullscreen
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    height: isFullScreen ? 0.0 : topZoneHeight,
                    child: AnimatedSlide(
                      offset: isFullScreen ? const Offset(0, -1) : Offset.zero,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: AnimatedOpacity(
                        opacity: isFullScreen ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 240),
                        child: OverflowBox(
                          minHeight: topZoneHeight,
                          maxHeight: topZoneHeight,
                          alignment: Alignment.topCenter,
                          child: TopBarZone(height: topZoneHeight),
                        ),
                      ),
                    ),
                  ),

                  // ZONE 2: CENTER - Expands to 100% in Fullscreen
                  Expanded(
                    child: Obx(() {
                      final currentTab = controller.selectedNavIndex.value;
                      if (currentTab == 0) {
                        return ChatPlaygroundZone(
                          height: totalHeight -
                              (isFullScreen ? 0 : topZoneHeight) -
                              (isFullScreen ? 0 : bottomZoneHeight),
                        );
                      } else if (currentTab == 1) {
                        return _buildTopicsTab(context, isFullScreen);
                      } else {
                        return _buildSecondaryTabPlaceholder(currentTab);
                      }
                    }),
                  ),

                  // ZONE 3: BOTTOM 12% - Slides & Fades DOWNWARDS in Fullscreen
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    height: isFullScreen ? 0.0 : bottomZoneHeight,
                    child: AnimatedSlide(
                      offset: isFullScreen ? const Offset(0, 1) : Offset.zero,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: AnimatedOpacity(
                        opacity: isFullScreen ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 240),
                        child: OverflowBox(
                          minHeight: bottomZoneHeight,
                          maxHeight: bottomZoneHeight,
                          alignment: Alignment.bottomCenter,
                          child: BottomNavZone(height: bottomZoneHeight),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }

  /// Interactive Curriculum Directory (TOPICS Tab with Zoomable Constellation Roadmap)
  Widget _buildTopicsTab(BuildContext context, bool isFullScreen) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final subjects = controller.subjects;
      final selectedSubjId = controller.selectedSubjectId.value;
      final learningMap = controller.subjectLearningMap.value;
      final isLoading = controller.isLoadingMap.value;
      final error = controller.roadmapError.value;
      final cameraTrigger = controller.topicsTabTapCount.value;

      if (isLoading && learningMap == null) {
        return Container(
          color: AptiquColors.surfaceDim,
          child: const Center(
            child: CircularProgressIndicator(color: AptiquColors.primary),
          ),
        );
      }

      if (error != null && learningMap == null) {
        return Container(
          color: AptiquColors.surfaceDim,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: Colors.amberAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Failed to load curriculum map.',
                style: AptiquTypography.headlineSm.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AptiquTypography.bodySm.copyWith(color: AptiquColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.primary,
                  foregroundColor: AptiquColors.onPrimary,
                ),
                onPressed: () => controller.fetchActiveRoadmap(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      if (learningMap != null) {
        return ConstellationRoadmapView(
          learningMap: learningMap,
          subjects: subjects,
          selectedSubjectId: selectedSubjId,
          cameraTrigger: cameraTrigger,
          isFullScreen: isFullScreen,
          onToggleFullScreen: () => controller.toggleFullScreen(),
          onSelectSubject: (subjId) => controller.selectSubject(subjId),
          onTopicTap: (topic) => controller.onTopicTapped(context, topic),
          onRefresh: () => controller.fetchActiveRoadmap(),
        );
      }

      return Container(
        color: AptiquColors.surfaceDim,
        child: const Center(
          child: CircularProgressIndicator(color: AptiquColors.primary),
        ),
      );
    });
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
