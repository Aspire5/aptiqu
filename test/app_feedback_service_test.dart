import 'dart:async';
import 'dart:io';
import 'package:aptiqu/core/feedback/app_feedback_service.dart';
import 'package:aptiqu/core/feedback/feedback_audio_adapter.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/core/feedback/feedback_preferences.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'support/feedback_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingFeedbackAudio audio;
  late RecordingHaptics haptics;
  late FeedbackPreferences preferences;
  late AppFeedbackService feedback;
  late FeedbackClock clock;
  late Object scope;
  void playable({bool first = false, String question = 'q'}) {
    feedback.playable(
      scope,
      session: 's',
      question: question,
      first: first,
      fresh: true,
    );
  }

  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    audio = RecordingFeedbackAudio();
    haptics = RecordingHaptics();
    clock = FeedbackClock();
    preferences = Get.put(FeedbackPreferences());
    feedback = Get.put(
      AppFeedbackService(
        preferences: preferences,
        audio: audio,
        haptics: haptics,
        clock: clock,
      ),
    );
    scope = Object();
    feedback.acquire(scope);
    feedback.setVisible(scope, true);
  });
  tearDown(() async {
    feedback.onClose();
    Get.reset();
  });

  test(
    'defaults and exact production assets are the retained approved candidates',
    () {
      expect(preferences.sounds.value, true);
      expect(preferences.haptics.value, true);
      expect(preferences.timerAudio.value, TimerAudio.full);
      final files = Directory('assets/audio/feedback')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .toList();
      expect(files.length, 8);
      expect(
        files.fold<int>(0, (sum, f) => sum + f.lengthSync()),
        lessThan(1024 * 1024),
      );
      for (final cue in FeedbackCue.values) {
        final original = File(
          'docs/sound_haptics_review/audio/${cue.filename}',
        );
        expect(original.existsSync(), true);
        expect(
          File('assets/${cue.asset}').readAsBytesSync(),
          original.readAsBytesSync(),
        );
      }
    },
  );
  testWidgets(
    'start after presentation once; no ticks/haptics from duplicate presentation',
    (tester) async {
      playable(first: true);
      playable(first: true);
      await tester.pump();
      expect(audio.played, [FeedbackCue.sessionStart]);
      expect(haptics.starts, 1);
      feedback.setVisible(scope, false);
      feedback.setVisible(scope, true);
      playable(first: true);
      await tester.pump();
      expect(haptics.starts, 1);
    },
  );
  testWidgets(
    'normal and urgent ticks replace each other, one per visible second',
    (tester) async {
      playable();
      for (final seconds in [12, 12, 11, 10, 10, 9, 0]) {
        feedback.tick(scope, 'q', seconds, answerable: true);
      }
      await tester.pump();
      expect(audio.played, [
        FeedbackCue.tick,
        FeedbackCue.tick,
        FeedbackCue.urgentTick,
        FeedbackCue.urgentTick,
      ]);
      feedback.tick(scope, 'q', 8, answerable: true);
      await tester.pump();
      expect(audio.played.last, FeedbackCue.urgentTick);
    },
  );
  testWidgets(
    'lock silences immediately; feedback and opponent timer are silent',
    (tester) async {
      playable();
      feedback.tick(scope, 'q', 48, answerable: true);
      await tester.pump();
      final before = audio.played.length;
      feedback.lock(scope);
      feedback.tick(scope, 'q', 47, answerable: false);
      await tester.pump();
      expect(audio.tickStops, greaterThan(0));
      expect(audio.played.length, before);
      feedback.playable(
        scope,
        session: 's',
        question: 'next',
        first: false,
        fresh: true,
      );
      feedback.tick(scope, 'next', 60, answerable: true);
      await tester.pump();
      expect(audio.played.last, FeedbackCue.tick);
    },
  );
  testWidgets(
    'zero stops without inventing correctness; confirmed outcome consumed once',
    (tester) async {
      playable();
      feedback.tick(scope, 'q', 0, answerable: true);
      await tester.pump();
      expect(audio.played, isEmpty);
      feedback.answer(scope, 's:q', correct: false);
      feedback.answer(scope, 's:q', correct: true);
      await tester.pump();
      expect(audio.played, [FeedbackCue.incorrect]);
    },
  );
  testWidgets('mute is immediate; timer choice is retained independently', (
    tester,
  ) async {
    playable();
    await preferences.setTimerAudio(TimerAudio.lastTen);
    feedback.tick(scope, 'q', 20, answerable: true);
    await tester.pump();
    expect(audio.played, isEmpty);
    feedback.tick(scope, 'q', 10, answerable: true);
    await tester.pump();
    expect(audio.played.last, FeedbackCue.urgentTick);
    final stops = audio.stops;
    await preferences.setSounds(false);
    expect(audio.stops, greaterThan(stops));
    feedback.tick(scope, 'q', 9, answerable: true);
    await tester.pump();
    expect(audio.played.length, 1);
    final reloaded = FeedbackPreferences();
    await reloaded.load();
    expect(reloaded.sounds.value, false);
    expect(reloaded.timerAudio.value, TimerAudio.lastTen);
    await preferences.setSounds(true);
    await preferences.setTimerAudio(TimerAudio.off);
    feedback.tick(scope, 'q', 8, answerable: true);
    await tester.pump();
    expect(audio.played.length, 1);
  });
  testWidgets(
    'silent sound does not disable independently enabled start haptic',
    (tester) async {
      await preferences.setSounds(false);
      playable(first: true);
      await tester.pump();
      expect(audio.played, isEmpty);
      expect(haptics.starts, 1);
      await preferences.setHaptics(false);
      feedback.playable(
        scope,
        session: 'new',
        question: 'new-q',
        first: true,
        fresh: true,
      );
      expect(haptics.starts, 1);
    },
  );
  testWidgets(
    'hidden/background/interrupted surfaces cannot play stale audio',
    (tester) async {
      playable();
      audio.delayedPlay = Completer();
      feedback.tick(scope, 'q', 30, answerable: true);
      feedback.didChangeAppLifecycleState(AppLifecycleState.paused);
      audio.delayedPlay!.complete();
      await tester.pump();
      expect(audio.played, isEmpty);
      feedback.didChangeAppLifecycleState(AppLifecycleState.resumed);
      audio.delayedPlay = null;
      audio.signals.add(FeedbackInterruption.began);
      feedback.tick(scope, 'q', 29, answerable: true);
      await tester.pump();
      expect(audio.played, isEmpty);
      audio.signals.add(FeedbackInterruption.ended);
      feedback.tick(scope, 'q', 28, answerable: true);
      await tester.pump();
      expect(audio.played, [FeedbackCue.tick]);
      feedback.setVisible(scope, false);
      feedback.tick(scope, 'q', 27, answerable: true);
      await tester.pump();
      expect(audio.played.length, 1);
    },
  );
  testWidgets('new owner and route release invalidate delayed effects', (
    tester,
  ) async {
    audio.delayedPlay = Completer();
    playable(first: true);
    feedback.acquire(Object());
    audio.delayedPlay!.complete();
    await tester.pump();
    expect(audio.played, isEmpty);
    feedback.release(scope);
    feedback.tick(scope, 'q', 30, answerable: true);
    expect(audio.played, isEmpty);
  });
  testWidgets(
    'account switch clears active ownership, never permits old session',
    (tester) async {
      feedback.onClose();
      await Get.delete<AppFeedbackService>(force: true);
      Get.put(DioClient(baseUrl: 'https://feedback.invalid'));
      final auth = Get.put(AuthController());
      auth.currentUser.value = const UserModel(
        id: 'a',
        email: 'a@invalid',
        firstName: 'A',
      );
      feedback = Get.put(
        AppFeedbackService(
          preferences: preferences,
          audio: audio = RecordingFeedbackAudio(),
          haptics: haptics,
        ),
      );
      feedback.acquire(scope);
      feedback.setVisible(scope, true);
      playable();
      auth.currentUser.value = const UserModel(
        id: 'b',
        email: 'b@invalid',
        firstName: 'B',
      );
      feedback.tick(scope, 'q', 20, answerable: true);
      await tester.pump();
      expect(audio.played, isEmpty);
    },
  );
  testWidgets(
    'victory replaces complete; delayed level-up never overlaps victory',
    (tester) async {
      expect(feedback.result(scope, 'match', won: true), true);
      await tester.pump();
      expect(feedback.result(scope, 'match', won: false), false);
      feedback.levelUp('level-2');
      await tester.pump();
      expect(audio.played, [FeedbackCue.victory]);
      await tester.pump(const Duration(seconds: 4));
      expect(audio.played, [FeedbackCue.victory, FeedbackCue.levelUp]);
      feedback.levelUp('level-2');
      await tester.pump();
      expect(audio.played.length, 2);
    },
  );
  testWidgets('history terminal and round recovery stay silent', (
    tester,
  ) async {
    expect(
      feedback.result(scope, 'history', won: true, recovered: true),
      false,
    );
    feedback.answer(scope, 'recovered', correct: true, recovered: true);
    feedback.answer(scope, 'recovered', correct: true);
    feedback.result(scope, 'history', won: true);
    await tester.pump();
    expect(audio.played, isEmpty);
  });
  testWidgets(
    'audio and haptic failures are swallowed; repeated sessions dispose once',
    (tester) async {
      audio.fail = true;
      haptics.fail = true;
      for (var i = 0; i < 20; i++) {
        final next = Object();
        feedback.acquire(next);
        feedback.setVisible(next, true);
        feedback.playable(
          next,
          session: 's-$i',
          question: 'q-$i',
          first: true,
          fresh: true,
        );
        feedback.release(next);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      feedback.onClose();
      await tester.pump();
      expect(audio.disposals, 1);
    },
  );
}
