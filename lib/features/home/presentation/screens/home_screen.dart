import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import '../../../social/friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/top_bar_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/constellation_roadmap_view.dart';
import '../widgets/home_dashboard_view.dart';
import '../../../practice/views/practice_catalog_view.dart';
import '../../../pvp/views/pvp_lobby_view.dart';

/// Home dashboard and existing immersive player share stable tab navigation.
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
              // 3 Zones allocation: Top (reduced by 30%), Center, Bottom
              final topZoneHeight = (totalHeight * 0.084).clamp(50.0, 62.0);
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
                        if (controller.showHomeDashboard.value) {
                          return const HomeDashboardView();
                        }
                        if (controller.isOpeningLesson.value) {
                          return const Center(child: AppLoader());
                        }
                        return ChatPlaygroundZone(
                          height:
                              totalHeight -
                              (isFullScreen ? 0 : topZoneHeight) -
                              (isFullScreen ? 0 : bottomZoneHeight),
                        );
                      } else if (currentTab == 1) {
                        return _buildTopicsTab(context, isFullScreen);
                      } else if (currentTab == 2) {
                        return const PracticeCatalogView();
                      } else if (currentTab == 3) {
                        return const PvpLobbyView();
                      } else {
                        return const FriendsScreen();
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
      final cachedMap = controller.subjectLearningMap.value;
      final learningMap = cachedMap?.subjectId == selectedSubjId
          ? cachedMap
          : null;
      final isLoading = controller.isLoadingMap.value;
      final error = controller.roadmapError.value;
      final cameraTrigger = controller.topicsTabTapCount.value;

      if (subjects.isEmpty && controller.activeRoadmap.value != null) {
        return const Center(child: Text('No subjects are available yet.'));
      }

      if (isLoading && learningMap == null) {
        return Container(
          color: AptiquColors.surfaceDim,
          child: const Center(child: AppLoader()),
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
              const Icon(
                Icons.cloud_off_outlined,
                color: Colors.amberAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load curriculum map.',
                style: AptiquTypography.headlineSm.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                ),
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
        return Column(
          children: [
            if (isLoading) const LinearProgressIndicator(),
            if (error != null)
              MaterialBanner(
                content: const Text('Progress could not be refreshed.'),
                actions: [
                  TextButton(
                    onPressed: controller.fetchActiveRoadmap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: ConstellationRoadmapView(
                learningMap: learningMap,
                subjects: subjects,
                selectedSubjectId: selectedSubjId,
                cameraTrigger: cameraTrigger,
                isFullScreen: isFullScreen,
                onToggleFullScreen: () => controller.toggleFullScreen(),
                onSelectSubject: (subjId) => controller.selectSubject(subjId),
                onTopicTap: (topic) => controller.onTopicTapped(context, topic),
                onRefresh: () => controller.fetchActiveRoadmap(),
              ),
            ),
          ],
        );
      }

      return Container(
        color: AptiquColors.surfaceDim,
        child: const Center(child: AppLoader()),
      );
    });
  }
}
