import 'dart:async';
import 'package:aptiqu/core/feedback/feedback_audio_adapter.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cache extends AudioCache {
  @override
  Future<Uri> load(String fileName) async => Uri.file('/fake-assets/$fileName');
}

class _GlobalPlatform extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> setGlobalAudioContext(AudioContext context) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final events = StreamController<GlobalAudioEvent>.broadcast();
  @override
  Future<void> init() async {}
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => events.stream;
}

class _Platform extends AudioplayersPlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final streams = <String, StreamController<AudioEvent>>{};
  final contexts = <AudioContext>[];
  final releases = <ReleaseMode>[];
  final playing = <String>{};
  int created = 0, disposed = 0, peakPlaying = 0, sources = 0;
  Completer<void>? sourceGate;
  @override
  Future<void> create(String id) async {
    created++;
    streams[id] = StreamController.broadcast();
  }

  @override
  Future<void> dispose(String id) async {
    disposed++;
    playing.remove(id);
    await streams.remove(id)?.close();
  }

  @override
  Stream<AudioEvent> getEventStream(String id) => streams[id]!.stream;
  @override
  Future<void> setAudioContext(String id, AudioContext context) async {
    contexts.add(context);
  }

  @override
  Future<void> setReleaseMode(String id, ReleaseMode mode) async {
    releases.add(mode);
  }

  @override
  Future<void> setSourceUrl(
    String id,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    sources++;
    if (sourceGate != null) await sourceGate!.future;
    streams[id]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String id, double volume) async {}
  @override
  Future<void> seek(String id, Duration position) async {
    streams[id]!.add(const AudioEvent(eventType: AudioEventType.seekComplete));
  }

  @override
  Future<void> resume(String id) async {
    playing.add(id);
    if (playing.length > peakPlaying) peakPlaying = playing.length;
  }

  @override
  Future<void> stop(String id) async {
    playing.remove(id);
  }

  @override
  Future<void> release(String id) async {
    playing.remove(id);
  }

  @override
  Future<int?> getDuration(String id) async => 1000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final global = _GlobalPlatform();
  late _Platform platform;
  late PreparedFeedbackAudio adapter;
  setUp(() {
    GlobalAudioplayersPlatformInterface.instance = global;
    AudioplayersPlatformInterface.instance = platform = _Platform();
    AudioCache.instance = _Cache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
    adapter = PreparedFeedbackAudio();
  });
  tearDown(() async {
    await adapter.dispose();
  });
  test(
    'real adapter stays at 3 players through 100 rounds and releases all handles',
    () async {
      await adapter.preload();
      for (var i = 0; i < 100; i++) {
        await adapter.play(FeedbackCue.tick, () => true);
        await adapter.stopTicks();
        await adapter.play(FeedbackCue.urgentTick, () => true);
        await adapter.stopTicks();
        await adapter.play(
          i.isEven ? FeedbackCue.correct : FeedbackCue.incorrect,
          () => true,
        );
        await adapter.stopAll();
      }
      expect(platform.created, 3);
      expect(platform.peakPlaying, 1);
      expect(platform.streams.length, 3);
      expect(platform.releases, everyElement(ReleaseMode.stop));
      expect(
        platform.contexts.every(
          (c) => c.iOS.category == AVAudioSessionCategory.ambient,
        ),
        true,
      );
      expect(
        platform.contexts.every(
          (c) =>
              c.android.usageType == AndroidUsageType.notificationRingtone &&
              !c.android.stayAwake,
        ),
        true,
      );
      await adapter.dispose();
      expect(platform.disposed, 3);
      expect(platform.streams, isEmpty);
    },
  );
  test(
    'invalidated async prepare cannot play a stale tick after lock or mute',
    () async {
      platform.sourceGate = Completer();
      var valid = true;
      final playback = adapter.play(FeedbackCue.tick, () => valid);
      await Future<void>.delayed(Duration.zero);
      valid = false;
      await adapter.stopTicks();
      platform.sourceGate!.complete();
      await playback;
      expect(platform.playing, isEmpty);
    },
  );
  test(
    'effect preempts a playing tick and late effect requests collapse to latest',
    () async {
      await adapter.preload();
      await adapter.play(FeedbackCue.tick, () => true);
      await adapter.play(FeedbackCue.urgentTick, () => true);
      expect(platform.playing.length, 1);
      await adapter.play(FeedbackCue.victory, () => true);
      expect(platform.playing.length, 1);
      final first = adapter.play(FeedbackCue.correct, () => true);
      final second = adapter.play(FeedbackCue.complete, () => true);
      await Future.wait([first, second]);
      expect(platform.created, 3);
      expect(platform.playing.length, 1);
    },
  );
}
