import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/practice_catalog_controller.dart';

class PracticeCatalogView extends StatelessWidget {
  const PracticeCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PracticeCatalogController());

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

      final liveTopics = controller.liveTopics;

      return Container(
        color: AptiquColors.surfaceDim,
        child: Column(
          children: [
            // Header Zone
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AptiquColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: AptiquColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
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
                        'Choose subtopics for a 10-Question drill',
                        style: AptiquTypography.bodySmall.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Subtopics Directory
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: liveTopics.length,
                itemBuilder: (context, idx) {
                  final topic = liveTopics[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AptiquColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AptiquColors.outlineVariant, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topic Title Bar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981), // Emerald Live badge
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  topic.topicName,
                                  style: AptiquTypography.titleSmall.copyWith(
                                    color: AptiquColors.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
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

                        // Subtopics Chips / Tiles
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
                                  backgroundColor: AptiquColors.surfaceContainerHigh,
                                  selectedColor: AptiquColors.primary.withValues(alpha: 0.25),
                                  checkmarkColor: AptiquColors.primary,
                                  labelStyle: AptiquTypography.bodySmall.copyWith(
                                    color: isSelected ? AptiquColors.primary : AptiquColors.onSurface,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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

            // Start Practice Floating Action Button Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceDim,
                border: const Border(top: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Obx(() {
                  final isBusy = controller.isStartingSession.value;
                  final selectedCount = controller.selectedSubtopicIds.length;

                  return ElevatedButton(
                    onPressed: isBusy || selectedCount == 0 ? null : controller.startPracticeSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AptiquColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isBusy
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Preparing 10 Questions...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Start Practice (10 Questions)',
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
            ),
          ],
        ),
      );
    });
  }
}
