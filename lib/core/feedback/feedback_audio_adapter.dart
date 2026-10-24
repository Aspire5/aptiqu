import 'dart:async';
import 'package:audio_session/audio_session.dart' as session;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'feedback_cue.dart';

enum FeedbackInterruption { began, ended, routeChanged }

abstract interface class FeedbackAudioAdapter {
  Stream<FeedbackInterruption> get interruptions;
  Future<void> preload();
  Future<void> play(FeedbackCue cue, bool Function() stillValid);
  Future<void> stopTicks();
  Future<void> stopAll();
  Future<void> dispose();
}

abstract interface class FeedbackHaptics {
  Future<void> sessionStart();
}

class PlatformFeedbackHaptics implements FeedbackHaptics {
  @override
  Future<void> sessionStart() => HapticFeedback.mediumImpact();
}

/// Three native players, fixed for the entire service lifetime. No player pools,
/// tick loops, or per-session player allocation. Only one effect may play.
class PreparedFeedbackAudio implements FeedbackAudioAdapter {
  final _interruptions = StreamController<FeedbackInterruption>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _players = <AudioPlayer>[];
  Future<void>? _loading;
  bool _disposed = false, _tickBusy = false;
  int _tickEpoch = 0, _effectEpoch = 0;
  Future<void>? _effects;
  FeedbackCue? _preparedEffect;
  session.AudioSession? _session;

  @override
  Stream<FeedbackInterruption> get interruptions => _interruptions.stream;

  @override
  Future<void> preload() => _loading ??= _prepare();

  Future<void> _prepare() async {
    if (_disposed) return;
    final context = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationRingtone,
        audioFocus: AndroidAudioFocus.none,
        stayAwake: false,
      ),
      // Ambient inherently mixes with other audio and respects the silent switch.
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    for (var i = 0; i < 3; i++) {
      if (_disposed) return;
      final player = AudioPlayer()..positionUpdater = null;
      _players.add(player);
      await player.setAudioContext(context);
      await player.setReleaseMode(ReleaseMode.stop);
      _subscriptions.add(
        player.onPlayerComplete.listen((_) {
          if (!_disposed &&
              !_players.any((p) => p.state == PlayerState.playing)) {
            unawaited(
              _session
                      ?.setActive(false)
                      .then((_) {})
                      .catchError((Object _) {}) ??
                  Future<void>.value(),
            );
          }
        }),
      );
    }
    await AudioCache.instance.loadAll(
      FeedbackCue.values.map((c) => c.asset).toList(),
    );
    if (_disposed) return;
    await _players[0].setSource(AssetSource(FeedbackCue.tick.asset));
    await _players[1].setSource(AssetSource(FeedbackCue.urgentTick.asset));
    await _players[2].setSource(AssetSource(FeedbackCue.sessionStart.asset));
    _preparedEffect = FeedbackCue.sessionStart;
    if (_disposed) return;
    final audioSession = await session.AudioSession.instance;
    _session = audioSession;
    if (_disposed) return;
    // Apply shared iOS session after the player plugin initializes.
    await audioSession.configure(
      const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.ambient,
        androidAudioAttributes: session.AndroidAudioAttributes(
          contentType: session.AndroidAudioContentType.sonification,
          usage: session.AndroidAudioUsage.notificationRingtone,
        ),
        androidAudioFocusGainType:
            session.AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ),
    );
    if (_disposed) return;
    _subscriptions.add(
      audioSession.interruptionEventStream.listen((event) {
        _interruptions.add(
          event.begin ? FeedbackInterruption.began : FeedbackInterruption.ended,
        );
      }),
    );
    _subscriptions.add(
      audioSession.becomingNoisyEventStream.listen((_) {
        _interruptions.add(FeedbackInterruption.routeChanged);
      }),
    );
    _subscriptions.add(
      audioSession.devicesChangedEventStream.listen((_) {
        _interruptions.add(FeedbackInterruption.routeChanged);
      }),
    );
  }

  @override
  Future<void> play(FeedbackCue cue, bool Function() stillValid) async {
    if (_disposed) return;
    if (cue.isTick) {
      if (_tickBusy) return; // Drop late ticks rather than queueing them.
      _tickBusy = true;
      final epoch = _tickEpoch;
      try {
        await preload();
        if (_disposed || epoch != _tickEpoch || !stillValid()) return;
        if (_players[2].state == PlayerState.playing) return;
        // Even an unusually fast displayed-second jump must never overlap the
        // normal and urgent sources. Both remain prepared for the next tick.
        await _players[cue == FeedbackCue.tick ? 1 : 0].stop();
        final player = _players[cue == FeedbackCue.tick ? 0 : 1];
        if (await _session?.setActive(true) == false) return;
        if (_disposed || epoch != _tickEpoch || !stillValid()) return;
        await player.setVolume(cue.volume);
        await player.seek(Duration.zero);
        if (_disposed || epoch != _tickEpoch || !stillValid()) return;
        await player.resume();
      } finally {
        _tickBusy = false;
      }
      return;
    }
    final epoch = ++_effectEpoch;
    final work = (_effects ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          await preload();
          if (_disposed || epoch != _effectEpoch || !stillValid()) return;
          await stopTicks();
          if (await _session?.setActive(true) == false) return;
          if (_disposed || epoch != _effectEpoch || !stillValid()) return;
          final player = _players[2];
          await player.stop();
          if (_preparedEffect != cue) {
            await player.setSource(AssetSource(cue.asset));
            _preparedEffect = cue;
          }
          await player.setVolume(cue.volume);
          await player.seek(Duration.zero);
          if (_disposed || epoch != _effectEpoch || !stillValid()) return;
          await player.resume();
        });
    _effects = work;
    await work;
  }

  @override
  Future<void> stopTicks() async {
    _tickEpoch++;
    await Future.wait(_players.take(2).map((p) => p.stop()));
  }

  @override
  Future<void> stopAll() async {
    _effectEpoch++;
    await stopTicks();
    if (_players.length == 3) await _players[2].stop();
    await _session?.setActive(false);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _tickEpoch++;
    _effectEpoch++;
    // Allow in-flight native preparation to unwind before releasing its handles.
    try {
      await _loading;
    } catch (_) {}
    try {
      await _effects;
    } catch (_) {}
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    await _interruptions.close();
  }
}
