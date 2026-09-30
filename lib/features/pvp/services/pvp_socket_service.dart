import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/network/dio_client.dart';

class PvpSocketService {
  static final PvpSocketService _instance = PvpSocketService._internal();
  factory PvpSocketService() => _instance;
  PvpSocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool isConnected = false;

  Future<void> connect() async {
    if (isConnected && _channel != null) return;

    final dioClient = Get.find<DioClient>();
    final token = await dioClient.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[PvP Socket] Cannot connect: No access token');
      return;
    }

    final rawBaseUrl = dioClient.dio.options.baseUrl;
    final wsBase = rawBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api/v1', '');

    final wsUri = Uri.parse('$wsBase/ws/pvp?token=$token');
    debugPrint('[PvP Socket] Connecting to: $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            _eventController.add(parsed);
          } catch (e) {
            debugPrint('[PvP Socket] Failed to decode incoming message: $e');
          }
        },
        onError: (err) {
          debugPrint('[PvP Socket] Stream Error: $err');
          isConnected = false;
          _channel = null;
        },
        onDone: () {
          debugPrint('[PvP Socket] Connection closed');
          isConnected = false;
          _channel = null;
        },
      );
    } catch (err) {
      debugPrint('[PvP Socket] Connection Failed: $err');
      isConnected = false;
      _channel = null;
    }
  }

  void send(String type, [Map<String, dynamic>? payload]) {
    if (_channel != null && isConnected) {
      final msg = jsonEncode({'type': type, 'payload': payload ?? {}});
      _channel!.sink.add(msg);
    }
  }

  Future<void> joinMatchmaking() async {
    if (!isConnected || _channel == null) {
      await connect();
    }
    send('JOIN_MATCHMAKING');
  }

  void leaveMatchmaking() {
    send('LEAVE_MATCHMAKING');
  }

  void submitAnswer({
    required String matchId,
    required int questionIndex,
    required String? selectedOptionId,
    required int responseTimeMs,
  }) {
    send('SUBMIT_ANSWER', {
      'matchId': matchId,
      'questionIndex': questionIndex,
      'selectedOptionId': selectedOptionId,
      'responseTimeMs': responseTimeMs,
    });
  }

  void reconnectMatch(String matchId) {
    send('RECONNECT_MATCH', {'matchId': matchId});
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    isConnected = false;
  }
}
