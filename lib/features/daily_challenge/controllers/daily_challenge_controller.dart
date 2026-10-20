import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../models/daily_challenge_models.dart';
import '../repositories/daily_challenge_repository.dart';

class DailyChallengeController extends GetxController {
  final DailyChallengeRepository _repository;
  DailyChallengeController({DailyChallengeRepository? repository})
    : _repository = repository ?? DailyChallengeRepository();

  // Status observables
  final Rxn<DailyChallengeStatusModel> status =
      Rxn<DailyChallengeStatusModel>();
  final RxBool isLoadingStatus = true.obs;
  final RxString statusErrorMessage = ''.obs;

  // Starting / Blocking State (ensuring user UI is properly blocked during AI generation)
  final RxBool isStarting = false.obs;
  final RxString startError = ''.obs;
  final RxString answerError = ''.obs;
  final RxString startLoadingMessage = 'Preparing today’s challenge…'.obs;

  // Active Quiz Observables
  final Rxn<DailyChallengeSessionModel> activeSession =
      Rxn<DailyChallengeSessionModel>();
  final RxInt currentQuestionIndex = 0.obs;
  final RxInt secondsRemaining = 60.obs;
  final RxnString selectedOptionId = RxnString();
  final RxBool isSubmitting = false.obs;
  final Rxn<DailyChallengeAnswerResultModel> lastAnswerResult =
      Rxn<DailyChallengeAnswerResultModel>();
  final RxBool showExplanation = false.obs;
  final RxBool isCompleted = false.obs;

  // History Observables
  final RxList<DailyHistoryItemModel> historyList =
      <DailyHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs;
  final RxString historyError = ''.obs;
  final RxInt historyPage = 1.obs;
  final RxInt historyTotalPages = 1.obs;
  final RxInt userHighestStreak = 0.obs;
  final RxInt userOverallAvgTimeMs = 0.obs;

  Timer? _countdownTimer;
  Timer? _loadingMessageTimer;
  DateTime? _localQuestionDeadline;

  @override
  void onInit() {
    super.onInit();
    fetchStatus();
    fetchHistory();
  }

  @override
  void onClose() {
    _stopTimer();
    _stopLoadingMessageTimer();
    super.onClose();
  }

  /// Fetches daily challenge status and tier rules
  Future<void> fetchStatus() async {
    isLoadingStatus.value = true;
    statusErrorMessage.value = '';
    try {
      final res = await _repository.getStatus();
      status.value = res;
      userHighestStreak.value = res.highestStreak;
    } catch (e) {
      statusErrorMessage.value = e.toString();
    } finally {
      isLoadingStatus.value = false;
    }
  }

