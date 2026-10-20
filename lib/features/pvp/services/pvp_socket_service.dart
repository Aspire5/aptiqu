import '../../auth/presentation/controllers/auth_controller.dart';
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
  Future<void>? _connecting;
  int _generation = 0;
  String? _connectionOwner;
  String? get _account => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currentUser.value?.id
      : null;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool _recoveringAuth = false;
  bool isConnected = false;
  bool isAuthenticated = false;

  Future<void> connect() {
    if (_connectionOwner != _account) disconnect();
    _connectionOwner = _account;
    if (isConnected && _channel != null) return Future.value();
    final pending = _connecting;
    if (pending != null) return pending;
    late final Future<void> work;
    work = _connect().whenComplete(() {
      if (identical(_connecting, work)) _connecting = null;
    });
    _connecting = work;
    return work;
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    final account = _account;
    bool owned() => generation == _generation && account == _account;
    try {
      final dioClient = Get.find<DioClient>();
      final token = await dioClient.getAccessToken();
      if (!owned()) return;
      if (token == null || token.isEmpty) {
        debugPrint('[PvP Socket] Cannot connect: No access token');
        _connectionLost(
          'Could not connect. Check your connection and sign-in session.',
        );
        return;
      }

      final rawBaseUrl = dioClient.dio.options.baseUrl;
      final wsBase = rawBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceFirst('/api/v1', '');

      final wsUri = Uri.parse('$wsBase/ws/pvp');
      debugPrint('[PvP Socket] Connecting to: $wsUri');

      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      isConnected = true;
      isAuthenticated = false;

      // Send initial authentication handshake frame
      send('AUTH_INIT', {'token': token});

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            if (!owned() || !identical(_channel, channel)) return;
            if (parsed['event'] == 'AUTH_SUCCESS') {
              isAuthenticated = true;
              _recoveringAuth = false;
            }
            _eventController.add(parsed);
          } catch (e) {
            debugPrint('[PvP Socket] Failed to decode incoming message: $e');
          }
        },
        onError: (err) {
          debugPrint('[PvP Socket] Stream Error: $err');
          if (owned() && identical(_channel, channel)) {
            _connectionLost('Ranked connection interrupted.');
          }
        },
        onDone: () {
          debugPrint('[PvP Socket] Connection closed');
          if (owned() && identical(_channel, channel)) {
            final code = channel.closeCode;
            _connectionLost('Ranked connection interrupted.');
            if ((code == 4001 || code == 4003) && !_recoveringAuth) {
              _recoveringAuth = true;
              unawaited(_refreshAndReconnect(generation, account));
            }
          }
        },
      );
    } catch (err) {
      if (!owned()) return;
      debugPrint('[PvP Socket] Connection Failed: $err');
      _connectionLost('Could not connect to Ranked. Please try again.');
    }
  }

  Future<void> _refreshAndReconnect(int generation, String? account) async {
    try {
      final tokens = await Get.find<DioClient>().refreshSession();
      if (tokens == null || generation != _generation || account != _account) {
        return;
      }
      await connect(); // Arena AUTH_SUCCESS handling restores the participant's active match.
    } catch (_) {
      if (generation == _generation && account == _account) {
        _connectionLost(
          'Your session could not be refreshed. Please sign in again.',
        );
      }
    }
  }

  void _connectionLost(String message) {
    isConnected = false;
    isAuthenticated = false;
    _channel = null;
    _eventController.add({
      'event': 'CONNECTION_LOST',
      'data': {'message': message},
    });
  }

  void send(String type, [Map<String, dynamic>? payload]) {
    if (_channel != null && isConnected && _connectionOwner == _account) {
      final msg = jsonEncode({'type': type, 'payload': payload ?? {}});
      _channel!.sink.add(msg);
    }
  }

  Future<void> joinMatchmaking() async {
    final account = _account;
    if (!isConnected || _channel == null) {
      await connect();
    }
    if (account != _account) return;
    send('JOIN_MATCHMAKING', {'rankedCapability': 1});
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
    _recoveringAuth = false;
    ++_generation;
    _connecting = null;
    _channel?.sink.close();
    _channel = null;
    isConnected = false;
    isAuthenticated = false;
  }
}
