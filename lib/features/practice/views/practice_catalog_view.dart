import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/practice_catalog_controller.dart';

class PracticeCatalogView extends StatelessWidget {
  const PracticeCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<PracticeCatalogController>()
        ? Get.find<PracticeCatalogController>()
        : Get.put(PracticeCatalogController());
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(child: AppLoader());
      }
      if (c.errorMessage.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.errorMessage.value, textAlign: TextAlign.center),
                TextButton(
                  onPressed: c.fetchLiveTopics,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      final custom = c.selectionMode.value == PracticeSelectionMode.specific;
      final busy = c.isStartingSession.value || c.isReplaying.value;
      return ColoredBox(
        color: AptiquColors.surfaceDim,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  if (c.showHistory.value)
                    IconButton(
                      tooltip: 'Back to practice',
                      onPressed: () => c.showHistory.value = false,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const Icon(Icons.bolt_rounded, color: AptiquColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.showHistory.value
                          ? 'History & Replays'
                          : 'Practice Session',
                      style: AptiquTypography.titleMedium,
                    ),
                  ),
                  if (!c.showHistory.value)
                    IconButton(
                      tooltip: 'History & replays',
                      onPressed: busy
                          ? null
                          : () {
                              c.showHistory.value = true;
                              c.fetchHistory();
                            },
                      icon: const Icon(Icons.history_rounded),
                    ),
                ],
              ),
            ),
            if (!c.showHistory.value)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<PracticeSelectionMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AptiquColors.surfaceContainerHigh
                            : AptiquColors.surfaceContainerLowest,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        AptiquColors.onSurface,
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AptiquColors.outlineVariant),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: PracticeSelectionMode.random,
                        icon: Icon(Icons.shuffle_rounded),
                        label: Text('Random'),
                      ),
                      ButtonSegment(
                        value: PracticeSelectionMode.specific,
                        icon: Icon(Icons.tune_rounded),
                        label: Text('Custom'),
                      ),
                    ],
                    selected: {c.selectionMode.value},
                    onSelectionChanged: busy
                        ? null
                        : (value) => c.selectionMode.value = value.first,
                  ),
                ),
              ),
            Expanded(
              child: c.showHistory.value
                  ? _buildHistoryMode(context, c)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AptiquColors.primary.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      custom
                                          ? Icons.track_changes_rounded
                                          : Icons.shuffle_rounded,
                                      color: AptiquColors.primary,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '10 questions. One session.',
                                          style: AptiquTypography.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          custom
                                              ? 'Build your own mix.'
                                              : 'Any topic. Any difficulty.',
                                          style: AptiquTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!custom) const SizedBox(height: 18),
                              if (!custom)
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: List.generate(
                                    10,
                                    (i) => Container(
                                      width: 20,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AptiquColors.primary.withValues(
                                          alpha: .25,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!custom) const SizedBox(height: 12),
                              if (!custom)
                                Text(
                                  'Fresh questions first. A new chance to improve.',
                                  style: AptiquTypography.bodySmall.copyWith(
                                    color: AptiquColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          Column(
                            children: [
                              SwitchListTile.adaptive(
                                title: const Text('Friendly duel'),
                                subtitle: const Text(
                                  '1v1 with a friend · 10 XP each when both finish',
                                ),
                                value: c.friendlyDuel.value,
                                onChanged: busy
                                    ? null
                                    : (value) => c.friendlyDuel.value = value,
                              ),
                              SwitchListTile.adaptive(
                                activeThumbColor: AptiquColors.primary,
                                activeTrackColor: AptiquColors.primaryContainer
                                    .withValues(alpha: .35),
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AptiquColors.primary,
                                ),
                                title: const Text('Smart AI Picks'),
                                subtitle: Text(
                                  c.friendlyDuel.value
                                      ? '5 questions from each player’s weaker topics.'
                                      : 'Focus on patterns you find difficult.',
                                ),
                                value: c.smartPicks.value,
                                onChanged: busy
                                    ? null
                                    : (value) => c.smartPicks.value = value,
                              ),
                              const Divider(height: 20),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.timer_outlined,
                                  color: AptiquColors.primary,
                                ),
                                title: const Text('60-second timer'),
                                subtitle: const Text(
                                  'For each question. Your pace when off.',
                                ),
                                value: c.timerEnabled.value,
                                onChanged: busy
                                    ? null
                                    : (value) => c.timerEnabled.value = value,
                              ),
                            ],
                          ),
                        ),
                        if (custom) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Choose a subject',
                            style: AptiquTypography.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: c.liveSubjects
                                .map(
                                  (subject) => ChoiceChip(
                                    selectedColor:
                                        AptiquColors.surfaceContainerHigh,
                                    checkmarkColor: AptiquColors.primary,
                                    label: Text(subject.name),
                                    selected:
                                        c.selectedSubjectId.value == subject.id,
                                    onSelected: busy
                                        ? null
                                        : (_) => c.selectSubject(subject.id),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.selectedSubtopicIds.length} subtopics selected',
                                  style: AptiquTypography.bodySmall,
                                ),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : c.selectAllCurrentSubject,
                                child: const Text('All'),
                              ),
                              TextButton(
                                onPressed: busy ? null : c.clearSelection,
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          ...c.currentSubjectTopics.map(
                            (topic) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _card(
                                ExpansionTile(
                                  key: PageStorageKey(topic.topicId),
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  leading: Checkbox(
                                    tristate: true,
                                    value: c.isTopicFullySelected(topic.topicId)
                                        ? true
                                        : c.isTopicPartiallySelected(
                                            topic.topicId,
                                          )
                                        ? null
                                        : false,
                                    onChanged: busy
                                        ? null
                                        : (_) => c.toggleTopic(topic.topicId),
                                  ),
                                  title: Text(topic.topicName),
                                  subtitle: Text(
                                    '${topic.subtopics.length} subtopics',
                                  ),
                                  children: topic.subtopics
                                      .map(
                                        (sub) => CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: Text(sub.name),
                                          value: c.selectedSubtopicIds.contains(
                                            sub.id,
                                          ),
                                          onChanged: busy
                                              ? null
                                              : (_) => c.toggleSubtopic(sub.id),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (c.liveTopics.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Practice questions are not available yet.',
                            ),
                          ),
                      ],
                    ),
            ),
            if (!c.showHistory.value)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AptiquColors.buttonDarkBg,
                        foregroundColor: AptiquColors.onSurface,
                        side: BorderSide(
                          color: custom && c.selectedSubtopicIds.isEmpty
                              ? AptiquColors.outlineVariant
                              : AptiquColors.primary.withValues(alpha: .5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed:
                          busy ||
                              c.liveTopics.isEmpty ||
                              (custom && c.selectedSubtopicIds.isEmpty)
                          ? null
                          : c.startPracticeSession,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppLoader(),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        busy
                            ? 'Preparing your session...'
                            : c.friendlyDuel.value
                            ? 'Invite a friend'
                            : 'Start Practice Session',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _card(Widget child) => Material(
    color: AptiquColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AptiquColors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  /// History & Replays View
  Widget _buildHistoryMode(
    BuildContext context,
    PracticeCatalogController controller,
  ) {
    return Obx(() {
      if (controller.isLoadingHistory.value && controller.historyList.isEmpty) {
        return const Center(
          child: AppLoader(),
        );
      }

      if (controller.historyError.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.historyError.value,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => controller.fetchHistory(refresh: true),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      if (controller.historyList.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                color: AptiquColors.onSurfaceVariant,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'No Practice Sessions Yet',
                style: AptiquTypography.bodyMedium.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete a practice session to see it here.',
                style: AptiquTypography.bodySmall.copyWith(
                  color: AptiquColors.outline,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.fetchHistory(refresh: true),
        color: AptiquColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.historyList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              // Stats Overview Banner
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AptiquColors.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'COMPLETED',
                      '${controller.historyCompletedDrills.value}',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: AptiquColors.outlineVariant,
                    ),
                    _buildStatItem(
                      'ACCURACY',
                      '${controller.historyOverallAccuracy.value}%',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: AptiquColors.outlineVariant,
                    ),
                    _buildStatItem(
                      'AVG TIME',
                      controller.historyAvgResponseTimeMs.value > 0
                          ? '${(controller.historyAvgResponseTimeMs.value / 1000).toStringAsFixed(1)}s'
                          : 'N/A',
                    ),
                  ],
                ),
              );
            }

            final item = controller.historyList[index - 1];
            final isReplay = item.isReplay;
            final isPvpReplay = item.replaySourceType == 'PVP';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isReplay
                      ? Colors.purple.withValues(alpha: 0.5)
                      : AptiquColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPvpReplay
                                ? Icons.sports_esports_rounded
                                : Icons.flash_on_rounded,
                            size: 16,
                            color: isPvpReplay
                                ? const Color(0xFFF59E0B)
                                : AptiquColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPvpReplay
                                ? 'PvP Duel Replay'
                                : ('Practice Session'),
                            style: AptiquTypography.labelCaps.copyWith(
                              color: AptiquColors.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (isReplay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'REPLAY · 0 REWARDS',
                            style: AptiquTypography.labelCaps.copyWith(
                              color: Colors.purpleAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else if (item.xpAwarded > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AptiquColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${item.xpAwarded} XP',
                            style: AptiquTypography.labelCaps.copyWith(
                              color: AptiquColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score: ${item.correctCount}/${item.totalQuestions} Correct',
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total Time: ${(item.totalTimeMs / 1000).toStringAsFixed(1)}s',
                            style: AptiquTypography.bodySmall.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      // Replay Button
                      OutlinedButton.icon(
                        onPressed: controller.isReplaying.value
                            ? null
                            : () => controller.replayPracticeSession(item.id),
                        icon: const Icon(Icons.replay_rounded, size: 14),
                        label: const Text(
                          'Replay',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AptiquColors.primary,
                          side: const BorderSide(color: AptiquColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AptiquTypography.labelCaps.copyWith(
            color: AptiquColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AptiquTypography.bodyMedium.copyWith(
            color: AptiquColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
