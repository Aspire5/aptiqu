import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../core/presentation/global_overlay_gate.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../../shared/widgets/feedback/app_state_view.dart';
import '../../../../shared/widgets/questions/question_presentation.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../models/daily_challenge_models.dart';

class DailyChallengeQuizScreen extends StatefulWidget {
  const DailyChallengeQuizScreen({super.key});
  @override
  State<DailyChallengeQuizScreen> createState() =>
      _DailyChallengeQuizScreenState();
}

class _DailyChallengeQuizScreenState extends State<DailyChallengeQuizScreen> {
  final controller = Get.isRegistered<DailyChallengeController>()
      ? Get.find<DailyChallengeController>()
      : Get.put(DailyChallengeController());
  bool _dialogOpen = false;
  bool _advancing = false;
  double _toolbarHeight(BuildContext context) {
    final text =
        TextPainter(
          text: TextSpan(
            text: 'Daily challenge',
            style: context.type.titleLarge,
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 136).clamp(
            1.0,
            double.infinity,
          ),
        );
    final height = (text.height + 16).clamp(56.0, double.infinity);
    text.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: _toolbarHeight(context),
          leading: IconButton(
            tooltip: 'Leave daily challenge',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _confirmExit(context),
          ),
          title: const Text('Daily challenge'),
          actions: [GlobalInvitationAction(gate: AppRouter.overlayGate)],
        ),
        body: SafeArea(
          top: false,
          child: Obx(() {
            final session = controller.activeSession.value;
            final index = controller.currentQuestionIndex.value;
            if (session == null ||
                session.questions.isEmpty ||
                index < 0 ||
                index >= session.questions.length) {
              return SingleChildScrollView(
                child: AppStateView(
                  title: 'No active questions',
                  message:
                      'Return to the daily challenge to start or resume an attempt.',
                  actionLabel: 'Return to daily challenge',
                  onAction: () => _returnToHub(context),
                ),
              );
            }
            final q = session.questions[index];
            final feedback =
                controller.showExplanation.value &&
                controller.lastAnswerResult.value != null;
            final busy = controller.isSubmitting.value;
            final selected = controller.selectedOptionId.value;
            final seconds = controller.secondsRemaining.value;
            final answerError = controller.answerError.value;
            return LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  ExcludeSemantics(
                    excluding: feedback,
                    child: ExcludeFocus(
                      excluding: feedback,
                      child: IgnorePointer(
                        ignoring: feedback,
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: session.totalQuestions > 0
                                  ? ((index + 1) / session.totalQuestions)
                                        .clamp(0.0, 1.0)
                                  : 0,
                              semanticsLabel: 'Daily challenge progress',
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                key: ValueKey('daily-question-${q.id}'),
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 720,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Question ${index + 1} of ${session.totalQuestions}',
                                              style: context.type.titleSmall,
                                            ),
                                            Semantics(
                                              label:
                                                  '$seconds seconds remaining',
                                              child: ExcludeSemantics(
                                                child: Text(
                                                  '${seconds}s remaining',
                                                  style: context.type.bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            controller
                                                                    .secondsRemaining
                                                                    .value <=
                                                                15
                                                            ? context
                                                                  .colors
                                                                  .error
                                                            : context
                                                                  .colors
                                                                  .primary,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        QuestionMetadata(
                                          difficulty: q.difficulty,
                                          mode: '60 seconds · No hints',
                                          source: q.pyq,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          q.prompt,
                                          style: context.type.bodyLarge,
                                        ),
                                        const SizedBox(height: 24),
                                        for (final option in q.options)
                                          AnswerOption(
                                            id: option.id,
                                            text: option.text,
                                            selected: selected == option.id,
                                            onPressed: busy || feedback
                                                ? null
                                                : () => controller.selectOption(
                                                    option.id,
                                                  ),
                                          ),
                                        if (answerError.isNotEmpty)
                                          Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              answerError,
                                              style: context.type.bodyMedium
                                                  ?.copyWith(
                                                    color: context.colors.error,
                                                  ),
                                            ),
                                          ),
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
                                      : answerError.isNotEmpty
                                      ? 'Retry answer'
                                      : 'Confirm answer',
                                  isLoading: busy,
                                  onPressed:
                                      selected != null && !busy && !feedback
                                      ? () => controller.submitAnswer(context)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (feedback)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 760,
                          maxHeight: box.maxHeight < 400
                              ? box.maxHeight
                              : box.maxHeight * .9,
                        ),
                        child: _explanation(
                          context,
                          controller.lastAnswerResult.value!,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    ),
  );

  /// Persistent feedback uses the actual body constraints, excluding app/system bars.
  Widget _explanation(
    BuildContext context,
    DailyChallengeAnswerResultModel result,
  ) => Material(
    elevation: 8,
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: context.colors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('daily-feedback-${result.sequence}'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnswerFeedback(
                  isCorrect: result.isCorrect,
                  correctAnswer: result.correctAnswer,
                  mayBeTimeout: true,
                ),
                const Divider(height: 32),
                QuestionSolutions(
                  explanation: result.explanation,
                  method: result.method,
                  alternativeExplanation: result.alternativeExplanation,
                  preferredSolution: result.preferredSolution,
                  preferredReason: result.preferredReason,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: AptiquButton(
            label: result.isComplete ? 'View result' : 'Next question',
            onPressed: () {
              if (_dialogOpen || _advancing) return;
              if (result.isComplete) {
                _completion(context, result);
              } else {
                _advancing = true;
                controller.proceedNext(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _advancing = false;
                });
              }
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _completion(
    BuildContext context,
    DailyChallengeAnswerResultModel result,
  ) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppearanceTheme(
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            scrollable: true,
            title: Text(
              result.streakIncremented
                  ? 'Daily challenge complete'
                  : 'Attempt finished',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  result.streakIncremented
                      ? Icons.local_fire_department_outlined
                      : Icons.info_outline,
                  color: result.streakIncremented
                      ? context.status.success
                      : context.colors.onSurfaceVariant,
                  size: 36,
                ),
                const SizedBox(height: 16),
                SessionMetrics(
                  items: [
                    (
                      label: 'Correct',
                      value: '${result.correctCount}/${result.totalQuestions}',
                    ),
                    (label: 'Current streak', value: '${result.streak} days'),
                    (label: 'XP awarded', value: '${result.xpAwarded}'),
                    (label: 'Coins awarded', value: '${result.coinsAwarded}'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  result.streakIncremented
                      ? 'Your streak increased. Your rewards have been recorded.'
                      : 'Every question must be correct to increase your streak and earn rewards.',
                  style: context.type.bodyLarge,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Return to daily challenge'),
              ),
            ],
          ),
        ),
      ),
    );
    _dialogOpen = false;
    if (context.mounted) _returnToHub(context);
  }

  Future<void> _confirmExit(BuildContext context) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Leave daily challenge?'),
          content: const Text(
            'Your attempt stays open until midnight IST (UTC+5:30). The current timer continues while you are away. Return before the daily cycle ends to resume any remaining questions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    if (leave == true && context.mounted) _returnToHub(context);
  }

  void _returnToHub(BuildContext context) {
    controller.fetchStatus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/daily-streak');
    }
  }
}