  /// Fetches user history of daily challenges
  Future<void> fetchHistory({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (isLoadingHistory.value || isClosed) return;
    final page = loadMore ? historyPage.value + 1 : 1;
    isLoadingHistory.value = true;
    historyError.value = '';
    try {
      final res = await _repository.getHistory(page: page, limit: 10);
      if (isClosed) return;
      historyPage.value = res.page;
      if (!loadMore) {
        historyList.assignAll(res.history);
      } else {
        historyList.addAll(res.history);
      }
      historyTotalPages.value = res.totalPages;
      userHighestStreak.value = res.highestStreak;
      userOverallAvgTimeMs.value = res.overallAvgTimeMs;
    } catch (e) {
      if (!isClosed) {
        historyError.value = 'History could not be loaded. Please try again.';
      }
      debugPrint('[DailyChallengeController] fetchHistory error: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Starts or resumes today's daily challenge.
  /// Shows a blocking, informative modal while Gemini synthesizes the script.
  Future<void> startDailyChallenge(BuildContext context) async {
    if (isStarting.value || isClosed) return;
    startError.value = '';
    if (status.value?.canAttempt == false) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot start another attempt today. The next daily cycle begins at midnight IST (UTC+5:30).',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    isStarting.value = true;
    _startLoadingMessageCycler();

    try {
      final session = await _repository.startChallenge();
      activeSession.value = session;
      currentQuestionIndex.value = session.questions.indexWhere(
        (q) => !q.isAnswered,
      );
      selectedOptionId.value = null;
      lastAnswerResult.value = null;
      showExplanation.value = false;
      isCompleted.value = false;

      _stopLoadingMessageTimer();
      isStarting.value = false;

      // Navigate to quiz screen
      if (context.mounted) {
        context.push(AppRoutes.dailyChallengeQuiz);
      }

      // Start 60s timer for the first question
      _startQuestionTimer();
    } catch (e) {
      _stopLoadingMessageTimer();
      isStarting.value = false;
      final rawMsg = e.toString().replaceAll('Exception: ', '').trim();
      startError.value = rawMsg.isNotEmpty
          ? rawMsg
          : 'Failed to start daily challenge. Please try again.';
      debugPrint('[DailyChallenge] startDailyChallenge error: $rawMsg');
    }
  }

  void _startLoadingMessageCycler() {
    final messages = [
      'Preparing today’s questions…',
      'Your challenge is still being prepared…',
      'Getting your daily questions ready…',
      'Preparing today’s challenge…',
      'This can take a moment…',
    ];
    int idx = 0;
    startLoadingMessage.value = messages[0];

    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(milliseconds: 3200), (
      _,
    ) {
      idx = (idx + 1) % messages.length;
      startLoadingMessage.value = messages[idx];
    });
  }

  void _stopLoadingMessageTimer() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;
  }

  /// Starts the 60-second fixed timer for the current question
  void _startQuestionTimer() {
    _stopTimer();
    final session = activeSession.value;
    final budget =
        session?.questionDeadline != null && session?.serverNow != null
        ? session!.questionDeadline!
              .difference(session.serverNow!)
              .inMilliseconds
        : 0;
    _localQuestionDeadline = DateTime.now().add(Duration(milliseconds: budget));
    secondsRemaining.value = (budget / 1000).ceil().clamp(0, 60);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _localQuestionDeadline!
          .difference(DateTime.now())
          .inMilliseconds;
      if (remaining > 0) {
        secondsRemaining.value = (remaining / 1000).ceil().clamp(0, 60);
      } else {
        secondsRemaining.value = 0;
        _stopTimer();
        _handleTimeExpired();
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void selectOption(String optionId) {
    if (showExplanation.value || isSubmitting.value) return;
    selectedOptionId.value = optionId;
  }

  /// Submits the selected answer or handles automatic time expiration
  Future<void> submitAnswer([BuildContext? context]) async {
    final session = activeSession.value;
    if (session == null || isSubmitting.value || showExplanation.value) return;

    final q = session.questions[currentQuestionIndex.value];
    final selected = selectedOptionId.value;

    if (selected == null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an option before submitting.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _stopTimer();
    isSubmitting.value = true;
    answerError.value = '';

    try {
      final result = await _repository.submitAnswer(
        participationId: session.participationId,
        questionId: q.id,
        selectedOptionId: selected,
        responseTimeMs:
            0, // Legacy request field; the server owns scoring time.
      );

      lastAnswerResult.value = result;
      showExplanation.value = true;

      if (result.isComplete) {
        isCompleted.value = true;
        // Refresh AuthController user profile to immediately reflect new streak & coins
        if (Get.isRegistered<AuthController>()) {
          Get.find<AuthController>().fetchUserProfile();
        }
        // Refresh status & history
        fetchStatus();
        fetchHistory(refresh: true);
      }
    } catch (e) {
      final rawMsg = e.toString().replaceAll('Exception: ', '').trim();
      answerError.value = rawMsg.isNotEmpty
          ? rawMsg
          : 'Failed to submit answer. Please try again.';
      debugPrint('[DailyChallenge] submitAnswer error: $rawMsg');
    } finally {
      isSubmitting.value = false;
    }
  }

  void _handleTimeExpired() {
    if (showExplanation.value || isSubmitting.value) return;

    // If an option was selected when time expired, submit it; otherwise submit timeout
    if (selectedOptionId.value != null) {
      submitAnswer();
    } else {
      selectedOptionId.value = 'TIMEOUT';
      submitAnswer();
    }
  }

  /// Advances to the next question or finishes the challenge
  Future<void> proceedNext(BuildContext context) async {
    if (isSubmitting.value) return;
    if (isCompleted.value) {
      context.pop();
      return;
    }
    isSubmitting.value = true;
    answerError.value = '';
    try {
      // This delivery starts the next clock. Reading feedback does not count as solve time.
      final session = await _repository.startChallenge();
      if (isClosed) return;
      activeSession.value = session;
      currentQuestionIndex.value = session.questions.indexWhere(
        (q) => !q.isAnswered,
      );
      showExplanation.value = false;
      selectedOptionId.value = null;
      lastAnswerResult.value = null;
      _startQuestionTimer();
    } catch (e) {
      answerError.value = e.toString().replaceAll('Exception: ', '').trim();
    } finally {
      isSubmitting.value = false;
    }
  }
}
