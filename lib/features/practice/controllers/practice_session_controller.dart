import '../../social/social_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/practice_models.dart';
import '../repositories/practice_repository.dart';
import '../../../core/progression/controllers/xp_controller.dart';
import '../../../core/routing/app_router.dart';

class PracticeSessionController extends GetxController {
  final PracticeRepository _repository;
  final PracticeSessionModel initialSession;

  PracticeSessionController(
    this.initialSession, {
    PracticeRepository? repository,
    Stopwatch? stopwatch,
  }) : _repository = repository ?? PracticeRepository(),
       _stopwatch = stopwatch ?? Stopwatch();

  late final Rx<PracticeSessionModel> session;
  final RxInt currentQuestionIndex = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxString selectedOptionId = ''.obs;
  final Rx<PracticeAnswerResultModel?> lastResult =
      Rx<PracticeAnswerResultModel?>(null);
  final RxInt hintsRevealed = 0.obs;
  final RxBool isCompleted = false.obs;

  final Rx<PracticeAnswerResultModel?> completionResult =
      Rx<PracticeAnswerResultModel?>(null);

  final RxInt remainingSeconds = 60.obs;
  final RxBool isReady = false.obs;
  final clockError = ''.obs;
  final RxBool isLeaving = false.obs;
  final CancelToken _requests = CancelToken();
  Timer? _countdown;
  Timer? _readyTimer;
  StreamSubscription? _duelEvents;
  final duelEnded = ''.obs;
  final friendlyScores = <Map<String, dynamic>>[].obs;
  bool _duelSyncing = false, _duelSyncAgain = false;
  Future<void> _syncDuel() async {
    if (_duelSyncing) {
      _duelSyncAgain = true;
      return;
    }
    if (session.value.friendlyDuelId == null ||
        isClosed ||
        !Get.isRegistered<SocialController>()) {
      return;
    }
    _duelSyncing = true;
    try {
      final d = await Get.find<SocialController>().api.get(
        'duels/${session.value.friendlyDuelId}',
      );
      if (isClosed) return;
      friendlyScores.assignAll([
        for (final row in d['sessions'])
          {
            ...Map<String, dynamic>.from(row),
            'name': row['userId'] == d['requester']['id']
                ? d['requester']['name']
                : d['recipient']['name'],
          },
      ]);
      if ([
        'ABANDONED',
        'CANCELLED',
        'EXPIRED',
        'REJECTED',
      ].contains(d['status'])) {
        _countdown?.cancel();
        duelEnded.value =
            'This friendly duel ended before both players finished. No XP was awarded.';
        isLeaving.value = true;
      } else if (d['status'] == 'COMPLETED') {
        final restored = await _repository.getSession(session.value.id);
        if (isClosed) return;
        session.value = restored;
        if (Get.isRegistered<AuthController>()) {
          await Get.find<AuthController>().fetchUserProfile();
        }
      }
    } catch (_) {
      /* Manual refresh/reopen recovers a missed live snapshot. */
    } finally {
      _duelSyncing = false;
      if (_duelSyncAgain) {
        _duelSyncAgain = false;
        _syncDuel();
      }
    }
  }

  void begin({bool reduceMotion = false}) {
    if (isReady.value || _readyTimer != null || isCompleted.value) return;
    if (reduceMotion) {
      isReady.value = true;
      _startQuestionClock();
      return;
    }
    _readyTimer = Timer(const Duration(milliseconds: 450), () {
      _readyTimer = null;
      if (isClosed) return;
      isReady.value = true;
      _startQuestionClock();
    });
  }

  int _timerBudgetMs = 60000;
  Future<void> _startQuestionClock() async {
    _countdown?.cancel();
    if (session.value.isFriendlyDuel) {
      isReady.value = false;
      clockError.value = '';
      try {
        _timerBudgetMs = await _repository.startFriendlyQuestion(
          session.value.id,
        );
        if (isClosed || isLeaving.value) return;
        isReady.value = true;
      } catch (_) {
        if (!isClosed) {
          clockError.value =
              'Could not start this duel question. Please retry.';
        }
        return;
      }
    }
    _stopwatch.reset();
    _stopwatch.start();
    remainingSeconds.value = (_timerBudgetMs / 1000).ceil().clamp(0, 60);
    if (!session.value.timerEnabled) return;
    _runCountdown();
  }

