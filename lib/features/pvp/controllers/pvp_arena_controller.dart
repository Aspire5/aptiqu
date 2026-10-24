import '../../../core/feedback/app_feedback_service.dart';
import '../ranked/ranked_models.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../services/pvp_socket_service.dart';
import '../models/pvp_models.dart';
import '../../../core/progression/controllers/xp_controller.dart';
import '../../../core/progression/models/xp_models.dart';
import '../../../core/network/dio_client.dart';
import '../../../features/auth/presentation/controllers/auth_controller.dart';

class PvpArenaController extends GetxController {
  final String matchId;
  final List<dynamic> initialPlayersData;
  final int totalQuestions;

  PvpArenaController({
    required this.matchId,
    required this.initialPlayersData,
    required this.totalQuestions,
    PvpSocketService? socketService,
    Stopwatch? roundClock,
    this.resume = false,
  }) : _socketService = socketService ?? PvpSocketService(),
       _roundClock = roundClock ?? Stopwatch();

  final bool resume;
  final Object _feedbackScope = Object();
  AppFeedbackService? get _feedback => AppFeedbackService.maybe;
  final Stopwatch _roundClock;
  int _roundBudgetMs = 60000;
  int _roundDurationMs = 60000;
  final personalRemainingSeconds = RxnInt();
  final opponentPlayer = <String, dynamic>{}.obs;
  final celebrateVictory = false.obs;
  bool _resultRecovered = false, _questionRecovered = false;
  String get _questionReceipt => '$matchId:${currentQuestionIndex.value}';
  bool get canAnswer =>
      currentQuestion.value != null &&
      !hasSubmittedAnswer.value &&
      selectedOptionId.isEmpty &&
      !isRoundEnded.value &&
      !isMatchCompleted.value &&
      !recoveredCompletion.value &&
      !isRecovering.value &&
      connectionError.isEmpty &&
      remainingSeconds.value > 0;
  Map<String, dynamic> get myPlayer {
    final user = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser.value
        : null;
    final initial = initialPlayersData
        .whereType<Map>()
        .where((p) => p['userId'] == currentUserId)
        .firstOrNull;
    return {
      'name': user?.firstName ?? initial?['firstName'] ?? 'You',
      'avatarUrl': user?.avatarUrl ?? initial?['avatarUrl'],
      'level': user?.level ?? initial?['level'],
    };
  }

  bool get _ownsFeedback =>
      !isClosed &&
      (!Get.isRegistered<AuthController>() ||
          Get.find<AuthController>().currentUser.value?.id == currentUserId);
  void setFeedbackVisible(bool value) {
    if (_ownsFeedback) _feedback?.setVisible(_feedbackScope, value);
  }

  void feedbackPresented() {
    if (!_ownsFeedback) return;
    if (isMatchCompleted.value && !isMatchVoided.value) {
      final fresh =
          _feedback?.result(
            _feedbackScope,
            'pvp:$matchId',
            won: isWinner.value && !isTie.value,
            recovered: _resultRecovered,
          ) ??
          false;
      // A result can be presented more than once after a route returns.
      if (fresh && isWinner.value && !isTie.value) {
        celebrateVictory.value = true;
      }
    } else if (canAnswer) {
      _feedback?.playable(
        _feedbackScope,
        session: 'pvp:$matchId',
        question: _questionReceipt,
        first: currentQuestionIndex.value == 0,
        fresh: !_questionRecovered && !resume,
      );
    }
  }

  void _tickFeedback() {
    if (_ownsFeedback) {
      _feedback?.tick(
        _feedbackScope,
        _questionReceipt,
        remainingSeconds.value,
        answerable: canAnswer,
      );
    }
  }

  // Single presentation clock, anchored to the server's remaining budget. Sound
  // observes its whole-second changes; it never owns an independent countdown.
  int _budget(Map<String, dynamic> data, {required int fallback}) {
    final deadline = DateTime.tryParse(data['deadline']?.toString() ?? '');
    final now = DateTime.tryParse(data['serverNow']?.toString() ?? '');
    if (deadline != null && now != null) {
      return deadline.difference(now).inMilliseconds.clamp(0, _roundDurationMs);
    }
    return ((data['remainingMs'] as num?)?.toInt() ?? fallback).clamp(
      0,
      _roundDurationMs,
    );
  }

