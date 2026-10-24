import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'feedback_audio_adapter.dart';
import 'feedback_cue.dart';
import 'feedback_preferences.dart';

/// Cosmetic events only. This service never drives a question clock or grading.
class AppFeedbackService extends GetxService with WidgetsBindingObserver {
  AppFeedbackService({
    required this.preferences,
    FeedbackAudioAdapter? audio,
    FeedbackHaptics? haptics,
    Stopwatch? clock,
  }) : audio = audio ?? PreparedFeedbackAudio(),
       haptics = haptics ?? PlatformFeedbackHaptics(),
       _clock = (clock ?? Stopwatch())..start();
  static AppFeedbackService? get maybe => Get.isRegistered<AppFeedbackService>()
      ? Get.find<AppFeedbackService>()
      : null;
  final FeedbackPreferences preferences;
  final FeedbackAudioAdapter audio;
  final FeedbackHaptics haptics;
  final _receipts = <String>{};
  final _workers = <Worker>[];
  final Stopwatch _clock;
  StreamSubscription? _interruptions;
  Object? _scope;
  String? _owner, _question;
  int? _lastSecond;
  int _epoch = 0, _eventUntil = 0;
  bool _visible = false, _answerable = false, _foreground = true;
  bool _interrupted = false, _closed = false;
  Timer? _levelUpDelay;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _workers.add(ever(preferences.sounds, (_) => _silence()));
    _workers.add(ever(preferences.timerAudio, (_) => stopTicks()));
    _interruptions = audio.interruptions.listen((event) {
      _interrupted = event == FeedbackInterruption.began;
      _silence(); // Ended/routing events never replay a missed cue.
    });
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _owner = auth.currentUser.value?.id;
      _workers.add(
        ever(auth.currentUser, (user) {
          if (_owner == user?.id) return;
          _owner = user?.id;
          _scope = null;
          _visible = false;
          _answerable = false;
          _receipts.clear();
          _silence();
        }),
      );
    }
  }

  void _safe(Future<void> Function() operation) {
    if (_closed) return;
    unawaited(Future<void>.sync(operation).catchError((Object _) {}));
  }

  bool get _audible =>
      !_closed && _foreground && !_interrupted && preferences.sounds.value;
  bool _owns(Object scope) => identical(_scope, scope);
  bool _once(String key) {
    if (!_receipts.add('${_owner ?? 'device'}:$key')) return false;
    if (_receipts.length > 256) _receipts.remove(_receipts.first);
    return true;
  }

  void prewarm() {
    if (preferences.sounds.value) _safe(audio.preload);
  }

  void acquire(Object scope) {
    _silence();
    _scope = scope;
    _visible = false;
    _answerable = false;
    _question = null;
    _lastSecond = null;
    if (preferences.sounds.value) _safe(audio.preload);
  }

  void setVisible(Object scope, bool value) {
    if (!_owns(scope)) return;
    _visible = value;
    if (!value) _silence();
  }

  void playable(
    Object scope, {
    required String session,
    required String question,
    required bool first,
    required bool fresh,
  }) {
    if (!_owns(scope)) return;
    if (_question != question) {
      stopTicks();
      _question = question;
      _lastSecond = null;
    }
    _answerable = true;
    // Consume even if muted/backgrounded. Returning must never replay the start.
    if (first &&
        _once('start:$session') &&
        fresh &&
        _visible &&
        _foreground &&
        !_interrupted) {
      _effect(FeedbackCue.sessionStart);
      if (preferences.haptics.value) _safe(haptics.sessionStart);
    }
  }

  void tick(
    Object scope,
    String question,
    int seconds, {
    required bool answerable,
  }) {
    if (!_owns(scope) || _question != question) return;
    _answerable = answerable;
    if (!answerable || seconds <= 0) {
      stopTicks();
      return;
    }
    if (_lastSecond == seconds) return;
    _lastSecond = seconds;
    final mode = preferences.timerAudio.value;
    if (!_audible ||
        !_visible ||
        mode == TimerAudio.off ||
        (mode == TimerAudio.lastTen && seconds > 10) ||
        _clock.elapsedMilliseconds < _eventUntil) {
      return;
    }
    final epoch = _epoch;
    _safe(
      () => audio.play(
        seconds <= 10 ? FeedbackCue.urgentTick : FeedbackCue.tick,
        () =>
            epoch == _epoch &&
            _owns(scope) &&
            _visible &&
            _audible &&
            _answerable &&
            _question == question &&
            _lastSecond == seconds,
      ),
    );
  }

  void lock(Object scope) {
    if (!_owns(scope)) return;
    _answerable = false;
    stopTicks();
  }

  void answer(
    Object scope,
    String receipt, {
    required bool correct,
    bool recovered = false,
  }) {
    if (!_owns(scope)) return;
    lock(scope);
    if (_once('answer:$receipt') && !recovered && _visible) {
      _effect(correct ? FeedbackCue.correct : FeedbackCue.incorrect);
    }
  }

  /// Results are called only at an authoritative terminal state. History/recovery
  /// consumes the receipt silently and cannot later turn into a fresh fanfare.
  bool result(
    Object scope,
    String receipt, {
    required bool won,
    bool recovered = false,
  }) {
    if (!_owns(scope)) return false;
    lock(scope);
    final fresh = _once('result:$receipt') && !recovered;
    if (fresh && _visible) {
      _effect(won ? FeedbackCue.victory : FeedbackCue.complete);
    }
    return fresh && _visible && _foreground;
  }

  void levelUp(String receipt) {
    if (!_once('level:$receipt') || !_foreground || _answerable) return;
    _levelUpDelay?.cancel();
    final epoch = _epoch;
    final wait = (_eventUntil - _clock.elapsedMilliseconds).clamp(0, 4000);
    void play() {
      if (epoch == _epoch && !_answerable) _effect(FeedbackCue.levelUp);
    }

    if (wait == 0) {
      play();
    } else {
      _levelUpDelay = Timer(Duration(milliseconds: wait + 80), play);
    }
  }

  void dismissLevelUp() {
    _levelUpDelay?.cancel();
    _silence();
  }

  void _effect(FeedbackCue cue) {
    if (!_audible) return;
    stopTicks();
    final epoch = _epoch;
    _eventUntil = _clock.elapsedMilliseconds + cue.durationMs + 100;
    _safe(() => audio.play(cue, () => epoch == _epoch && _audible));
  }

  void stopTicks() {
    _safe(audio.stopTicks);
  }

  void release(Object scope) {
    if (!_owns(scope)) return;
    _scope = null;
    _visible = false;
    _answerable = false;
    _silence();
  }

  void _silence() {
    _epoch++;
    _eventUntil = 0;
    _levelUpDelay?.cancel();
    _safe(audio.stopAll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _silence();
  }

  @override
  void onClose() {
    if (_closed) return;
    _silence();
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final worker in _workers) {
      worker.dispose();
    }
    _interruptions?.cancel();
    _clock.stop();
    unawaited(audio.dispose().catchError((Object _) {}));
    super.onClose();
  }
}
