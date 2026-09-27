import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/practice_catalog_controller.dart';

class PracticeCatalogView extends StatelessWidget {
  const PracticeCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PracticeCatalogController>()
        ? Get.find<PracticeCatalogController>()
        : Get.put(PracticeCatalogController());

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AptiquColors.primary),
        );
      }

      if (controller.errorMessage.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AptiquColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.fetchLiveTopics,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AptiquColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: AptiquColors.surfaceDim,
        child: Column(
          children: [
            // 1. Header Zone & Mode Selector Tabs
            _buildHeaderAndModeTabs(context, controller),

            // 2. Mode-Specific Content
            Expanded(
              child: Obx(() {
                final mode = controller.selectionMode.value;
                if (mode == PracticeSelectionMode.random) {
                  return _buildRandomModeCard(context, controller);
                } else {
                  return _buildSpecificModeDirectory(context, controller);
                }
              }),
            ),

            // 3. Persistent Start Practice Bottom Action Bar
            _buildBottomActionBar(controller),
          ],
        ),
      );
    });
  }

  /// Header with Mode Tabs (Random vs Specific)
  Widget _buildHeaderAndModeTabs(BuildContext context, PracticeCatalogController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: AptiquColors.surfaceDim,
        border: Border(bottom: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AptiquColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports_esports_rounded, color: AptiquColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speed Practice Arena',
                      style: AptiquTypography.titleMedium.copyWith(
                        color: AptiquColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sharpen your aptitude with targeted 10-question drills',
                      style: AptiquTypography.bodySmall.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cyber Segmented Mode Switcher (Random vs Specific)
          Obx(() {
            final isRandom = controller.selectionMode.value == PracticeSelectionMode.random;

            return Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AptiquColors.outlineVariant, width: 1),
              ),
              child: Row(
                children: [
                  // Option 1: RANDOM
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => controller.selectionMode.value = PracticeSelectionMode.random,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isRandom ? AptiquColors.primaryContainer.withValues(alpha: 0.28) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: isRandom ? Border.all(color: AptiquColors.primary.withValues(alpha: 0.5)) : null,
                          boxShadow: isRandom ? AptiquColors.primaryGlow : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              size: 16,
                              color: isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Random Drill',
                              style: AptiquTypography.labelMedium.copyWith(
                                color: isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                                fontWeight: isRandom ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Option 2: SPECIFIC
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => controller.selectionMode.value = PracticeSelectionMode.specific,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: !isRandom ? AptiquColors.primaryContainer.withValues(alpha: 0.28) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: !isRandom ? Border.all(color: AptiquColors.primary.withValues(alpha: 0.5)) : null,
                          boxShadow: !isRandom ? AptiquColors.primaryGlow : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              size: 16,
                              color: !isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Specific Topics',
                              style: AptiquTypography.labelMedium.copyWith(
                                color: !isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                                fontWeight: !isRandom ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Option 1: RANDOM MODE VIEW
  Widget _buildRandomModeCard(BuildContext context, PracticeCatalogController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AptiquColors.primaryContainer.withValues(alpha: 0.12),
                  AptiquColors.surfaceContainerLowest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AptiquColors.primary.withValues(alpha: 0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AptiquColors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AptiquColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AptiquColors.secondary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full-Curriculum Random Drill',
                            style: AptiquTypography.headlineSm.copyWith(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Balanced questions from all live topics',
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Test your mental agility across varied topics. Questions are drawn randomly from across all live curriculum scripts with zero setup needed.',
                  style: AptiquTypography.bodyMedium.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Key Specs Cards
                Row(
                  children: [
                    _buildSpecPill(
                      icon: Icons.timer_outlined,
                      title: '10 Questions',
                      subtitle: 'Fast-paced drill',
                    ),
                    const SizedBox(width: 10),
                    _buildSpecPill(
                      icon: Icons.hub_rounded,
                      title: '${controller.totalLiveSubtopicsCount} Subtopics',
                      subtitle: 'In active pool',
                      isAccent: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Available Live Subjects Summary Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AptiquColors.outlineVariant, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Live Topics in Random Pool',
                      style: AptiquTypography.labelMedium.copyWith(
                        color: AptiquColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...controller.liveTopics.map((topic) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AptiquColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            topic.topicName,
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${topic.subtopics.length} subtopics',
                          style: AptiquTypography.labelSmall.copyWith(
                            color: AptiquColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecPill({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isAccent = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isAccent
              ? AptiquColors.secondary.withValues(alpha: 0.08)
              : AptiquColors.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAccent ? AptiquColors.secondary.withValues(alpha: 0.3) : AptiquColors.outlineVariant,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isAccent ? AptiquColors.secondary : AptiquColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AptiquTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AptiquTypography.labelSmall.copyWith(
                      color: AptiquColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Option 2: SPECIFIC MODE VIEW (Hierarchical Subject -> Topic -> Subtopics)
  Widget _buildSpecificModeDirectory(BuildContext context, PracticeCatalogController controller) {
    final liveSubjects = controller.liveSubjects;
    final currentTopics = controller.currentSubjectTopics;

    return Column(
      children: [
        // Subject Selector Bar (if there are subjects)
        if (liveSubjects.length > 1)
          Container(
            height: 44,
            margin: const EdgeInsets.only(top: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: liveSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subj = liveSubjects[index];
                return Obx(() {
                  final isSelected = controller.selectedSubjectId.value == subj.id;
                  return ChoiceChip(
                    label: Text(subj.name),
                    selected: isSelected,
                    onSelected: (_) => controller.selectSubject(subj.id),
                    selectedColor: AptiquColors.primaryContainer,
                    backgroundColor: AptiquColors.surfaceContainerLowest,
                    labelStyle: AptiquTypography.labelMedium.copyWith(
                      color: isSelected ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AptiquColors.primary : AptiquColors.outlineVariant,
                      ),
                    ),
                  );
                });
              },
            ),
          ),

        // Quick Select All / Clear Row
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() => Text(
                    '${controller.selectedSubtopicIds.length} subtopics selected',
                    style: AptiquTypography.labelMedium.copyWith(
                      color: AptiquColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  )),
              Row(
                children: [
                  TextButton(
                    onPressed: controller.selectAllCurrentSubject,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Select All',
                      style: AptiquTypography.labelSmall.copyWith(color: AptiquColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.clearSelection,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear',
                      style: AptiquTypography.labelSmall.copyWith(color: AptiquColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Topics and Subtopics List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
            itemCount: currentTopics.length,
            itemBuilder: (context, idx) {
              final topic = currentTopics[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AptiquColors.outlineVariant, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic Header with Checkbox to toggle all subtopics
                    Obx(() {
                      final isFullySelected = controller.isTopicFullySelected(topic.topicId);
                      final isPartiallySelected = controller.isTopicPartiallySelected(topic.topicId);

                      return InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        onTap: () => controller.toggleTopic(topic.topicId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              // Cyber Checkbox
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isFullySelected || isPartiallySelected
                                      ? AptiquColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFullySelected || isPartiallySelected
                                        ? AptiquColors.primary
                                        : AptiquColors.outlineVariant,
                                    width: 1.5,
                                  ),
                                ),
                                child: isFullySelected
                                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                    : isPartiallySelected
                                        ? const Icon(Icons.remove_rounded, size: 16, color: Colors.white)
                                        : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.topicName,
                                      style: AptiquTypography.titleSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      '${topic.subtopics.length} Subtopics',
                                      style: AptiquTypography.labelSmall.copyWith(
                                        color: AptiquColors.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Live Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'LIVE',
                                  style: AptiquTypography.labelSmall.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Subtopics Interactive Chips
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: topic.subtopics.map((sub) {
                          return Obx(() {
                            final isSelected = controller.selectedSubtopicIds.contains(sub.id);
                            return FilterChip(
                              label: Text(sub.name),
                              selected: isSelected,
                              onSelected: (_) => controller.toggleSubtopic(sub.id),
                              backgroundColor: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.5),
                              selectedColor: AptiquColors.primary.withValues(alpha: 0.22),
                              checkmarkColor: AptiquColors.primary,
                              labelStyle: AptiquTypography.bodySmall.copyWith(
                                color: isSelected ? Colors.white : AptiquColors.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 11.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                                side: BorderSide(
                                  color: isSelected ? AptiquColors.primary : AptiquColors.outlineVariant,
                                ),
                              ),
                            );
                          });
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Persistent Bottom Action Button Bar
  Widget _buildBottomActionBar(PracticeCatalogController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceDim,
        border: const Border(top: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Obx(() {
          final isBusy = controller.isStartingSession.value;
          final isRandom = controller.selectionMode.value == PracticeSelectionMode.random;
          final selectedCount = controller.selectedSubtopicIds.length;
          final isEnabled = isRandom || selectedCount > 0;

          final buttonText = isRandom
              ? 'Start Random Practice (10 Questions)'
              : 'Start Practice ($selectedCount Subtopics)';

          return ElevatedButton(
            onPressed: isBusy || !isEnabled ? null : controller.startPracticeSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AptiquColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: AptiquColors.surfaceContainerHigh,
              disabledForegroundColor: AptiquColors.onSurfaceVariant.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isBusy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Preparing Drill...'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRandom ? Icons.shuffle_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: AptiquTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ),
    );
  }
}
