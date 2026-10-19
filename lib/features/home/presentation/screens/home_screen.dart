import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:aptiqu/shared/widgets/feedback/app_state_view.dart';
import '../../../social/friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import '../controllers/home_controller.dart';
import '../../../../core/presentation/global_overlay_gate.dart';
import '../../../../core/routing/app_router.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/top_bar_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/constellation_roadmap_view.dart';
import '../widgets/home_dashboard_view.dart';
import '../../../practice/views/practice_catalog_view.dart';
import '../../../pvp/views/pvp_lobby_view.dart';

/// Home dashboard and existing immersive player share stable tab navigation.
/// Existing five destinations and lesson state are preserved.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Obx(() {
      final isFullScreen = controller.isFullScreen.value;

      return AppearanceTheme(
        builder: (context) => GlobalOverlayTask(
          gate: AppRouter.overlayGate,
          active:
              controller.selectedNavIndex.value == 0 &&
              !controller.showHomeDashboard.value,
          child: PopScope(
            canPop: !isFullScreen,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && controller.isFullScreen.value) {
                controller.isFullScreen.value = false;
              }
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                top: !isFullScreen,
                bottom: !isFullScreen,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalHeight = constraints.maxHeight;
                    final topZoneHeight =
                        24.0 +
                        MediaQuery.textScalerOf(context).scale(16) * 1.35 +
                        MediaQuery.textScalerOf(context).scale(12) * 1.4;
                    final bottomZoneHeight = BottomNavZone.preferredHeight(
                      context,
                      constraints.maxWidth,
                    );

                    return Column(
                      children: [
                        if (!isFullScreen) TopBarZone(height: topZoneHeight),

                        // ZONE 2: CENTER - Expands to 100% in Fullscreen
                        Expanded(
                          key: const ValueKey('home-content'),
                          child: Obx(() {
                            final currentTab =
                                controller.selectedNavIndex.value;
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
                              return const FriendsScreen(embedded: true);
                            }
                          }),
                        ),

                        if (!isFullScreen)
                          BottomNavZone(height: bottomZoneHeight),
                      ],
                    );
                  },
                ),
              ),
            ),
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
        return const Center(
          child: AppStateView(
            title: 'No subjects yet',
            message: 'New topics will appear here when they are available.',
          ),
        );
      }

      if (isLoading && learningMap == null) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(
            child: AppStateView(title: 'Loading topics', loading: true),
          ),
        );
      }

      if (error != null && learningMap == null) {
        return Center(
          child: SingleChildScrollView(
            child: AppStateView(
              title: 'Could not load topics',
              message: error,
              actionLabel: 'Retry',
              onAction: controller.fetchActiveRoadmap,
            ),
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
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: AppLoader()),
      );
    });
  }
}
