import 'dart:async';
import 'package:aptiqu/core/feedback/feedback_audio_adapter.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/features/pvp/services/pvp_socket_service.dart';

class FeedbackClock extends Stopwatch {
  int milliseconds = 0;
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  void reset() {
    milliseconds = 0;
  }
}

class RecordingFeedbackAudio implements FeedbackAudioAdapter {
  final signals = StreamController<FeedbackInterruption>.broadcast(sync: true);
  final played = <FeedbackCue>[];
  int stops = 0, tickStops = 0, preloads = 0, disposals = 0;
  bool fail = false;
  Completer<void>? delayedPlay;
  @override
  Stream<FeedbackInterruption> get interruptions => signals.stream;
  @override
  Future<void> preload() async {
    preloads++;
    if (fail) throw StateError('Unavailable');
  }

  @override
  Future<void> play(FeedbackCue cue, bool Function() stillValid) async {
    if (fail) throw StateError('Unavailable');
    if (delayedPlay != null) await delayedPlay!.future;
    if (stillValid()) played.add(cue);
  }

  @override
  Future<void> stopTicks() async {
    tickStops++;
  }

  @override
  Future<void> stopAll() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await signals.close();
  }
}

class RecordingHaptics implements FeedbackHaptics {
  int starts = 0;
  bool fail = false;
  @override
  Future<void> sessionStart() async {
    starts++;
    if (fail) throw StateError('No vibrator');
  }
}

class FeedbackSocket implements PvpSocketService {
  final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final answers = <Map<String, dynamic>>[];
  int reconnects = 0;
  void emit(String event, Map<String, dynamic> data) =>
      events.add({'event': event, 'data': data});
  @override
  Stream<Map<String, dynamic>> get eventStream => events.stream;
  @override
  bool isConnected = true;
  @override
  bool isAuthenticated = true;
  @override
  Future<void> connect() async {}
  @override
  void reconnectMatch(String id) {
    reconnects++;
  }

  @override
  void submitAnswer({
    required String matchId,
    required int questionIndex,
    required String? selectedOptionId,
    required int responseTimeMs,
  }) {
    answers.add({
      'matchId': matchId,
      'questionIndex': questionIndex,
      'selectedOptionId': selectedOptionId,
      'responseTimeMs': responseTimeMs,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
