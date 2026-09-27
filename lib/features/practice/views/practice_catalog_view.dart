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
                const Icon(Icons.error_outline_rounded, color: AptiquColors.error, size: 44),
                const SizedBox(height: 14),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // 1. Sleek Minimal Header & Mode Switcher
            _buildHeaderAndModeTabs(context, controller),

            // 2. Mode Content (Quick Drill vs Custom Curate)
            Expanded(
              child: Obx(() {
                final mode = controller.selectionMode.value;
                if (mode == PracticeSelectionMode.random) {
                  return _buildQuickDrillMode(context, controller);
                } else {
                  return _buildCustomDrillMode(context, controller);
                }
              }),
            ),

            // 3. Persistent Action Bar (guaranteed overflow-free)
            _buildBottomActionBar(controller),
          ],
        ),
      );
    });
  }

  /// Minimalist Header with Segmented Mode Switcher
  Widget _buildHeaderAndModeTabs(BuildContext context, PracticeCatalogController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AptiquColors.outlineVariant),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AptiquColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Practice Arena',
                      style: AptiquTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Adaptive drills and topic mastery sets',
                      style: AptiquTypography.bodySmall.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE ENGINE',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        color: const Color(0xFF10B981),
                        fontSize: 9,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modern Low-Profile Segmented Switcher
          Obx(() {
            final isRandom = controller.selectionMode.value == PracticeSelectionMode.random;

            return Container(
              height: 38,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AptiquColors.outlineVariant, width: 0.8),
              ),
              child: Row(
                children: [
                  // Tab 1: Quick Drill
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.selectionMode.value = PracticeSelectionMode.random,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isRandom ? AptiquColors.surfaceContainerHigh : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isRandom
                              ? Border.all(color: AptiquColors.primary.withValues(alpha: 0.35))
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              size: 14,
                              color: isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Quick Drill',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AptiquTypography.labelMedium.copyWith(
                                  color: isRandom ? Colors.white : AptiquColors.onSurfaceVariant,
                                  fontWeight: isRandom ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab 2: Custom Curate
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.selectionMode.value = PracticeSelectionMode.specific,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: !isRandom ? AptiquColors.surfaceContainerHigh : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: !isRandom
                              ? Border.all(color: AptiquColors.primary.withValues(alpha: 0.35))
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: !isRandom ? AptiquColors.primary : AptiquColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Curate Topics',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AptiquTypography.labelMedium.copyWith(
                                  color: !isRandom ? Colors.white : AptiquColors.onSurfaceVariant,
                                  fontWeight: !isRandom ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
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

  /// Option 1: REDESIGNED MINIMAL QUICK DRILL VIEW (No clunky purple box!)
  Widget _buildQuickDrillMode(BuildContext context, PracticeCatalogController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Overview Card (Clean, Slate, Minimalist)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AptiquColors.outlineVariant, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AptiquColors.secondary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'FULL CURRICULUM DRILL',
                          style: AptiquTypography.labelCapsBold.copyWith(
                            color: AptiquColors.secondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AptiquColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '10 Questions',
                        style: AptiquTypography.labelSmall.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  'Comprehensive Sprint',
                  style: AptiquTypography.headlineSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Instant diagnostic set pulled across all active syllabus topics. Zero setup required.',
                  style: AptiquTypography.bodySmall.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Clean 3-Metric Horizontal Strip
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AptiquColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AptiquColors.outlineVariant, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      _buildMetricItem('10', 'Questions'),
                      _buildVerticalDivider(),
                      _buildMetricItem('Adaptive', 'Difficulty'),
                      _buildVerticalDivider(),
                      _buildMetricItem('${controller.totalLiveSubtopicsCount}', 'Subtopics'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // AI Intelligence Breakdown (Subtle High-Trust Box)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AptiquColors.outlineVariant, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: AptiquColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_outlined, color: AptiquColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Adaptive Set Composition',
                        style: AptiquTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Reserves 2–3 questions focused on patterns you previously missed\n• Introduces 7–8 fresh unseen questions crafted on demand',
                        style: AptiquTypography.bodySmall.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active Curriculum Pool Preview
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE SYLLABUS POOL',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${controller.liveTopics.length} Topics Ready',
                      style: AptiquTypography.labelSmall.copyWith(
                        color: AptiquColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...controller.liveTopics.map((topic) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AptiquColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${topic.subtopics.length} subtopics',
                              style: AptiquTypography.labelSmall.copyWith(
                                color: AptiquColors.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        if (topic.subtopics.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: topic.subtopics.map((sub) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AptiquColors.outlineVariant, width: 0.5),
                                ),
                                child: Text(
                                  sub.name,
                                  style: AptiquTypography.labelSmall.copyWith(
                                    color: AptiquColors.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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

  Widget _buildMetricItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AptiquTypography.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AptiquTypography.labelSmall.copyWith(
              color: AptiquColors.onSurfaceVariant,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AptiquColors.outlineVariant,
    );
  }

  /// Option 2: REDESIGNED CUSTOM TOPIC CURATION VIEW
  Widget _buildCustomDrillMode(BuildContext context, PracticeCatalogController controller) {
    final liveSubjects = controller.liveSubjects;
    final currentTopics = controller.currentSubjectTopics;

    return Column(
      children: [
        // Subject Selector Bar (if multiple subjects exist)
        if (liveSubjects.length > 1)
          Container(
            height: 40,
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => controller.selectSubject(subj.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AptiquColors.surfaceContainerHigh : AptiquColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AptiquColors.primary : AptiquColors.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        subj.name,
                        style: AptiquTypography.labelSmall.copyWith(
                          color: isSelected ? Colors.white : AptiquColors.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),

        // Quick Select All / Clear Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() => Text(
                    '${controller.selectedSubtopicIds.length} subtopics selected',
                    style: AptiquTypography.labelMedium.copyWith(
                      color: AptiquColors.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            itemCount: currentTopics.length,
            itemBuilder: (context, idx) {
              final topic = currentTopics[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AptiquColors.outlineVariant, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic Header with Checkbox to toggle all subtopics
                    Obx(() {
                      final isFullySelected = controller.isTopicFullySelected(topic.topicId);
                      final isPartiallySelected = controller.isTopicPartiallySelected(topic.topicId);

                      return InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        onTap: () => controller.toggleTopic(topic.topicId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isFullySelected || isPartiallySelected
                                      ? AptiquColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isFullySelected || isPartiallySelected
                                        ? AptiquColors.primary
                                        : AptiquColors.outlineVariant,
                                    width: 1.5,
                                  ),
                                ),
                                child: isFullySelected
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : isPartiallySelected
                                        ? const Icon(Icons.remove_rounded, size: 14, color: Colors.white)
                                        : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  topic.topicName,
                                  style: AptiquTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${topic.subtopics.length} subtopics',
                                style: AptiquTypography.labelSmall.copyWith(
                                  color: AptiquColors.onSurfaceVariant,
                                  fontSize: 11,
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
                              label: Text(
                                sub.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: isSelected,
                              onSelected: (_) => controller.toggleSubtopic(sub.id),
                              backgroundColor: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.4),
                              selectedColor: AptiquColors.primary.withValues(alpha: 0.2),
                              checkmarkColor: AptiquColors.primary,
                              labelStyle: AptiquTypography.bodySmall.copyWith(
                                color: isSelected ? Colors.white : AptiquColors.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected ? AptiquColors.primary : AptiquColors.outlineVariant,
                                  width: 0.8,
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

  /// Persistent Bottom Action Button Bar (responsive & zero overflow)
  Widget _buildBottomActionBar(PracticeCatalogController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AptiquColors.surfaceDim,
        border: Border(top: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
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
              ? 'Start Quick Drill (10 Questions)'
              : 'Start Drill ($selectedCount ${selectedCount == 1 ? 'Subtopic' : 'Subtopics'})';

          return ElevatedButton(
            onPressed: isBusy || !isEnabled ? null : controller.startPracticeSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AptiquColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: AptiquColors.surfaceContainerHigh,
              disabledForegroundColor: AptiquColors.onSurfaceVariant.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isBusy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Curating Questions with AI...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRandom ? Icons.bolt_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          buttonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AptiquTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
