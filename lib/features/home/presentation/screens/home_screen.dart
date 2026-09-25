import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/top_bar_zone.dart';
import '../widgets/learning_map_topic_card.dart';

/// Screen 3: Redesigned Home Screen with 3 Strict Zones
/// - Top 12%: Avatar + First Name & Level | Space | Streak & Points Badges
/// - Center 76%: Conversational AI Playground / Topics Directory
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
                    } else if (currentTab == 1) {
                      return _buildTopicsTab(context);
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

  /// Interactive Curriculum Directory (TOPICS Tab)
  Widget _buildTopicsTab(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Obx(() {
      final activeRoadmap = controller.activeRoadmap.value;
      final subjects = controller.subjects;
      final selectedSubjId = controller.selectedSubjectId.value;
      final learningMap = controller.subjectLearningMap.value;
      final isLoading = controller.isLoadingMap.value;
      final error = controller.roadmapError.value;

      return Container(
        color: AptiquColors.surfaceDim,
        child: RefreshIndicator(
          color: AptiquColors.primary,
          backgroundColor: AptiquColors.surfaceContainer,
          onRefresh: () async {
            await controller.fetchActiveRoadmap();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Header Row: Tag + Active Roadmap Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AptiquColors.primary,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: AptiquColors.primaryGlow,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeRoadmap != null
                            ? activeRoadmap.name.toUpperCase()
                            : 'GENERAL APTITUDE',
                        style: AptiquTypography.labelCapsBold.copyWith(
                          color: AptiquColors.primary,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AptiquColors.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AptiquColors.primaryContainer),
                    ),
                    child: Text(
                      'ACTIVE ROADMAP',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        color: AptiquColors.primary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select a subject track to view your structured, milestone-based learning map.',
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),

              // Subject Tabs Selector
              if (subjects.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: subjects.map((subj) {
                      final isSelected = subj.id == selectedSubjId;
                      final isQA = subj.slug.contains('quantitative');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => controller.selectSubject(subj.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AptiquColors.surfaceContainerHigh
                                  : AptiquColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AptiquColors.primary
                                    : AptiquColors.outlineVariant,
                                width: isSelected ? 1.6 : 1.0,
                              ),
                              boxShadow: isSelected ? AptiquColors.primaryGlow : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isQA ? Icons.calculate_outlined : Icons.psychology_outlined,
                                  size: 16,
                                  color: isSelected ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  subj.name,
                                  style: AptiquTypography.bodySm.copyWith(
                                    color: isSelected ? Colors.white : AptiquColors.onSurfaceVariant,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Progress Overview Card
              if (learningMap != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AptiquColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AptiquColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            learningMap.subjectName.toUpperCase(),
                            style: AptiquTypography.labelCapsBold.copyWith(
                              color: AptiquColors.secondary,
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            '${learningMap.completedTopics} of ${learningMap.totalTopics} Completed',
                            style: AptiquTypography.labelCaps.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: learningMap.totalTopics > 0
                              ? learningMap.completedTopics / learningMap.totalTopics
                              : 0.0,
                          backgroundColor: AptiquColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(AptiquColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Loading or Error State
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AptiquColors.primary),
                  ),
                )
              else if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, color: Colors.amberAccent, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load curriculum map.',
                        style: AptiquTypography.bodyMd.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => controller.fetchActiveRoadmap(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (learningMap != null)
                // Ordered Learning Map Topics
                ...learningMap.topics.map(
                  (topic) => LearningMapTopicCard(
                    topic: topic,
                    onTap: () => controller.onTopicTapped(context, topic),
                  ),
                ),
            ],
          ),
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
