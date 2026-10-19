import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../practice/models/practice_models.dart';
import '../../practice/controllers/practice_session_controller.dart';
import '../models/pvp_history_model.dart';
import '../services/pvp_socket_service.dart';

class PvpLobbyController extends GetxController {
  final PvpSocketService _socketService;
  PvpLobbyController({PvpSocketService? socketService})
    : _socketService = socketService ?? PvpSocketService();
  StreamSubscription? _sub;
  Worker? _presentationWorker;
  final RxBool isInQueue = false.obs,
      isCancelling = false.obs,
      isOpeningMatch = false.obs;
  final RxString statusMessage = 'Ready to play'.obs,
      queueError = ''.obs,
      historyError = ''.obs;
  final RxInt secondsInQueue = 0.obs;
  Timer? _queueTimer, _cancelTimer;
  int _queueGeneration = 0;
  final RxList<PvpMatchHistoryItemModel> matchHistory =
      <PvpMatchHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs, isReplayingMatch = false.obs;
  @override
  void onInit() {
    super.onInit();
    _presentationWorker = everAll([
      isInQueue,
      isCancelling,
      isOpeningMatch,
      isReplayingMatch,
    ], (_) => _syncPresentationActivity());
    _syncPresentationActivity();
    _sub = _socketService.eventStream.listen(_event);
    _socketService.connect();
    fetchHistory();
  }

  void _syncPresentationActivity() => AppRouter.overlayGate.setTask(
    this,
    isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isReplayingMatch.value,
  );

  void _event(Map<String, dynamic> event) {
    if (isClosed) return;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    switch (event['event']) {
      case 'QUEUE_STATUS':
        if (data['status'] == 'LEFT_QUEUE') {
          isInQueue.value = false;
          isCancelling.value = false;
          _cancelTimer?.cancel();
          _stopQueueTimer();
          statusMessage.value = 'Ready to play';
        } else if (data['status'] == 'WAITING_FOR_OPPONENT' ||
            data['status'] == 'ALREADY_IN_QUEUE') {
          isInQueue.value = true;
          statusMessage.value = 'Finding an opponent…';
          if (_queueTimer == null) _startQueueTimer();
          if (isCancelling.value) _socketService.leaveMatchmaking();
        }
        break;
      case 'MATCH_FOUND':
        if (isOpeningMatch.value) return;
        _stopQueueTimer();
        _cancelTimer?.cancel();
        isCancelling.value = false;
        isInQueue.value = false;
        _openMatch(data);
        break;
      case 'ERROR':
      case 'CONNECTION_LOST':
        _stopQueueTimer();
        _cancelTimer?.cancel();
        isInQueue.value = false;
        isCancelling.value = false;
        queueError.value =
            data['message']?.toString() ??
            'Could not connect to Ranked. Please try again.';
        statusMessage.value = 'Ready to play';
        break;
    }
  }

  Future<void> _openMatch(Map<String, dynamic> data) async {
    isOpeningMatch.value = true;
    statusMessage.value = 'Match found. Opening…';
    queueError.value = '';
    try {
      await AppRouter.router.push(
        AppRoutes.pvpArena,
        extra: {
          'matchId': data['matchId'] as String,
          'initialPlayersData': data['players'] as List<dynamic>? ?? [],
          'totalQuestions': data['totalQuestions'] as int? ?? 10,
        },
      );
      if (!isClosed) await fetchHistory();
    } catch (_) {
      if (!isClosed) {
        queueError.value = 'Could not open this match. Please try again.';
      }
    } finally {
      if (!isClosed) {
        isOpeningMatch.value = false;
        statusMessage.value = 'Ready to play';
      }
    }
  }

  Future<void> startMatchmaking() async {
    if (isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isReplayingMatch.value ||
        isClosed) {
      return;
    }
    final generation = ++_queueGeneration;
    queueError.value = '';
    isInQueue.value = true;
    statusMessage.value = 'Connecting to Ranked…';
    _startQueueTimer();
    await _socketService.connect();
    if (isClosed || generation != _queueGeneration || !isInQueue.value) return;
    if (!_socketService.isConnected) {
      isInQueue.value = false;
      _stopQueueTimer();
      queueError.value = 'Could not connect to Ranked. Please try again.';
      return;
    }
    await _socketService.joinMatchmaking();
  }

  void cancelMatchmaking() {
    if (isClosed || isCancelling.value) return;
    ++_queueGeneration;
    if (!_socketService.isConnected) {
      isInQueue.value = false;
      _stopQueueTimer();
      return;
    }
    isCancelling.value = true;
    statusMessage.value = 'Cancelling matchmaking…';
    _socketService.leaveMatchmaking();
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(seconds: 10), () {
      if (isClosed || !isCancelling.value) return;
      isCancelling.value = false;
      queueError.value = 'Cancellation was not confirmed. Try Cancel again.';
    });
  }

  void _startQueueTimer() {
    secondsInQueue.value = 0;
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsInQueue.value++;
    });
  }

  void _stopQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  Future<void> fetchHistory() async {
    if (isLoadingHistory.value || isClosed) return;
    isLoadingHistory.value = true;
    historyError.value = '';
    try {
      final res = await Get.find<DioClient>().dio.get('/pvp/history');
      if (res.statusCode != 200 || res.data['success'] != true) {
        throw Exception('History unavailable');
      }
      final list =
          (res.data['data']['history'] as List<dynamic>?)
              ?.map(
                (item) => PvpMatchHistoryItemModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          [];
      if (!isClosed) matchHistory.assignAll(list);
    } catch (_) {
      if (!isClosed) {
        historyError.value = 'Could not load match history. Please try again.';
      }
    } finally {
      if (!isClosed) isLoadingHistory.value = false;
    }
  }

  /// Existing solo Practice replay: untimed, no opponent, no replay rewards.
  Future<void> replayMatchInPractice(String matchId) async {
    if (isReplayingMatch.value ||
        isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isClosed) {
      return;
    }
    isReplayingMatch.value = true;
    queueError.value = '';
    try {
      final res = await Get.find<DioClient>().dio.post(
        '/pvp/replay/$matchId',
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      if (res.statusCode != 201 || res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to replay match');
      }
      final session = PracticeSessionModel.fromJson(
        res.data['data'] as Map<String, dynamic>,
      );
      if (isClosed) return;
      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }
      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
    } catch (_) {
      if (!isClosed) {
        queueError.value = 'Could not open the replay. Please try again.';
      }
    } finally {
      if (!isClosed) isReplayingMatch.value = false;
    }
  }

  @override
  void onClose() {
    _presentationWorker?.dispose();
    AppRouter.overlayGate.setTask(this, false);
    _sub?.cancel();
    _queueTimer?.cancel();
    _cancelTimer?.cancel();
    super.onClose();
  }
}
