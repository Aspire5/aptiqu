import 'dart:async';
import 'package:get/get.dart';
import '../services/pvp_socket_service.dart';
import '../models/pvp_models.dart';
import '../../../core/progression/controllers/xp_controller.dart';
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
  }) : _socketService = socketService ?? PvpSocketService();

  final PvpSocketService _socketService;
  StreamSubscription? _sub;
  Timer? _recoveryTimer;
  final isRecovering = false.obs, recoveredCompletion = false.obs;
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

    _setupInitialPlayers();
    _listenSocketEvents();
  }

  void _setupInitialPlayers() {
    for (final p in initialPlayersData) {
      final uid = p['userId']?.toString();
      final name = p['firstName']?.toString() ?? 'Opponent';
      if (uid != currentUserId) {
        opponentName.value = name;
      }
    }
  }

  void _listenSocketEvents() {
    _sub = _socketService.eventStream.listen((event) {
      final eventName = event['event'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      switch (eventName) {
        case 'QUESTION_STARTED':
          _finishRecovery();
          _handleQuestionStarted(data);
          break;

        case 'ANSWER_ACCEPTED':
          // Answer acknowledged by server
          hasSubmittedAnswer.value = true;
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
          connectionError.value =
              data['message']?.toString() ??
              'Connection interrupted. Try reconnecting.';
          break;
      }
    });
  }

  void _handleQuestionStarted(Map<String, dynamic> data) {
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

    // Start 60-second local visual countdown
    final durationSec = data['durationSeconds'] as int? ?? 60;
    remainingSeconds.value = durationSec;

    _responseTimeOffsetMs = 0;
    _questionStopwatch.reset();
    _questionStopwatch.start();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        timer.cancel();
      }
    });
  }

  void _handleQuestionEnded(Map<String, dynamic> data) {
    _countdownTimer?.cancel();
    _questionStopwatch.stop();
    isRoundEnded.value = true;

    roundCorrectAnswer.value = data['correctAnswer']?.toString() ?? '';
    roundExplanation.value = data['explanation']?.toString() ?? '';

    final scores = (data['scores'] as List<dynamic>?) ?? [];
    for (final s in scores) {
      final uid = s['userId']?.toString();
      final sc = s['score'] as int? ?? 0;
      if (uid == currentUserId) {
        myScore.value = sc;
      } else {
        opponentScore.value = sc;
      }
    }
  }

  void _handleMatchCompleted(Map<String, dynamic> data) {
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

    // Synchronize XP with global controller
    if (xpAwarded.value > 0 && Get.isRegistered<XpController>()) {
      final curXp = XpController.to.progress.value;
      XpController.to.handleXpUpdate(
        xp: curXp.copyWith(
          earned: xpAwarded.value,
          total: curXp.total + xpAwarded.value,
        ),
      );
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
    _finishRecovery();
    _countdownTimer?.cancel();
    for (final player in data['players'] as List? ?? []) {
      if (player['userId'] == currentUserId) {
        myScore.value = (player['score'] as num?)?.toInt() ?? 0;
      } else {
        opponentScore.value = (player['score'] as num?)?.toInt() ?? 0;
      }
    }
    // Reconnection does not return winner/reward fields. History remains authoritative.
    if (data['status'] == 'COMPLETED') {
      _questionStopwatch.stop();
      recoveredCompletion.value = true;
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
      hasSubmittedAnswer.value = false;
    }
    currentQuestionIndex.value = nextIndex;
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
    if (!isRoundEnded.value) {
      if (!sameQuestion) {
        _responseTimeOffsetMs = (60000 - remainingMs).clamp(0, 60000);
        _questionStopwatch.reset();
      }
      if (selectedOptionId.isEmpty) _questionStopwatch.start();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds.value > 0) {
          remainingSeconds.value--;
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _recoveryTimer?.cancel();
    _countdownTimer?.cancel();
    _questionStopwatch.stop();
    super.onClose();
  }
}
