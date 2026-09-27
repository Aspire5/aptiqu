import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/pvp_socket_service.dart';
import '../views/pvp_arena_screen.dart';

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
  }

  Future<void> _connectAndListen() async {
    await _socketService.connect();
    _sub = _socketService.eventStream.listen((event) {
      final eventName = event['event'] as String?;
      final data = event['data'] as Map<String, dynamic>? ?? {};

      switch (eventName) {
        case 'QUEUE_STATUS':
          final status = data['status'] as String?;
          if (status == 'WAITING_FOR_OPPONENT') {
            isInQueue.value = true;
            statusMessage.value = 'Searching for worthy opponent...';
            _startQueueTimer();
          } else if (status == 'LEFT_QUEUE') {
            isInQueue.value = false;
            statusMessage.value = 'Ready for Duel';
            _stopQueueTimer();
          }
          break;

        case 'MATCH_FOUND':
          _stopQueueTimer();
          isInQueue.value = false;
          statusMessage.value = 'Opponent Found! Preparing Arena...';

          final matchId = data['matchId'] as String;
          final players = (data['players'] as List<dynamic>?) ?? [];
          final totalQ = data['totalQuestions'] as int? ?? 10;

          // Transition to Arena
          Get.to(() => PvpArenaScreen(
                matchId: matchId,
                initialPlayersData: players,
                totalQuestions: totalQ,
              ));
          break;

        case 'ERROR':
          Get.snackbar(
            'Arena Error',
            data['message']?.toString() ?? 'An error occurred',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
          break;
      }
    });
  }

  void startMatchmaking() {
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

  @override
  void onClose() {
    _sub?.cancel();
    _queueTimer?.cancel();
    super.onClose();
  }
}