  void _runCountdown() {
    _countdown = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (isClosed || isLeaving.value) {
        _countdown?.cancel();
        return;
      }
      final left =
          ((_timerBudgetMs - _stopwatch.elapsedMilliseconds + 999) ~/ 1000)
              .clamp(0, 60);
      if (remainingSeconds.value != left) remainingSeconds.value = left;
      if (left == 0) {
        _countdown?.cancel();
        selectedOptionId.value = 'TIMEOUT';
        submitAnswer();
      }
    });
  }

  @override
  void onClose() {
    _duelEvents?.cancel();
    _requests.cancel('Practice session closed');
    _readyTimer?.cancel();
    _countdown?.cancel();
    _stopwatch.stop();
    super.onClose();
  }

  final Stopwatch _stopwatch;

  @override
  void onInit() {
    super.onInit();
    session = Rx<PracticeSessionModel>(initialSession);
    if (initialSession.isFriendlyDuel && Get.isRegistered<SocialController>()) {
      _duelEvents = Get.find<SocialController>().events.stream.listen((event) {
        if ((event['event'] == 'DUEL_CHANGED' &&
                event['id'] == initialSession.friendlyDuelId) ||
            event['event'] == 'RECONNECTED') {
          _syncDuel();
        }
      });
      _syncDuel();
    }
    currentQuestionIndex.value = initialSession.currentIndex;
    if (initialSession.status == 'COMPLETED') isCompleted.value = true;
  }

  PracticeSessionQuestionModel? get currentSessionQuestion {
    final idx = currentQuestionIndex.value;
    if (idx >= 0 && idx < session.value.questions.length) {
      return session.value.questions[idx];
    }
    return null;
  }

  void selectOption(String optionId) {
    if (!isReady.value ||
        isLeaving.value ||
        remainingSeconds.value == 0 ||
        lastResult.value != null ||
        isSubmitting.value) {
      return;
    }
    selectedOptionId.value = optionId;
  }

  void revealNextHint() {
    if (hintsRevealed.value < 2) {
      hintsRevealed.value++;
    }
  }

  Future<void> submitAnswer() async {
    final curQ = currentSessionQuestion;
    if (curQ == null ||
        selectedOptionId.isEmpty ||
        isSubmitting.value ||
        lastResult.value != null) {
      return;
    }

    isSubmitting.value = true;
    _countdown?.cancel();
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;

    try {
      final result = await _repository.submitAnswer(
        sessionId: session.value.id,
        questionId: curQ.question.id,
        selectedOptionId: selectedOptionId.value,
        responseTimeMs: elapsedMs,
        cancelToken: _requests,
      );

      if (isClosed || isLeaving.value) return;
      lastResult.value = result;

      if (result.isComplete) {
        completionResult.value = result;
      }
    } catch (err) {
      if (isClosed || isLeaving.value) return;
      // The server may have committed even when the response was lost.
      try {
        final restored = await _repository.getSession(
          session.value.id,
          cancelToken: _requests,
        );
        if (isClosed || isLeaving.value) return;
        final answered = restored.questions[currentQuestionIndex.value];
        if (answered.isAnswered) {
          session.value = restored;
          lastResult.value = PracticeAnswerResultModel(
            isCorrect: answered.isCorrect ?? false,
            correctAnswer: answered.question.correctAnswer ?? '',
            explanation: answered.question.explanation ?? '',
            method: answered.question.method ?? '',
            alternativeExplanation: answered.question.alternativeExplanation,
            preferredSolution: answered.question.preferredSolution,
            preferredReason: answered.question.preferredReason,
            isComplete: restored.status == 'COMPLETED',
            totalAnswered: restored.questions.where((q) => q.isAnswered).length,
            correctCount: restored.correctCount,
            xpAwarded: restored.xpAwarded,
          );
          if (restored.status == 'COMPLETED') {
            completionResult.value = lastResult.value;
          }
          return;
        }
      } catch (_) {}
      if (isClosed || isLeaving.value) return;
      // Keep elapsed work; restart the ticker without resetting the clock.
      if (remainingSeconds.value > 0) {
        _stopwatch.start();
        if (session.value.timerEnabled) _runCountdown();
      }
      final context = AppRouter.navigatorKey.currentContext;
      final message = err.toString().replaceAll('Exception: ', '');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $message'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        debugPrint('[Practice] Answer submission failed: $message');
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  void nextQuestion() {
    if (lastResult.value == null ||
        isSubmitting.value ||
        isLeaving.value ||
        isCompleted.value) {
      return;
    }
    if (currentQuestionIndex.value < session.value.totalQuestions - 1) {
      currentQuestionIndex.value++;
      selectedOptionId.value = '';
      lastResult.value = null;
      hintsRevealed.value = 0;
      _startQuestionClock();
    } else {
      finishSession();
    }
  }

  void finishSession() {
    if (isCompleted.value) return;
    _countdown?.cancel();
    _stopwatch.stop();
    isCompleted.value = true;
    final compResult = completionResult.value ?? lastResult.value;
    if (compResult != null &&
        compResult.xpResult != null &&
        Get.isRegistered<XpController>()) {
      XpController.to.handleXpUpdate(
        xp: compResult.xpResult!.xp,
        levelUp: compResult.xpResult!.levelUp,
      );
    }
  }

  Future<void> abandon() async {
    if (isLeaving.value) return;
    isLeaving.value = true;
    _requests.cancel('Leaving session');
    _countdown?.cancel();
    _readyTimer?.cancel();
    _stopwatch.stop();
    if (!isCompleted.value) {
      unawaited(
        _repository.abandonSession(session.value.id).catchError((Object _) {}),
      );
    }
    final nav = AppRouter.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      Get.back();
    }
  }
}
