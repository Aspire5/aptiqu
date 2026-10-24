import 'package:aptiqu/core/feedback/app_feedback_service.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/core/feedback/feedback_preferences.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:aptiqu/core/progression/models/xp_models.dart';
import 'package:aptiqu/core/presentation/global_overlay_gate.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/presentation/widgets/level_up_overlay.dart';
import 'package:aptiqu/features/social/social_overlay.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'social_test.dart' show FakeSocial;
import 'support/feedback_fakes.dart';
import 'support/presentation_fonts.dart';

const after = XpProgressModel(
  level: 3,
  total: 80,
  xpIntoCurrentLevel: 20,
  xpRequiredForNextLevel: 60,
  progress: 1 / 3,
);
const prior = XpProgressModel(
  level: 2,
  total: 50,
  xpIntoCurrentLevel: 30,
  xpRequiredForNextLevel: 40,
  progress: .75,
);
void main() {
  late RecordingFeedbackAudio audio;
  late RecordingHaptics haptics;
  late AppFeedbackService feedback;
  late AuthController auth;
  late XpController xp;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(DioClient(baseUrl: 'https://celebration.invalid'));
    auth = Get.put(AuthController());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'me@invalid',
      firstName: 'Asha',
      level: 2,
      totalXp: 50,
      xpIntoCurrentLevel: 30,
      xpRequiredForNextLevel: 40,
      progress: .75,
      isRegistrationComplete: true,
    );
    audio = RecordingFeedbackAudio();
    haptics = RecordingHaptics();
    feedback = Get.put(
      AppFeedbackService(
        preferences: Get.put(FeedbackPreferences()),
        audio: audio,
        haptics: haptics,
      ),
    );
    xp = Get.put(XpController())..presentationManaged = true;
  });
  tearDown(() {
    Get.reset();
  });
  test(
    'single award captures immutable before and after without changing actual XP',
    () {
      xp.handleXpUpdate(xp: after);
      final award = xp.pendingCelebration.value!;
      expect(award.beforeProgress!.progress, .75);
      expect(award.beforeProgress!.total, 50);
      expect(award.afterProgress, same(after));
      expect(xp.progress.value.total, 80);
      expect(auth.currentUser.value!.totalXp, 80);
      xp.handleXpUpdate(xp: after);
      expect(
        xp.pendingCelebration.value!.beforeProgress,
        same(award.beforeProgress),
      );
      expect(xp.pendingCelebration.value!.afterProgress!.total, 80);
    },
  );
  test(
    'coalesced multiple awards retain earliest real snapshot and latest final value',
    () {
      xp.handleXpUpdate(xp: after);
      const finalXp = XpProgressModel(
        level: 5,
        total: 230,
        xpIntoCurrentLevel: 30,
        xpRequiredForNextLevel: 100,
        progress: .3,
      );
      xp.handleXpUpdate(xp: finalXp);
      final award = xp.pendingCelebration.value!;
      expect(award.fromLevel, 2);
      expect(award.toLevel, 5);
      expect(award.levelsGained, 3);
      expect(award.beforeProgress!.total, 50);
      expect(award.afterProgress, same(finalXp));
      xp.handleXpUpdate(
        xp: finalXp.copyWith(total: 240, xpIntoCurrentLevel: 40, progress: .4),
      );
      expect(xp.pendingCelebration.value!.afterProgress!.total, 240);
    },
  );
  testWidgets(
    'XP fills old threshold, avatar settles, new bar reaches confirmed final fraction',
    (tester) async {
      xp.handleXpUpdate(xp: after);
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.lightTheme,
          home: Scaffold(
            body: LevelUpOverlay(
              levelUp: xp.pendingCelebration.value!,
              onContinue: () {},
            ),
          ),
        ),
      );
      expect(find.text('LEVEL 2'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('previous-level-xp')),
            )
            .value,
        .75,
      );
      await tester.pump(const Duration(milliseconds: 950));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('previous-level-xp')),
            )
            .value,
        1,
      );
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text('LEVEL 3'), findsOneWidget);
      expect(find.text('20 / 60 XP'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('new-level-xp')),
            )
            .value,
        closeTo(1 / 3, .001),
      );
      expect(audio.played, [FeedbackCue.levelUp]);
      expect(haptics.starts, 0);
      await tester.pump();
      expect(audio.played.length, 1);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
    },
  );
  testWidgets(
    'multiple levels show +N once; missing snapshot shows honest final state; Continue never waits',
    (tester) async {
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: Scaffold(
            body: LevelUpOverlay(
              levelUp: const LevelUpModel(
                occurred: true,
                fromLevel: 2,
                toLevel: 5,
                levelsGained: 3,
                afterProgress: XpProgressModel(
                  level: 5,
                  total: 230,
                  xpIntoCurrentLevel: 30,
                  xpRequiredForNextLevel: 100,
                  progress: .3,
                ),
              ),
              onContinue: () {
                continued = true;
              },
            ),
          ),
        ),
      );
      expect(find.text('LEVEL 5'), findsOneWidget);
      expect(find.text('+3 levels'), findsOneWidget);
      expect(find.byKey(const ValueKey('previous-level-xp')), findsNothing);
      await tester.tap(find.text('Continue'));
      expect(continued, true);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
    },
  );
  testWidgets(
    'reduced motion renders final progress immediately with a single sound',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: LevelUpOverlay(
                levelUp: const LevelUpModel(
                  occurred: true,
                  fromLevel: 2,
                  toLevel: 3,
                  levelsGained: 1,
                  beforeProgress: prior,
                  afterProgress: after,
                ),
                onContinue: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('LEVEL 3'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('new-level-xp')),
            )
            .value,
        closeTo(1 / 3, .001),
      );
      expect(audio.played, [FeedbackCue.levelUp]);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
    },
  );
  testWidgets(
    'safe overlay gate queues during active gameplay and presents one coalesced celebration later',
    (tester) async {
      Get.put<SocialController>(FakeSocial());
      final navKey = GlobalKey<NavigatorState>();
      final gate = GlobalOverlayGate();
      final task = Object();
      gate.setTask(task, true);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [gate],
          theme: AptiquTheme.lightTheme,
          builder: (context, child) =>
              SocialOverlay(gate: gate, navigatorKey: navKey, child: child!),
          home: const Scaffold(body: Text('Session')),
        ),
      );
      xp.handleXpUpdate(xp: after);
      xp.handleXpUpdate(
        xp: const XpProgressModel(
          level: 4,
          total: 130,
          xpIntoCurrentLevel: 10,
          xpRequiredForNextLevel: 80,
          progress: .125,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(LevelUpOverlay), findsNothing);
      expect(audio.played, isEmpty);
      gate.setTask(task, false);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LevelUpOverlay), findsOneWidget);
      expect(find.text('+2 levels'), findsOneWidget);
      expect(audio.played, [FeedbackCue.levelUp]);
      auth.currentUser.value = null;
      await tester.pump();
      await tester.pump();
      expect(xp.pendingCelebration.value, isNull);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
      gate.dispose();
    },
  );
}
