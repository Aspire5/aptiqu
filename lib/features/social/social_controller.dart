import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import 'social_api.dart';

class SocialController extends GetxController with WidgetsBindingObserver {
  final SocialApi api = SocialApi();
  final friendInvites = <Map<String, dynamic>>[].obs;
  final duelInvites = <Map<String, dynamic>>[].obs;
  final activeDuelId = ''.obs;
  final connected = false.obs;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  Timer? _heartbeat, _retry;
  Worker? _auth;
  String? _owner;
  bool _paused = false,
      _syncing = false,
      _syncAgain = false,
      _connecting = false;
  int _generation = 0, _attempt = 0;
  List<String> _watched = [];
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _auth = ever(Get.find<AuthController>().currentUser, (_) => _updateAuth());
    _updateAuth();
  }

  void _updateAuth() {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.isRegistrationComplete != true) {
      disconnect();
      _owner = null;
      friendInvites.clear();
      duelInvites.clear();
      activeDuelId.value = '';
      _watched = [];
      return;
    }
    if (_owner != user!.id) {
      disconnect();
      _owner = user.id;
    }
    if (!_paused && _channel == null) unawaited(connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      disconnect();
    } else {
      _updateAuth();
    }
  }

  Future<void> syncInbox() async {
    if (_owner == null || _paused) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    final generation = _generation;
    try {
      final data = await api.get('inbox');
      if (generation != _generation || isClosed) return;
      friendInvites.assignAll(
        (data['friends'] as List).map((r) => Map<String, dynamic>.from(r)),
      );
      duelInvites.assignAll(
        (data['duels'] as List).map((r) => Map<String, dynamic>.from(r)),
      );
      activeDuelId.value = data['activeDuelId'] ?? '';
    } catch (_) {
      /* Recovered on connection, foreground resume or manual refresh. */
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncInbox());
      }
    }
  }

  Future<void> connect() async {
    if (_connecting || _owner == null || _paused || isClosed) return;
    _connecting = true;
    final generation = _generation;
    try {
      await syncInbox(); // HTTP interceptor refreshes expired JWTs first.
      final token = await api.client.getAccessToken();
      if (token == null || generation != _generation || _paused) return;
      final base = Uri.parse(api.client.dio.options.baseUrl);
      final channel = WebSocketChannel.connect(
        base.replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/ws/social',
          query: '',
        ),
      );
      _channel = channel;
      await channel.ready;
      if (generation != _generation) {
        await channel.sink.close();
        return;
      }
      channel.stream.listen(
        (raw) {
          if (generation != _generation) return;
          try {
            final data = Map<String, dynamic>.from(jsonDecode(raw as String));
            if (data['event'] == 'AUTH_SUCCESS') {
              events.add({'event': 'RECONNECTED'});
              _attempt = 0;
              connected.value = true;
              watchFriends(_watched);
              unawaited(syncInbox());
              _heartbeat?.cancel();
              _heartbeat = Timer.periodic(
                const Duration(seconds: 25),
                (_) => channel.sink.add(jsonEncode({'type': 'HEARTBEAT'})),
              );
            } else {
              events.add(data);
              if (data['event'] != 'PRESENCE') unawaited(syncInbox());
            }
          } catch (_) {
            /* Invalid frames never become app state. */
          }
        },
        onError: (_) => _lost(generation),
        onDone: () => _lost(generation),
      );
      channel.sink.add(jsonEncode({'type': 'AUTH_INIT', 'token': token}));
    } catch (_) {
      _lost(generation);
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  void _lost(int generation) {
    if (generation != _generation) return;
    connected.value = false;
    _channel = null;
    _heartbeat?.cancel();
    if (_paused || _owner == null || isClosed || _retry?.isActive == true) {
      return;
    }
    final delay = min(30, 1 << min(_attempt++, 5));
    _retry = Timer(
      Duration(milliseconds: delay * 1000 + Random().nextInt(1000)),
      () {
        _retry = null;
        unawaited(connect());
      },
    );
  }

  void watchFriends(List<String> ids) {
    _watched = ids.take(50).toList();
    if (connected.value) {
      _channel?.sink.add(
        jsonEncode({'type': 'WATCH_FRIENDS', 'ids': _watched}),
      );
    }
  }

  void disconnect() {
    _generation++;
    _connecting = false;
    _retry?.cancel();
    _retry = null;
    _heartbeat?.cancel();
    _channel?.sink.close();
    _channel = null;
    connected.value = false;
  }

  @override
  void onClose() {
    disconnect();
    _auth?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    events.close();
    super.onClose();
  }
}
