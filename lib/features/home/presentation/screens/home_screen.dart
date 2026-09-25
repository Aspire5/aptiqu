import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';
import '../widgets/bottom_nav_zone.dart';
import '../widgets/chat_playground_zone.dart';
import '../widgets/top_bar_zone.dart';

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
    return Container(
      color: AptiquColors.surfaceDim,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Header
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
                'CURRICULUM TRACKS',
                style: AptiquTypography.labelCapsBold.copyWith(
                  color: AptiquColors.primary,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Master quantitative aptitude through conversational AI sessions.',
            style: AptiquTypography.bodySm.copyWith(
              color: AptiquColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // TOPIC 1: RATIO & PROPORTION (LIVE BACKEND LESSON)
          _buildLiveTopicCard(
            context,
            topicSlug: 'math_ratios_101',
            title: 'Foundations of Ratios: Intuition to Mastery',
            topicTag: 'RATIO & PROPORTION • 15 MIN',
            description:
                'Learn the invariance property, part-to-part vs part-to-whole, scaling shortcuts, and mental calculation tricks with our interactive AI Tutor.',
            concepts: ['Scaling Intuition', 'Total Parts', 'Mental Shortcuts'],
            isReady: true,
          ),
          const SizedBox(height: 12),

          // TOPIC 2: PERCENTAGES (UPCOMING)
          _buildLiveTopicCard(
            context,
            topicSlug: 'math_percentages_101',
            title: 'Percentage Multipliers & Mental Conversions',
            topicTag: 'PERCENTAGES • 20 MIN',
            description:
                'Convert fractions to percentages mentally, understand base shifting, and master successive percentage changes.',
            concepts: ['Fraction Bridges', 'Base Changes', 'Successive %'],
            isReady: false,
          ),
          const SizedBox(height: 12),

          // TOPIC 3: SPEED, TIME & DISTANCE (UPCOMING)
          _buildLiveTopicCard(
            context,
            topicSlug: 'math_spd_101',
            title: 'Relative Speed, Trains & Circular Tracks',
            topicTag: 'SPEED & TIME • 25 MIN',
            description:
                'Master relative velocity, train crossings, and average speed without memorizing complicated formulas.',
            concepts: ['Relative Speed', 'Train Crossing', 'Harmonic Mean'],
            isReady: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTopicCard(
    BuildContext context, {
    required String topicSlug,
    required String title,
    required String topicTag,
    required String description,
    required List<String> concepts,
    required bool isReady,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? AptiquColors.primaryContainer.withValues(alpha: 0.8)
              : AptiquColors.outlineVariant.withValues(alpha: 0.6),
          width: isReady ? 1.4 : 1.0,
        ),
        boxShadow: isReady ? AptiquColors.primaryGlow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag Row + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  topicTag,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: isReady ? AptiquColors.secondary : AptiquColors.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReady
                      ? AptiquColors.primaryContainer.withValues(alpha: 0.25)
                      : AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isReady
                        ? AptiquColors.primaryContainer
                        : AptiquColors.outlineVariant,
                  ),
                ),
                child: Text(
                  isReady ? '⚡ LIVE AI TUTOR' : 'COMING SOON',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: isReady ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: AptiquTypography.headlineSm.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            description,
            style: AptiquTypography.bodySm.copyWith(
              color: AptiquColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Concept tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: concepts.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '• $c',
                  style: AptiquTypography.labelCaps.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isReady
                    ? AptiquColors.primaryContainer
                    : AptiquColors.surfaceContainerHigh,
                foregroundColor: isReady ? Colors.white : AptiquColors.onSurfaceDisabled,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isReady ? 3 : 0,
              ),
              onPressed: isReady
                  ? () => context.push('/lesson/$topicSlug')
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isReady ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isReady ? 'Start AI Lesson ➔' : 'Unlocks in Track 2',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AptiquTypography.labelCapsBold.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