  void _startVisualClock(int budget) {
    _countdownTimer?.cancel();
    _roundBudgetMs = budget;
    _roundClock
      ..reset()
      ..start();
    remainingSeconds.value = (budget / 1000).ceil().clamp(0, 60);
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      final next =
          ((_roundBudgetMs - _roundClock.elapsedMilliseconds + 999) ~/ 1000)
              .clamp(0, 60);
      if (remainingSeconds.value != next) {
        remainingSeconds.value = next;
        _tickFeedback();
      }
      if (next == 0) {
        timer.cancel();
        _feedback?.lock(_feedbackScope);
      }
    });
  }

  final PvpSocketService _socketService;
  StreamSubscription? _sub;
  Timer? _recoveryTimer;
  final isRecovering = false.obs, recoveredCompletion = false.obs;
  final isMatchVoided = false.obs;
  final ratingChange = Rxn<RankedChange>();
  final ratingDisposition = 'LEGACY_UNRATED'.obs;
  final settledAt = Rxn<DateTime>();
  int _stateVersion = -1;
  final connectionError = ''.obs;

  final RxInt currentQuestionIndex = 0.obs;
  final Rx<PvpQuestionDataModel?> currentQuestion = Rx<PvpQuestionDataModel?>(
    null,
  );
  final RxString selectedOptionId = ''.obs;
  final RxBool hasSubmittedAnswer = false.obs;

  // Real-time scores
  final RxInt myScore = 0.obs;
  final RxInt opponentScore = 0.obs;
  final RxString opponentName = 'Opponent'.obs;
  final RxBool isOpponentAfk = false.obs;

  // 60-second server countdown
  final RxInt remainingSeconds = 60.obs;
  Timer? _countdownTimer;
  final Stopwatch _questionStopwatch = Stopwatch();
  int _responseTimeOffsetMs = 0;
  bool _snapshotRequested = false;

  // Round results
  final RxString roundCorrectAnswer = ''.obs;
  final RxString roundExplanation = ''.obs;
  final RxBool isRoundEnded = false.obs;

  // Match final state
  final RxBool isMatchCompleted = false.obs;
  final RxBool isWinner = false.obs;
  final RxBool isTie = false.obs;
  final RxInt xpAwarded = 0.obs;

  String? currentUserId;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AuthController>()) {
      currentUserId = Get.find<AuthController>().currentUser.value?.id;
    }

    _feedback?.acquire(_feedbackScope);
    _setupInitialPlayers();
    _listenSocketEvents();
  }

  void _setupInitialPlayers() {
    for (final p in initialPlayersData) {
      final uid = p['userId']?.toString();
      final name = p['firstName']?.toString() ?? 'Opponent';
      if (uid != currentUserId) {
        opponentName.value = name;
        opponentPlayer.assignAll({
          'name': name,
          'avatarUrl': p['avatarUrl'],
          'level': p['level'],
        });
      }
    }
  }

  void _listenSocketEvents() {
    _sub = _socketService.eventStream.listen((event) {
      final eventName = event['event'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};
      if (isClosed ||
          (data['matchId'] != null && data['matchId'] != matchId) ||
          (Get.isRegistered<AuthController>() &&
              Get.find<AuthController>().currentUser.value?.id !=
                  currentUserId)) {
        return;
      }
      final version = data['stateVersion'];
      if (version is num) {
        if (version.toInt() < _stateVersion) return;
        _stateVersion = version.toInt();
      }
      if (isMatchVoided.value ||
          (isMatchCompleted.value && eventName != 'MATCH_COMPLETED')) {
        return;
      }

      switch (eventName) {
        case 'QUESTION_STARTED':
          _finishRecovery();
          _handleQuestionStarted(data);
          break;

        case 'ANSWER_ACCEPTED':
          if (isRoundEnded.value) return;
          if (data['questionIndex'] != null &&
              data['questionIndex'] != currentQuestionIndex.value) {
            return;
          }
          // Answer acknowledged by server
          hasSubmittedAnswer.value = true;
          _feedback?.lock(_feedbackScope);
          if (data.containsKey('selectedOptionId')) {
            selectedOptionId.value = data['selectedOptionId']?.toString() ?? '';
          }
          break;

        case 'QUESTION_ENDED':
          _finishRecovery();
          _handleQuestionEnded(data);
          break;

        case 'MATCH_COMPLETED':
          _finishRecovery();
          _handleMatchCompleted(data);
          break;
        case 'AUTH_SUCCESS':
          if (isRecovering.value) _requestSnapshot();
          break;
        case 'MATCH_RECONNECTED':
          if (data['matchId'] == matchId) _restoreSnapshot(data);
          break;
        case 'ERROR':
        case 'CONNECTION_LOST':
          _recoveryTimer?.cancel();
          isRecovering.value = false;
          _feedback?.lock(_feedbackScope);
          connectionError.value =
              data['message']?.toString() ??
              'Connection interrupted. Try reconnecting.';
          break;
      }
    });
  }

  void _handleQuestionStarted(Map<String, dynamic> data) {
    final index = data['questionIndex'] as int? ?? 0;
    if (index < currentQuestionIndex.value ||
        (index == currentQuestionIndex.value &&
            currentQuestion.value != null)) {
      return;
    }
    _questionRecovered = false;
    personalRemainingSeconds.value = null;
    isRoundEnded.value = false;
    hasSubmittedAnswer.value = false;
    selectedOptionId.value = '';
    roundCorrectAnswer.value = '';
    roundExplanation.value = '';

    currentQuestionIndex.value = data['questionIndex'] as int? ?? 0;
    final qData = data['question'] as Map<String, dynamic>?;
    if (qData != null) {
      currentQuestion.value = PvpQuestionDataModel.fromJson(qData);
    }

    final durationSec = data['durationSeconds'] as int? ?? 60;
    _roundDurationMs = durationSec * 1000;
    final budget = _budget(data, fallback: _roundDurationMs);
    _responseTimeOffsetMs = (_roundDurationMs - budget).clamp(
      0,
      _roundDurationMs,
    );
    _questionStopwatch
      ..reset()
      ..start();
    _startVisualClock(budget);
  }

  void _handleQuestionEnded(
    Map<String, dynamic> data, {
    bool recovered = false,
  }) {
    if (data['questionIndex'] != null &&
        data['questionIndex'] != currentQuestionIndex.value) {
      return;
    }
    if (isRoundEnded.value && roundCorrectAnswer.isNotEmpty) return;
    _countdownTimer?.cancel();
    _questionStopwatch.stop();
    _feedback?.lock(_feedbackScope);
    isRoundEnded.value = true;

    roundCorrectAnswer.value = data['correctAnswer']?.toString() ?? '';
    roundExplanation.value = data['explanation']?.toString() ?? '';

    final scores = (data['scores'] as List<dynamic>?) ?? [];
    for (final s in scores) {
      final uid = s['userId']?.toString();
      final sc = s['score'] as int? ?? 0;
      if (uid == currentUserId) {
        myScore.value = sc;
        if (s['isCorrect'] is bool && _ownsFeedback) {
          _feedback?.answer(
            _feedbackScope,
            _questionReceipt,
            correct: s['isCorrect'] as bool,
            recovered: recovered,
          );
        }
      } else {
        opponentScore.value = sc;
      }
    }
  }

  void _handleMatchCompleted(
    Map<String, dynamic> data, {
    bool recovered = false,
  }) {
    if (isMatchCompleted.value) return;
    if (data['ratingMode'] == 'RATED' && data['disposition'] != 'RATED') {
      connectionError.value =
          'Result updating. Refresh match to check the recorded result.';
      return;
    }
    ratingDisposition.value =
        data['disposition']?.toString() ?? 'LEGACY_UNRATED';
    final rawRating = data['rating'];
    if (rawRating is Map && rawRating['userId'] == currentUserId) {
      ratingChange.value = RankedChange.parse(rawRating);
    }
    settledAt.value = DateTime.tryParse(data['settledAt']?.toString() ?? '');
    _resultRecovered = recovered;
    recoveredCompletion.value = false;
    _feedback?.lock(_feedbackScope);
    _countdownTimer?.cancel();
    _questionStopwatch.stop();
    isMatchCompleted.value = true;

    final winnerId = data['winnerId']?.toString();
    isTie.value = data['isTie'] as bool? ?? false;
    isWinner.value = winnerId == currentUserId;

    final players = (data['players'] as List<dynamic>?) ?? [];
    for (final p in players) {
      final uid = p['userId']?.toString();
      if (uid == currentUserId) {
        xpAwarded.value = p['xpAwarded'] as int? ?? 0;
        if (p['score'] is num) myScore.value = (p['score'] as num).toInt();
      } else {
        isOpponentAfk.value = p['isAfk'] as bool? ?? false;
        if (p['score'] is num) {
          opponentScore.value = (p['score'] as num).toInt();
        }
      }
    }

    // Absolute server progress is safe across duplicate events/controller rebuilds.
    // Older servers lack this block: refresh progression instead of adding XP locally.
    if (Get.isRegistered<XpController>()) {
      final xp = data['xp'];
      if (xp is Map) {
        _applyXp(Map<String, dynamic>.from(xp));
      } else {
        unawaited(_refreshXp());
      }
    }
  }

  void _applyXp(Map<String, dynamic> data) {
    if (!Get.isRegistered<XpController>()) return;
    final xp = XpProgressModel.fromJson(data);
    if (xp.total < XpController.to.progress.value.total) return;
    XpController.to.handleXpUpdate(xp: xp);
  }

  Future<void> _refreshXp() async {
    if (!Get.isRegistered<DioClient>()) return;
    try {
      final response = await Get.find<DioClient>().dio.get('/user/progress');
      if (isClosed ||
          (Get.isRegistered<AuthController>() &&
              Get.find<AuthController>().currentUser.value?.id !=
                  currentUserId)) {
        return;
      }
      if (response.data['success'] == true && response.data['data'] is Map) {
        _applyXp(Map<String, dynamic>.from(response.data['data'] as Map));
      }
    } catch (_) {
      // The recorded award remains visible; the next profile refresh can sync XP.
    }
  }

  void selectOption(String optionId) {
    if (hasSubmittedAnswer.value ||
        selectedOptionId.isNotEmpty ||
        isRoundEnded.value ||
        isMatchCompleted.value ||
        recoveredCompletion.value ||
        isRecovering.value ||
        connectionError.isNotEmpty ||
        remainingSeconds.value <= 0) {
      return;
    }

    selectedOptionId.value = optionId;
    personalRemainingSeconds.value = remainingSeconds.value;
    _feedback?.lock(_feedbackScope);
    _questionStopwatch.stop();
    final elapsedMs =
        _responseTimeOffsetMs + _questionStopwatch.elapsedMilliseconds;

    // Submit authoritative answer to backend WebSocket
    _socketService.submitAnswer(
      matchId: matchId,
      questionIndex: currentQuestionIndex.value,
      selectedOptionId: optionId,
      responseTimeMs: elapsedMs,
    );
  }

  void _finishRecovery() {
    _recoveryTimer?.cancel();
    isRecovering.value = false;
    connectionError.value = '';
  }

  Future<void> recoverConnection() async {
    if (isRecovering.value ||
        isMatchCompleted.value ||
        recoveredCompletion.value ||
        isClosed) {
      return;
    }
    _feedback?.lock(_feedbackScope);
    isRecovering.value = true;
    _snapshotRequested = false;
    connectionError.value = '';
    await _socketService.connect();
    if (isClosed) return;
    if (!_socketService.isConnected) {
      isRecovering.value = false;
      connectionError.value =
          'Could not reconnect. Check your connection and try again.';
      return;
    }
    if (_socketService.isAuthenticated) _requestSnapshot();
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(seconds: 15), () {
      if (isClosed || !isRecovering.value) return;
      isRecovering.value = false;
      connectionError.value =
          'No match update received. Try reconnecting again.';
    });
  }

  void _requestSnapshot() {
    if (_snapshotRequested || !isRecovering.value) return;
    _snapshotRequested = true;
    _socketService.reconnectMatch(matchId);
  }

  void _restoreSnapshot(Map<String, dynamic> data) {
    if (data['status'] == 'CANCELLED' &&
        data['outcomeReason'] == 'SYSTEM_VOID') {
      _finishRecovery();
      _countdownTimer?.cancel();
      _questionStopwatch.stop();
      isRoundEnded.value = true;
      _feedback?.lock(_feedbackScope);
      isMatchVoided.value = true;
      recoveredCompletion.value = true;
      return;
    }
    final snapshotIndex =
        (data['currentQuestionIndex'] as num?)?.toInt() ??
        currentQuestionIndex.value;
    if (data['status'] != 'COMPLETED' &&
        (snapshotIndex < currentQuestionIndex.value ||
            (snapshotIndex == currentQuestionIndex.value &&
                currentQuestion.value != null &&
                (data['status'] == 'STARTING' ||
                    (roundCorrectAnswer.isNotEmpty &&
                        data['status'] == 'QUESTION_ACTIVE'))))) {
      return;
    }
    _questionRecovered = true;
    _finishRecovery();
    _countdownTimer?.cancel();
    for (final player in data['players'] as List? ?? []) {
      if (player['userId'] == currentUserId) {
        myScore.value = (player['score'] as num?)?.toInt() ?? 0;
      } else {
        opponentScore.value = (player['score'] as num?)?.toInt() ?? 0;
        opponentName.value =
            player['firstName']?.toString() ?? opponentName.value;
        opponentPlayer.assignAll({
          ...opponentPlayer,
          'name': opponentName.value,
          if (player['avatarUrl'] != null) 'avatarUrl': player['avatarUrl'],
          if (player['level'] != null) 'level': player['level'],
        });
      }
    }
    if (data['status'] == 'COMPLETED') {
      _questionStopwatch.stop();
      if (data.containsKey('winnerId') && data.containsKey('isTie')) {
        _handleMatchCompleted(data, recovered: true);
      } else {
        // Backward compatibility with old, incomplete reconnect snapshots.
        recoveredCompletion.value = true;
      }
      return;
    }
    final nextIndex =
        (data['currentQuestionIndex'] as num?)?.toInt() ??
        currentQuestionIndex.value;
    final sameQuestion =
        currentQuestion.value != null &&
        nextIndex == currentQuestionIndex.value;
    if (!sameQuestion) {
      selectedOptionId.value = '';
      personalRemainingSeconds.value = null;
      hasSubmittedAnswer.value = false;
    }
    currentQuestionIndex.value = nextIndex;
    if (data.containsKey('ownAnswer') &&
        (data['ownAnswer'] is Map ||
            !sameQuestion ||
            !hasSubmittedAnswer.value)) {
      final own = data['ownAnswer'];
      hasSubmittedAnswer.value = own is Map;
      selectedOptionId.value = own is Map
          ? own['selectedOptionId']?.toString() ?? ''
          : '';
    }
    final question = data['question'];
    currentQuestion.value = question is Map && data['status'] != 'STARTING'
        ? PvpQuestionDataModel.fromJson(Map<String, dynamic>.from(question))
        : null;
    if (!sameQuestion || data['status'] == 'QUESTION_ACTIVE') {
      roundCorrectAnswer.value = '';
      roundExplanation.value = '';
    }
    final remainingMs = (data['remainingMs'] as num?)?.toInt() ?? 0;
    remainingSeconds.value = (remainingMs / 1000).ceil().clamp(0, 60);
    isRoundEnded.value =
        data['status'] != 'QUESTION_ACTIVE' || remainingMs <= 0;
    if (isRoundEnded.value) _questionStopwatch.stop();
    final round = data['roundResult'];
    if (round is Map) {
      _handleQuestionEnded(Map<String, dynamic>.from(round), recovered: true);
    }
    if (!isRoundEnded.value) {
      if (!sameQuestion) {
        _responseTimeOffsetMs = (60000 - remainingMs).clamp(0, 60000);
        _questionStopwatch.reset();
      }
      if (selectedOptionId.isEmpty) _questionStopwatch.start();
      var budget = _budget(data, fallback: remainingMs);
      if (sameQuestion && _roundClock.isRunning) {
        final currentBudget = (_roundBudgetMs - _roundClock.elapsedMilliseconds)
            .clamp(0, _roundDurationMs);
        if (currentBudget < budget) budget = currentBudget;
      }
      _startVisualClock(budget);
    }
  }

  @override
  void onClose() {
    _feedback?.release(_feedbackScope);
    _roundClock.stop();
    _sub?.cancel();
    _recoveryTimer?.cancel();
    _countdownTimer?.cancel();
    _questionStopwatch.stop();
    super.onClose();
  }
}
