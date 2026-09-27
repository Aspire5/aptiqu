import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/practice_models.dart';
import '../repositories/practice_repository.dart';
import '../../../core/progression/controllers/xp_controller.dart';
import '../../../core/routing/app_router.dart';

class PracticeSessionController extends GetxController {
  final PracticeRepository _repository = PracticeRepository();
  final PracticeSessionModel initialSession;

  PracticeSessionController(this.initialSession);

  late final Rx<PracticeSessionModel> session;
  final RxInt currentQuestionIndex = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxString selectedOptionId = ''.obs;
  final Rx<PracticeAnswerResultModel?> lastResult = Rx<PracticeAnswerResultModel?>(null);
  final RxInt hintsRevealed = 0.obs;
  final RxBool isCompleted = false.obs;

  final Rx<PracticeAnswerResultModel?> completionResult = Rx<PracticeAnswerResultModel?>(null);

  final Stopwatch _stopwatch = Stopwatch();

  @override
  void onInit() {
    super.onInit();
    session = Rx<PracticeSessionModel>(initialSession);
    currentQuestionIndex.value = initialSession.currentIndex;
    _stopwatch.start();
  }

  PracticeSessionQuestionModel? get currentSessionQuestion {
    final idx = currentQuestionIndex.value;
    if (idx >= 0 && idx < session.value.questions.length) {
      return session.value.questions[idx];
    }
    return null;
  }

  void selectOption(String optionId) {
    if (lastResult.value != null || isSubmitting.value) return;
    selectedOptionId.value = optionId;
  }

  void revealNextHint() {
    if (hintsRevealed.value < 2) {
      hintsRevealed.value++;
    }
  }

  Future<void> submitAnswer() async {
    final curQ = currentSessionQuestion;
    if (curQ == null || selectedOptionId.isEmpty || isSubmitting.value || lastResult.value != null) {
      return;
    }

    isSubmitting.value = true;
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;

    try {
      final result = await _repository.submitAnswer(
        sessionId: session.value.id,
        questionId: curQ.question.id,
        selectedOptionId: selectedOptionId.value,
        responseTimeMs: elapsedMs,
      );

      lastResult.value = result;

      if (result.isComplete) {
        completionResult.value = result;
      }
    } catch (err) {
      Get.snackbar(
        'Submission Failed',
        err.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void nextQuestion() {
    if (currentQuestionIndex.value < session.value.totalQuestions - 1) {
      currentQuestionIndex.value++;
      selectedOptionId.value = '';
      lastResult.value = null;
      hintsRevealed.value = 0;
      _stopwatch.reset();
      _stopwatch.start();
    } else {
      finishSession();
    }
  }

  void finishSession() {
    isCompleted.value = true;
    final compResult = completionResult.value ?? lastResult.value;
    if (compResult != null && compResult.xpResult != null) {
      XpController.to.handleXpUpdate(
        xp: compResult.xpResult!.xp,
        levelUp: compResult.xpResult!.levelUp,
      );
    }
  }

  Future<void> abandon() async {
    if (!isCompleted.value) {
      try {
        await _repository.abandonSession(session.value.id);
      } catch (_) {}
    }
    final nav = AppRouter.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      Get.back();
    }
  }
}
