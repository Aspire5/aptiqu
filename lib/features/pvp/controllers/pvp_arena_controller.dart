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
  });

  final PvpSocketService _socketService = PvpSocketService();
  StreamSubscription? _sub;

  final RxInt currentQuestionIndex = 0.obs;
  final Rx<PvpQuestionDataModel?> currentQuestion = Rx<PvpQuestionDataModel?>(null);
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
          _handleQuestionStarted(data);
          break;

        case 'ANSWER_ACCEPTED':
          // Answer acknowledged by server
          hasSubmittedAnswer.value = true;
          break;

        case 'QUESTION_ENDED':
          _handleQuestionEnded(data);
          break;

        case 'MATCH_COMPLETED':
          _handleMatchCompleted(data);
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
      } else {
        isOpponentAfk.value = p['isAfk'] as bool? ?? false;
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
    if (hasSubmittedAnswer.value || isRoundEnded.value) return;

    selectedOptionId.value = optionId;
    _questionStopwatch.stop();
    final elapsedMs = _questionStopwatch.elapsedMilliseconds;

    // Submit authoritative answer to backend WebSocket
    _socketService.submitAnswer(
      matchId: matchId,
      questionIndex: currentQuestionIndex.value,
      selectedOptionId: optionId,
      responseTimeMs: elapsedMs,
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    _countdownTimer?.cancel();
    super.onClose();
  }
}
