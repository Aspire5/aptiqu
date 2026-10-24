import '../../../core/feedback/feedback_presentation.dart';
import '../../../shared/widgets/feedback/victory_celebration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../../../shared/widgets/sheets/app_sheet.dart';
import '../models/practice_models.dart';
import '../controllers/practice_session_controller.dart';

class PracticeSessionScreen extends StatefulWidget {
  final PracticeSessionModel initialSession;
  const PracticeSessionScreen({super.key, required this.initialSession});
  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  late final PracticeSessionController controller;
  bool _confirmingExit = false;
  @override
  void initState() {
    super.initState();
    controller = Get.put(PracticeSessionController(widget.initialSession));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.begin(reduceMotion: MediaQuery.disableAnimationsOf(context));
  }

  @override
  void dispose() {
    if (Get.isRegistered<PracticeSessionController>() &&
        identical(Get.find<PracticeSessionController>(), controller)) {
      Get.delete<PracticeSessionController>();
    }
    super.dispose();
  }

  Widget _entrance(BuildContext context, Widget child, String key) =>
      TweenAnimationBuilder<double>(
        key: ValueKey(key),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
        ),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        ),
        child: child,
      );
  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Obx(() {
      final session = controller.session.value;
      final finished =
          controller.isCompleted.value || controller.duelEnded.isNotEmpty;
      return FeedbackPresentation(
        presentationKey: controller.isCompleted.value
            ? 'result:${controller.friendlyResult.value?['status'] ?? ''}'
            : controller.isReady.value
            ? 'question:${controller.currentQuestionIndex.value}'
            : null,
        onVisibility: controller.setFeedbackVisible,
        onPresented: controller.feedbackPresented,
        child: PopScope(
          canPop: finished || controller.isLeaving.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmExit(context);
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: (MediaQuery.textScalerOf(context).scale(18) * 2.4)
                  .clamp(56.0, double.infinity),
              leading: IconButton(
                tooltip: 'Exit practice',
                onPressed: controller.isLeaving.value
                    ? null
                    : () => _confirmExit(context),
                icon: const Icon(Icons.close_rounded),
              ),
              title: Text(
                session.isReplay
                    ? 'Practice replay'
                    : session.isFriendlyDuel
                    ? 'Friendly practice'
                    : 'Practice',
              ),
              actions: [
                if (!finished)
                  IconButton(
                    tooltip: 'Hints',
                    onPressed:
                        controller
                                    .currentSessionQuestion
                                    ?.question
                                    .hints
                                    .isNotEmpty ==
                                true &&
                            !controller.isLeaving.value
                        ? () => _showHints(context)
                        : null,
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                  ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Obx(() {
                if (controller.duelEnded.isNotEmpty) {
                  return SingleChildScrollView(
                    child: AppStateView(
                      title: 'Duel ended',
                      message: controller.duelEnded.value,
                      actionLabel: 'Return to practice',
                      onAction: () => Navigator.of(context).pop(),
                    ),
                  );
                }
                if (controller.isCompleted.value) {
                  return _entrance(context, _completion(context), 'completed');
                }
                if (controller.clockError.isNotEmpty) {
                  return SingleChildScrollView(
                    child: AppStateView(
                      title: 'Could not start the timer',
                      message: controller.clockError.value,
                      actionLabel: 'Retry',
                      onAction: () => controller.begin(reduceMotion: true),
                    ),
                  );
                }
                if (!controller.isReady.value) {
                  return const Center(
                    child: SingleChildScrollView(
                      child: AppStateView(
                        title: 'Getting practice ready',
                        loading: true,
                      ),
                    ),
                  );
                }
                final current = controller.currentSessionQuestion;
                if (current == null) {
                  return SingleChildScrollView(
                    child: AppStateView(
                      title: 'No question available',
                      actionLabel: 'Return to practice',
                      onAction: controller.abandon,
                    ),
                  );
                }
                final q = current.question;
                final result = controller.lastResult.value;
                final busy =
                    controller.isSubmitting.value || controller.isLeaving.value;
                return _entrance(
                  context,
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: session.totalQuestions > 0
                            ? ((controller.currentQuestionIndex.value + 1) /
                                      session.totalQuestions)
                                  .clamp(0.0, 1.0)
                            : 0,
                        semanticsLabel: 'Practice progress',
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey('practice-question-${q.id}'),
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        'Question ${controller.currentQuestionIndex.value + 1} of ${session.totalQuestions}',
                                        style: context.type.titleSmall,
                                      ),
                                      if (session.timerEnabled)
                                        Semantics(
                                          label:
                                              '${controller.remainingSeconds.value} seconds remaining',
                                          child: ExcludeSemantics(
                                            child: Text(
                                              '${controller.remainingSeconds.value}s remaining',
                                              style: context.type.bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        context.colors.primary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      if (controller.hintsRevealed.value > 0)
                                        Text(
                                          '${controller.hintsRevealed.value}/2 hints used',
                                          style: context.type.bodyMedium,
                                        ),
                                    ],
                                  ),
                                  if (session.isFriendlyDuel) ...[
                                    const SizedBox(height: 16),
                                    SessionMetrics(
                                      items: [
                                        for (final score
                                            in controller.friendlyScores.take(
                                              2,
                                            ))
                                          (
                                            label: '${score['name']}',
                                            value:
                                                '${score['correctCount']} / 10 correct',
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  QuestionMetadata(
                                    difficulty: q.difficulty,
                                    mode: q.calculationBadge,
                                    source: q.pyq,
                                  ),
                                  if (q.pattern?.trim().isNotEmpty ??
                                      false) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      q.pattern!,
                                      style: context.type.bodySmall?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Text(q.prompt, style: context.type.bodyLarge),
                                  const SizedBox(height: 24),
                                  for (final option in q.options)
                                    AnswerOption(
                                      id: option.id,
                                      text: option.text,
                                      selected:
                                          controller.selectedOptionId.value ==
                                          option.id,
                                      correct:
                                          result?.correctAnswer == option.id,
                                      incorrect:
                                          result != null &&
                                          !result.isCorrect &&
                                          controller.selectedOptionId.value ==
                                              option.id,
                                      onPressed: result != null || busy
                                          ? null
                                          : () => controller.selectOption(
                                              option.id,
                                            ),
                                    ),
                                  if (controller.submitError.isNotEmpty)
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        controller.submitError.value,
                                        style: context.type.bodyMedium
                                            ?.copyWith(
                                              color: context.colors.error,
                                            ),
                                      ),
                                    ),
                                  if (result != null) ...[
                                    const SizedBox(height: 8),
                                    AnswerFeedback(
                                      isCorrect: result.isCorrect,
                                      correctAnswer: result.correctAnswer,
                                    ),
                                    const Divider(height: 32),
                                    QuestionSolutions(
                                      explanation: result.explanation.isNotEmpty
                                          ? result.explanation
                                          : q.explanation ?? '',
                                      method: result.method.isNotEmpty
                                          ? result.method
                                          : q.method ?? '',
                                      alternativeExplanation:
                                          result.alternativeExplanation ??
                                          q.alternativeExplanation,
                                      preferredSolution:
                                          result.preferredSolution ??
                                          q.preferredSolution,
                                      preferredReason:
                                          result.preferredReason ??
                                          q.preferredReason,
                                      onPreferredReason: (title, reason) =>
                                          _showReason(context, title, reason),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: AptiquButton(
                            label: busy
                                ? 'Submitting answer…'
                                : result != null
                                ? controller.currentQuestionIndex.value <
                                          session.totalQuestions - 1
                                      ? 'Next question'
                                      : 'Continue to summary'
                                : controller.submitError.isNotEmpty
                                ? 'Retry answer'
                                : 'Submit answer',
                            isLoading: busy,
                            onPressed: busy
                                ? null
                                : result != null
                                ? controller.nextQuestion
                                : controller.selectedOptionId.value.isEmpty
                                ? null
                                : controller.submitAnswer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  q.id,
                );
              }),
            ),
          ),
        ),
      );
    }),
  );

  void _showHints(BuildContext context) {
    final hints = controller.currentSessionQuestion?.question.hints ?? [];
    if (hints.isEmpty) return;
    showAppSheet<void>(
      context: context,
      title: 'Strategy hints',
      builder: (context) => Obx(() {
        final count = controller.hintsRevealed.value;
        final available = hints.length.clamp(0, 2);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$count of $available revealed',
              style: context.type.bodyMedium,
            ),
            for (var i = 0; i < count && i < available; i++) ...[
              const SizedBox(height: 16),
              Text('Hint ${i + 1}', style: context.type.titleSmall),
              const SizedBox(height: 8),
              Text(hints[i], style: context.type.bodyLarge),
            ],
            if (count < available) ...[
              const SizedBox(height: 24),
              AptiquButton(
                label: 'Reveal hint ${count + 1}',
                onPressed: controller.isLeaving.value
                    ? null
                    : controller.revealNextHint,
              ),
            ],
          ],
        );
      }),
    );
  }

  void _showReason(BuildContext context, String title, String? reason) =>
      showAppSheet<void>(
        context: context,
        title: 'AI preferred: $title',
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reason?.trim().isNotEmpty == true
                  ? reason!
                  : 'A reason for this preference is not available.',
              style: context.type.bodyLarge,
            ),
            const SizedBox(height: 24),
            AptiquButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _completion(BuildContext context) {
    final session = controller.session.value;
    final result =
        controller.completionResult.value ?? controller.lastResult.value;
    final correct = result?.correctCount ?? session.correctCount;
    final xp = session.isFriendlyDuel
        ? session.xpAwarded
        : result?.xpAwarded ?? session.xpAwarded;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.celebrateVictory.value)
                VictoryCelebration(person: controller.friendlyWinnerPerson)
              else
                Icon(
                  Icons.task_alt_rounded,
                  color: context.status.success,
                  size: 48,
                ),
              const SizedBox(height: 20),
              Text(
                session.isFriendlyDuel
                    ? controller.friendlyResult.value == null
                          ? 'Waiting for your friend'
                          : controller.friendlyResult.value!['isTie'] == true
                          ? 'Draw'
                          : controller.friendlyResult.value!['winnerId'] ==
                                controller.feedbackUserId
                          ? 'Victory'
                          : 'Duel complete'
                    : session.isReplay
                    ? 'Replay complete'
                    : 'Session complete',
                style: context.type.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SessionMetrics(
                items: [
                  (
                    label: 'Correct answers',
                    value: '$correct / ${session.totalQuestions}',
                  ),
                  (label: 'XP awarded', value: '$xp'),
                ],
              ),
              if (session.isReplay) ...[
                const SizedBox(height: 16),
                Text(
                  'Replays do not earn rewards.',
                  style: context.type.bodyLarge,
                ),
              ],
              if (session.isFriendlyDuel) ...[
                const SizedBox(height: 16),
                Text(
                  '10 XP each when both players finish. No Ranked rewards.',
                  style: context.type.bodyLarge,
                ),
                if (session.friendlyDuelId != null)
                  TextButton(
                    onPressed: () => context.push(
                      '/friendly-duel/${session.friendlyDuelId}',
                    ),
                    child: const Text('Duel score & rewards'),
                  ),
              ],
              const SizedBox(height: 32),
              AptiquButton(
                label: 'Return to practice',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    if (_confirmingExit || controller.isLeaving.value) return;
    if (controller.isCompleted.value || controller.duelEnded.isNotEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _confirmingExit = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Exit practice?'),
          content: const Text(
            'Your session will be marked as abandoned and zero completion XP will be awarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep practicing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit (0 XP)'),
            ),
          ],
        ),
      ),
    );
    _confirmingExit = false;
    if (leave == true && mounted) await controller.abandon();
  }
}
