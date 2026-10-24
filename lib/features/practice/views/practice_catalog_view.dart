import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/layout/text_fit.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../controllers/practice_catalog_controller.dart';

class PracticeCatalogView extends StatelessWidget {
  const PracticeCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<PracticeCatalogController>()
        ? Get.find<PracticeCatalogController>()
        : Get.put(PracticeCatalogController());
    return LayoutBuilder(
      builder: (context, box) => Obx(() {
        final history = c.showHistory.value;
        final busy = c.isStartingSession.value || c.isReplaying.value;
        final preparing = c.isStartingSession.value && !c.friendlyDuel.value;
        final custom = c.selectionMode.value == PracticeSelectionMode.specific;
        final compact =
            box.maxHeight < 240 * MediaQuery.textScalerOf(context).scale(1);
        final header = _header(context, c, history, busy);
        final action = !history && !c.isLoading.value && c.errorMessage.isEmpty
            ? _action(context, c, busy, custom)
            : null;
        return PopScope(
          canPop: !history,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && history) {
              c.showHistory.value = false;
            }
          },
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                if (!compact) header,
                Expanded(
                  child: preparing
                      ? SingleChildScrollView(
                          child: AppStateView(
                            title: 'Finalising your questions…',
                            message: 'This may take a moment.',
                            loading: true,
                            actionLabel: 'Cancel',
                            onAction: c.cancelQuestionPreparation,
                          ),
                        )
                      : history
                      ? _history(context, c, header: compact ? header : null)
                      : _setup(
                          context,
                          c,
                          busy,
                          custom,
                          header: compact ? header : null,
                          action: compact ? action : null,
                        ),
                ),
                if (!preparing && !compact && action != null) action,
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _header(
    BuildContext context,
    PracticeCatalogController c,
    bool history,
    bool busy,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        if (history)
          IconButton(
            tooltip: 'Back to practice',
            onPressed: () => c.showHistory.value = false,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        Expanded(
          child: Text(
            history ? 'History & replays' : 'Practice',
            style: context.type.titleLarge,
          ),
        ),
        if (!history)
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
  );

  Widget _action(
    BuildContext context,
    PracticeCatalogController c,
    bool busy,
    bool custom,
  ) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.liveTopics.isEmpty || custom && c.selectedSubtopicIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                c.liveTopics.isEmpty
                    ? 'Practice questions are not available yet.'
                    : 'Select at least one subtopic to continue.',
                style: context.type.bodySmall,
              ),
            ),
          AptiquButton(
            label: busy
                ? 'Preparing your session…'
                : c.friendlyDuel.value
                ? 'Invite a friend'
                : 'Start practice',
            icon: const Icon(Icons.play_arrow_rounded),
            isLoading: busy,
            onPressed:
                busy ||
                    c.liveTopics.isEmpty ||
                    custom && c.selectedSubtopicIds.isEmpty
                ? null
                : c.startPracticeSession,
          ),
        ],
      ),
    ),
  );

  Widget _setup(
    BuildContext context,
    PracticeCatalogController c,
    bool busy,
    bool custom, {
    Widget? header,
    Widget? action,
  }) {
    if (c.isLoading.value) {
      return const Center(
        child: AppStateView(title: 'Loading practice', loading: true),
      );
    }
    if (c.errorMessage.isNotEmpty) {
      return SingleChildScrollView(
        child: AppStateView(
          title: 'Could not load practice',
          message: c.errorMessage.value,
          actionLabel: 'Retry',
          onAction: c.fetchLiveTopics,
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('practice-setup'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (header != null) header,
        LayoutBuilder(
          builder: (context, box) {
            final horizontal =
                textFits(
                  context,
                  'Random',
                  context.type.bodyLarge!,
                  box.maxWidth / 2 - 40,
                ) &&
                textFits(
                  context,
                  'Custom',
                  context.type.bodyLarge!,
                  box.maxWidth / 2 - 40,
                );
            if (!horizontal) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in PracticeSelectionMode.values)
                    ChoiceChip(
                      label: Text(
                        mode == PracticeSelectionMode.random
                            ? 'Random'
                            : 'Custom',
                      ),
                      selected: c.selectionMode.value == mode,
                      onSelected: busy
                          ? null
                          : (_) => c.selectionMode.value = mode,
                    ),
                ],
              );
            }
            return SegmentedButton<PracticeSelectionMode>(
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
              showSelectedIcon: false,
              onSelectionChanged: busy
                  ? null
                  : (value) => c.selectionMode.value = value.first,
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              custom ? Icons.track_changes_rounded : Icons.shuffle_rounded,
              color: context.colors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('10 questions', style: context.type.titleMedium),
                  Text(
                    custom
                        ? 'Your choice of topics.'
                        : 'Any topic. Any difficulty.',
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              _setting(
                context,
                icon: Icons.people_outline,
                title: 'Friendly duel',
                subtitle: '1v1 with a friend · 10 XP each when both finish',
                value: c.friendlyDuel.value,
                onChanged: busy ? null : (v) => c.friendlyDuel.value = v,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _setting(
                context,
                icon: Icons.auto_awesome_outlined,
                title: 'Smart AI Picks',
                subtitle: c.friendlyDuel.value
                    ? '5 questions from each player’s weaker topics.'
                    : 'Focus on patterns you find difficult.',
                value: c.smartPicks.value,
                onChanged: busy ? null : (v) => c.smartPicks.value = v,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _setting(
                context,
                icon: Icons.timer_outlined,
                title: '60-second timer',
                subtitle: 'For each question. Your pace when off.',
                value: c.timerEnabled.value,
                onChanged: busy ? null : (v) => c.timerEnabled.value = v,
              ),
            ],
          ),
        ),
        if (custom) ...[
          const SizedBox(height: 24),
          Text('Choose a subject', style: context.type.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in c.liveSubjects)
                ChoiceChip(
                  label: Text(subject.name),
                  selected: c.selectedSubjectId.value == subject.id,
                  onSelected: busy ? null : (_) => c.selectSubject(subject.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${c.selectedSubtopicIds.length} subtopics selected',
                style: context.type.bodyMedium,
              ),
              TextButton(
                onPressed: busy ? null : c.selectAllCurrentSubject,
                child: const Text('All'),
              ),
              TextButton(
                onPressed: busy ? null : c.clearSelection,
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final topic in c.currentSubjectTopics) ...[
            const Divider(height: 1),
            ExpansionTile(
              key: PageStorageKey(topic.topicId),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: Checkbox(
                tristate: true,
                value: c.isTopicFullySelected(topic.topicId)
                    ? true
                    : c.isTopicPartiallySelected(topic.topicId)
                    ? null
                    : false,
                onChanged: busy ? null : (_) => c.toggleTopic(topic.topicId),
              ),
              title: Text(topic.topicName, style: context.type.bodyLarge),
              subtitle: Text('${topic.subtopics.length} subtopics'),
              children: [
                for (final sub in topic.subtopics)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(sub.name, style: context.type.bodyLarge),
                    value: c.selectedSubtopicIds.contains(sub.id),
                    onChanged: busy ? null : (_) => c.toggleSubtopic(sub.id),
                  ),
              ],
            ),
          ],
        ],
        if (action != null) action,
      ],
    );
  }

  Widget _setting(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    secondary: Icon(icon, color: context.colors.primary),
    title: Text(title, style: context.type.bodyLarge),
    subtitle: Text(subtitle, style: context.type.bodyMedium),
    value: value,
    onChanged: onChanged,
  );

  Widget _history(
    BuildContext context,
    PracticeCatalogController c, {
    Widget? header,
  }) {
    if (c.isLoadingHistory.value && c.historyList.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            if (header != null) header,
            const AppStateView(
              title: 'Loading practice history',
              loading: true,
            ),
          ],
        ),
      );
    }
    if (c.historyList.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            if (header != null) header,
            AppStateView(
              title: c.historyError.isNotEmpty
                  ? 'Could not load history'
                  : 'No practice history yet',
              message: c.historyError.isNotEmpty
                  ? c.historyError.value
                  : 'Your practice sessions and replays will appear here.',
              actionLabel: c.historyError.isNotEmpty ? 'Retry' : null,
              onAction: c.historyError.isNotEmpty ? c.fetchHistory : null,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => c.fetchHistory(refresh: true),
      child: ListView(
        key: const PageStorageKey('practice-history'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (header != null) header,
          if (c.historyError.isNotEmpty)
            SessionNotice(
              message: 'History could not be refreshed',
              onRetry: () => c.fetchHistory(refresh: true),
            ),
          if (c.isLoadingHistory.value) const LinearProgressIndicator(),
          SessionMetrics(
            items: [
              (label: 'Completed', value: '${c.historyCompletedDrills.value}'),
              (label: 'Accuracy', value: '${c.historyOverallAccuracy.value}%'),
              (
                label: 'Average time',
                value: c.historyAvgResponseTimeMs.value > 0
                    ? '${(c.historyAvgResponseTimeMs.value / 1000).toStringAsFixed(1)}s'
                    : 'Unavailable',
              ),
            ],
          ),
          if (c.isReplaying.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: AppStateView(title: 'Preparing replay…', loading: true),
            ),
          const SizedBox(height: 16),
          for (final item in c.historyList) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.replaySourceType == 'PVP'
                        ? 'PvP duel replay'
                        : 'Practice session',
                    style: context.type.titleSmall,
                  ),
                  Text(
                    '${_date(context, item.createdAt)} · ${_status(item.status)}',
                    style: context.type.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SessionMetrics(
                    items: [
                      (
                        label: 'Correct',
                        value: '${item.correctCount}/${item.totalQuestions}',
                      ),
                      (
                        label: 'Total time',
                        value:
                            '${(item.totalTimeMs / 1000).toStringAsFixed(1)}s',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.isReplay
                            ? 'Replay · No rewards'
                            : '${item.xpAwarded} XP awarded',
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            c.isReplaying.value || c.isStartingSession.value
                            ? null
                            : () => c.replayPracticeSession(item.id),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Replay'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (c.historyPage.value < c.historyTotalPages.value)
            OutlinedButton(
              onPressed: c.isLoadingHistory.value
                  ? null
                  : () => c.fetchHistory(loadMore: true),
              child: Text(
                c.isLoadingHistory.value ? 'Loading history…' : 'Load more',
              ),
            ),
        ],
      ),
    );
  }

  String _date(BuildContext context, String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    return date == null
        ? 'Date unavailable'
        : MaterialLocalizations.of(context).formatFullDate(date);
  }

  String _status(String value) => switch (value) {
    'COMPLETED' => 'Completed',
    'ABANDONED' => 'Abandoned',
    'IN_PROGRESS' => 'In progress',
    'FAILED' => 'Finished',
    _ => value,
  };
}
