import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../models/daily_challenge_models.dart';
import '../repositories/daily_challenge_repository.dart';

class DailyChallengeController extends GetxController {
  final DailyChallengeRepository _repository = DailyChallengeRepository();

  // Status observables
  final Rxn<DailyChallengeStatusModel> status = Rxn<DailyChallengeStatusModel>();
  final RxBool isLoadingStatus = true.obs;
  final RxString statusErrorMessage = ''.obs;

  // Starting / Blocking State (ensuring user UI is properly blocked during AI generation)
  final RxBool isStarting = false.obs;
  final RxString startLoadingMessage = 'Synthesizing Today\'s Challenge...'.obs;

  // Active Quiz Observables
  final Rxn<DailyChallengeSessionModel> activeSession = Rxn<DailyChallengeSessionModel>();
  final RxInt currentQuestionIndex = 0.obs;
  final RxInt secondsRemaining = 60.obs;
  final RxnString selectedOptionId = RxnString();
  final RxBool isSubmitting = false.obs;
  final Rxn<DailyChallengeAnswerResultModel> lastAnswerResult = Rxn<DailyChallengeAnswerResultModel>();
  final RxBool showExplanation = false.obs;
  final RxBool isCompleted = false.obs;

  // History Observables
  final RxList<DailyHistoryItemModel> historyList = <DailyHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs;
  final RxInt historyPage = 1.obs;
  final RxInt historyTotalPages = 1.obs;
  final RxInt userHighestStreak = 0.obs;
  final RxInt userOverallAvgTimeMs = 0.obs;

  Timer? _countdownTimer;
  Timer? _loadingMessageTimer;
  int _questionStartTimeMs = 0;

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
  Future<void> fetchHistory({bool refresh = false}) async {
    if (refresh) historyPage.value = 1;
    isLoadingHistory.value = true;
    try {
      final res = await _repository.getHistory(page: historyPage.value, limit: 10);
      if (refresh) {
        historyList.assignAll(res.history);
      } else {
        historyList.addAll(res.history);
      }
      historyTotalPages.value = res.totalPages;
      userHighestStreak.value = res.highestStreak;
      userOverallAvgTimeMs.value = res.overallAvgTimeMs;
    } catch (e) {
      debugPrint('[DailyChallengeController] fetchHistory error: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Starts or resumes today's daily challenge.
  /// Shows a blocking, informative modal while Gemini synthesizes the script.
  Future<void> startDailyChallenge(BuildContext context) async {
    if (status.value?.canAttempt == false) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already conquered today\'s challenge! Next challenge unlocks at 12:00 AM IST.'),
            backgroundColor: Color(0xFF1E293B),
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
      currentQuestionIndex.value = 0;
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
      debugPrint('[DailyChallenge] startDailyChallenge error: $rawMsg');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rawMsg.isNotEmpty ? rawMsg : 'Failed to start daily challenge. Please try again.'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startLoadingMessageCycler() {
    final messages = [
      'Consulting AI Aptitude Master...',
      'Synthesizing Brand-New Trick Questions...',
      'Calibrating 60-Second Shortcut Curves...',
      'Locking In Today\'s Authoritative Script...',
      'Preparing Your Challenge Arena...',
    ];
    int idx = 0;
    startLoadingMessage.value = messages[0];

    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
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
    secondsRemaining.value = 60;
    _questionStartTimeMs = DateTime.now().millisecondsSinceEpoch;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 1) {
        secondsRemaining.value--;
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
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _stopTimer();
    isSubmitting.value = true;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _questionStartTimeMs;
    final clampedTimeMs = elapsedMs.clamp(1000, 60000);

    try {
      final result = await _repository.submitAnswer(
        participationId: session.participationId,
        questionId: q.id,
        selectedOptionId: selected,
        responseTimeMs: clampedTimeMs,
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
      debugPrint('[DailyChallenge] submitAnswer error: $rawMsg');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rawMsg.isNotEmpty ? rawMsg : 'Failed to submit answer. Please try again.'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
  void proceedNext(BuildContext context) {
    showExplanation.value = false;
    selectedOptionId.value = null;

    final session = activeSession.value;
    if (session == null) return;

    if (currentQuestionIndex.value < session.questions.length - 1) {
      currentQuestionIndex.value++;
      _startQuestionTimer();
    } else {
      // Finished all questions!
      context.pop();
    }
  }
}
