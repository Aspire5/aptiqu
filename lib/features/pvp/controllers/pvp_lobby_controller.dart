import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../practice/models/practice_models.dart';
import '../../practice/controllers/practice_session_controller.dart';
import '../models/pvp_history_model.dart';
import '../services/pvp_socket_service.dart';

class PvpLobbyController extends GetxController {
  final PvpSocketService _socketService = PvpSocketService();
  StreamSubscription? _sub;

  final RxBool isInQueue = false.obs;
  final RxString statusMessage = 'Ready for Duel'.obs;
  final RxInt secondsInQueue = 0.obs;
  Timer? _queueTimer;

  @override
  void onInit() {
    super.onInit();
    _connectAndListen();
    fetchHistory();
  }

  Future<void> _connectAndListen() async {
    await _socketService.connect();
    _sub = _socketService.eventStream.listen((event) {
      final eventName = event['event'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      switch (eventName) {
        case 'QUEUE_STATUS':
          final status = data['status'] as String?;
          if (status == 'WAITING_FOR_OPPONENT' || status == 'ALREADY_IN_QUEUE') {
            isInQueue.value = true;
            statusMessage.value = 'Searching for worthy opponent...';
            if (_queueTimer == null) {
              _startQueueTimer();
            }
          } else if (status == 'LEFT_QUEUE') {
            isInQueue.value = false;
            statusMessage.value = 'Ready for Duel';
            _stopQueueTimer();
          }
          break;

        case 'MATCH_FOUND':
          try {
            _stopQueueTimer();
            isInQueue.value = false;
            statusMessage.value = 'Opponent Found! Entering Arena...';

            final matchId = data['matchId'] as String;
            final players = (data['players'] as List<dynamic>?) ?? [];
            final totalQ = data['totalQuestions'] as int? ?? 10;

            AppRouter.router.push(
              AppRoutes.pvpArena,
              extra: {
                'matchId': matchId,
                'initialPlayersData': players,
                'totalQuestions': totalQ,
              },
            );
          } catch (e) {
            debugPrint('[PvP Lobby] Navigation error on MATCH_FOUND: $e');
            _showMessage('Arena Error', 'Failed to open PvP Arena: $e', isError: true);
          }
          break;

        case 'ERROR':
          final errMsg = data['message']?.toString() ?? 'An error occurred';
          _stopQueueTimer();
          isInQueue.value = false;
          statusMessage.value = 'Ready for Duel';
          _showMessage('Arena Error', errMsg, isError: true);
          break;
      }
    });
  }

  void _showMessage(String title, String message, {bool isError = false}) {
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: isError ? Colors.redAccent : const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      debugPrint('[$title] $message');
    }
  }

  void startMatchmaking() {
    isInQueue.value = true;
    statusMessage.value = 'Searching for worthy opponent...';
    _startQueueTimer();
    _socketService.joinMatchmaking();
  }

  void cancelMatchmaking() {
    _socketService.leaveMatchmaking();
    _stopQueueTimer();
    isInQueue.value = false;
    statusMessage.value = 'Ready for Duel';
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

  // PvP History observables
  final RxList<PvpMatchHistoryItemModel> matchHistory = <PvpMatchHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs;
  final RxBool isReplayingMatch = false.obs;

  Future<void> fetchHistory() async {
    isLoadingHistory.value = true;
    try {
      final dioClient = Get.find<DioClient>();
      final res = await dioClient.dio.get('/pvp/history');
      if (res.statusCode == 200 && res.data['success'] == true) {
        final list = (res.data['data']['history'] as List<dynamic>?)
                ?.map((item) => PvpMatchHistoryItemModel.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList() ??
            [];
        matchHistory.assignAll(list);
      }
    } catch (e) {
      debugPrint('[PvpLobby] fetchHistory error: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Replays a past PvP match as a solo Practice drill (untimed, no opponent, 0 rewards).
  /// Logs automatically save into Practice History.
  Future<void> replayMatchInPractice(String matchId) async {
    isReplayingMatch.value = true;
    try {
      final dioClient = Get.find<DioClient>();
      final res = await dioClient.dio.post(
        '/pvp/replay/$matchId',
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );

      if (res.statusCode == 201 && res.data['success'] == true) {
        final session = PracticeSessionModel.fromJson(
            res.data['data'] as Map<String, dynamic>);

        if (Get.isRegistered<PracticeSessionController>()) {
          Get.delete<PracticeSessionController>();
        }

        AppRouter.router.push(
          AppRoutes.practiceSession,
          extra: session,
        );
      } else {
        throw Exception(res.data['message'] ?? 'Failed to replay match');
      }
    } catch (e) {
      _showMessage(
        'Replay Notice',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      isReplayingMatch.value = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _queueTimer?.cancel();
    super.onClose();
  }
}

