import '../../../core/feedback/feedback_presentation.dart';
import '../../../shared/widgets/feedback/victory_celebration.dart';
import 'pvp_versus_arena.dart';
import '../ranked/ranked_result.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../../social/widgets/social_profile_chrome.dart';
import '../controllers/pvp_arena_controller.dart';

class PvpArenaScreen extends StatefulWidget {
  final String matchId;
  final List<dynamic> initialPlayersData;
  final int totalQuestions;
  final bool resume;
  const PvpArenaScreen({
    super.key,
    required this.matchId,
    required this.initialPlayersData,
    required this.totalQuestions,
    this.resume = false,
  });
  @override
  State<PvpArenaScreen> createState() => _PvpArenaScreenState();
}

class _PvpArenaScreenState extends State<PvpArenaScreen> {
  late final PvpArenaController c;
  bool policyOpen = false, returning = false;
  @override
  void initState() {
    super.initState();
    c = Get.put(
      PvpArenaController(
        matchId: widget.matchId,
        resume: widget.resume,
        initialPlayersData: widget.initialPlayersData,
        totalQuestions: widget.totalQuestions,
      ),
    );
    if (widget.resume) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.recoverConnection();
      });
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<PvpArenaController>() &&
        identical(Get.find<PvpArenaController>(), c)) {
      Get.delete<PvpArenaController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Obx(() {
      final complete = c.isMatchCompleted.value || c.recoveredCompletion.value;
      final q = c.currentQuestion.value;
      final ended = c.isRoundEnded.value;
      final blocked =
          c.hasSubmittedAnswer.value ||
          c.selectedOptionId.isNotEmpty ||
          ended ||
          c.isRecovering.value ||
          c.connectionError.isNotEmpty;
      return FeedbackPresentation(
        presentationKey: complete
            ? 'result'
            : q == null
            ? null
            : 'question:${c.currentQuestionIndex.value}:${!blocked}',
        onVisibility: c.setFeedbackVisible,
        onPresented: c.feedbackPresented,
        child: PopScope(
          canPop: complete,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _policy(context);
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: SocialPageAppBar.height(
                context,
                title: 'Ranked match',
              ),
              title: const Text('Ranked match'),
              automaticallyImplyLeading: false,
              leading: complete
                  ? IconButton(
                      tooltip: 'Return to Ranked',
                      onPressed: () => _return(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : IconButton(
                      tooltip: 'About leaving this match',
                      onPressed: () => _policy(context),
                      icon: const Icon(Icons.info_outline),
                    ),
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (!complete && q != null) _ticker(context, ended),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _arenaHeader(context, complete),
                              const SizedBox(height: 20),
                              if (complete)
                                ..._result(context)
                              else ...[
                                if (c.connectionError.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        '${c.connectionError.value}\nMatch timing continues on the server.',
                                        style: context.type.bodyMedium
                                            ?.copyWith(
                                              color: context.colors.error,
                                            ),
                                      ),
                                    ),
                                  ),
                                if (q == null)
                                  AppStateView(
                                    title: c.isRecovering.value
                                        ? 'Reconnecting to your match…'
                                        : c.connectionError.isNotEmpty
                                        ? 'Waiting for connection'
                                        : 'Waiting for the first question',
                                    message:
                                        'Refresh the match if a question does not arrive.',
                                    loading: c.isRecovering.value,
                                    actionLabel: c.isRecovering.value
                                        ? null
                                        : 'Refresh match',
                                    onAction: c.isRecovering.value
                                        ? null
                                        : c.recoverConnection,
                                  )
                                else ...[
                                  const SizedBox(height: 16),
                                  QuestionMetadata(
                                    difficulty: q.difficulty,
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
                                  const SizedBox(height: 16),
                                  if (!blocked)
                                    Text(
                                      'Tap an option to submit immediately. Your choice locks for this round.',
                                      style: context.type.bodyMedium?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  for (final option in q.options)
                                    Obx(
                                      () => AnswerOption(
                                        id: option.id,
                                        text: option.text,
                                        selected:
                                            c.selectedOptionId.value ==
                                            option.id,
                                        correct:
                                            ended &&
                                            c.roundCorrectAnswer.value ==
                                                option.id,
                                        incorrect:
                                            ended &&
                                            c.selectedOptionId.value ==
                                                option.id &&
                                            c.roundCorrectAnswer.isNotEmpty &&
                                            c.roundCorrectAnswer.value !=
                                                option.id,
                                        onPressed: blocked || !c.canAnswer
                                            ? null
                                            : () => c.selectOption(option.id),
                                      ),
                                    ),
                                  if (ended) ...[
                                    const SizedBox(height: 12),
                                    if (c.roundCorrectAnswer.isNotEmpty)
                                      AnswerFeedback(
                                        isCorrect:
                                            c.selectedOptionId.value ==
                                            c.roundCorrectAnswer.value,
                                        correctAnswer:
                                            c.roundCorrectAnswer.value,
                                        mayBeTimeout: true,
                                      ),
                                    if (c.roundExplanation.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        c.roundExplanation.value,
                                        style: context.type.bodyLarge,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Text(
                                      'Waiting for the next question…',
                                      style: context.type.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: c.isRecovering.value
                                        ? null
                                        : c.recoverConnection,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(
                                      c.isRecovering.value
                                          ? 'Reconnecting…'
                                          : 'Refresh match',
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
  Widget _arenaHeader(BuildContext context, bool complete) => Obx(
    () => PvpVersusArena(
      me: c.myPlayer,
      opponent: Map<String, dynamic>.from(c.opponentPlayer),
      myScore: c.myScore.value,
      opponentScore: c.opponentScore.value,
      remaining: c.remainingSeconds.value,
      personalRemaining: c.personalRemainingSeconds.value,
      locked: c.selectedOptionId.isNotEmpty || c.hasSubmittedAnswer.value,
      accepted: c.hasSubmittedAnswer.value,
      ended: c.isRoundEnded.value,
      connected: !c.isRecovering.value && c.connectionError.isEmpty,
      complete: complete,
    ),
  );

  Widget _ticker(BuildContext context, bool ended) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Question ${c.currentQuestionIndex.value + 1} of ${widget.totalQuestions}',
            style: context.type.labelLarge,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: LinearProgressIndicator(
            value: widget.totalQuestions <= 0
                ? 0
                : ((c.currentQuestionIndex.value + 1) / widget.totalQuestions)
                      .clamp(0.0, 1.0),
            semanticsLabel: 'Match progress',
          ),
        ),
      ],
    ),
  );

  List<Widget> _result(BuildContext context) => [
    if (c.celebrateVictory.value)
      VictoryCelebration(
        key: ValueKey('victory:${widget.matchId}'),
        person: c.myPlayer,
      ),
    if (!c.celebrateVictory.value)
      Icon(
        c.recoveredCompletion.value
            ? Icons.task_alt_rounded
            : c.isTie.value
            ? Icons.handshake_outlined
            : c.isWinner.value
            ? Icons.emoji_events_outlined
            : Icons.info_outline,
        color: c.isWinner.value
            ? context.status.success
            : context.colors.primary,
        size: 40,
      ),
    const SizedBox(height: 16),
    Text(
      c.isMatchVoided.value
          ? 'Match cancelled'
          : c.recoveredCompletion.value
          ? 'Match finished'
          : c.isTie.value
          ? 'Draw'
          : c.isWinner.value
          ? 'Victory'
          : 'Defeat',
      style: context.type.headlineSmall,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 20),
    if (c.recoveredCompletion.value)
      Text(
        c.isMatchVoided.value
            ? 'A server interruption ended this match. No Elo or XP was awarded.'
            : 'Your match has finished. View its recorded result and rewards in Recent matches on Ranked.',
        style: context.type.bodyLarge,
      )
    else ...[
      if (c.ratingChange.value != null) ...[
        RankedResultView(
          key: ValueKey(c.ratingChange.value!.eventId),
          change: c.ratingChange.value!,
          owner: c.currentUserId ?? '',
          settledAt: c.settledAt.value,
        ),
        const SizedBox(height: 16),
      ] else
        Text(
          c.ratingDisposition.value == 'RATED'
              ? 'Recorded Elo unavailable. Refresh Ranked to check your standing.'
              : 'Unrated match · No Elo change',
          style: context.type.bodyMedium,
        ),
      SessionMetrics(
        items: [(label: 'XP awarded', value: '${c.xpAwarded.value}')],
      ),
      if (c.isOpponentAfk.value) ...[
        const SizedBox(height: 16),
        Text(
          'Your opponent left or disconnected during the match.',
          style: context.type.bodyLarge,
        ),
      ],
    ],
    const SizedBox(height: 32),
    AptiquButton(label: 'Return to Ranked', onPressed: () => _return(context)),
  ];
  void _return(BuildContext context) {
    if (returning) return;
    returning = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _policy(BuildContext context) async {
    if (policyOpen) return;
    policyOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Ranked match in progress'),
          content: const Text(
            'This match continues until the server ends it. Leaving or forfeiting a live Ranked match is not available. If updates stop, use Refresh match to reconnect. You can return to Ranked after the match finishes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
    policyOpen = false;
  }
}
