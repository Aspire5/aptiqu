import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aptiqu/core/feedback/app_feedback_service.dart';
import 'package:aptiqu/core/feedback/feedback_preferences.dart';
import 'package:aptiqu/core/feedback/feedback_presentation.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/progression/models/xp_models.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/pvp/views/pvp_arena_screen.dart';
import 'package:aptiqu/features/profile/presentation/widgets/feedback_settings.dart';
import 'package:aptiqu/features/home/presentation/widgets/level_up_overlay.dart';
import 'package:aptiqu/shared/widgets/feedback/victory_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'support/feedback_fakes.dart';
import 'support/presentation_fonts.dart';
import 'session_feedback_integration_test.dart' show roundStart, matchResult;

void main() {
  late FeedbackSocket socket;
  late RecordingFeedbackAudio audio;
  late AppFeedbackService feedback;
  late FeedbackClock clock;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(DioClient(baseUrl: 'https://ui.invalid'));
    final auth = Get.put(AuthController());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'me@invalid',
      firstName: 'Asha',
      level: 4,
    );
    audio = RecordingFeedbackAudio();
    clock = FeedbackClock();
    feedback = Get.put(
      AppFeedbackService(
        preferences: Get.put(FeedbackPreferences()),
        audio: audio,
        haptics: RecordingHaptics(),
      ),
    );
    socket = FeedbackSocket();
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_FEEDBACK')) return;
    await loadProductionFontFixtures(tester);
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/evidence/feedback/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    for (final configuration in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 1.3),
      (const Size(390, 844), 2.0),
      (const Size(568, 320), 2.0),
    ]) {
      final size = configuration.$1;
      final scale = configuration.$2;
      final label =
          '${dark ? 'dark' : 'light'}-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(
        'arena active, locked waiting and victory stay readable $label at $scale',
        (tester) async {
          Get.put(AppearanceController()).mode.value = dark
              ? ThemeMode.dark
              : ThemeMode.light;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = Get.put(
            PvpArenaController(
              matchId: 'match',
              initialPlayersData: const [
                {'userId': 'me', 'firstName': 'Asha', 'level': 4},
                {
                  'userId': 'other',
                  'firstName': 'Dev Narayanaswamy',
                  'level': 5,
                },
              ],
              totalQuestions: 10,
              socketService: socket,
              roundClock: clock,
            ),
          );
          socket.emit('QUESTION_STARTED', roundStart(0));
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AptiquTheme.darkTheme : AptiquTheme.lightTheme,
              navigatorObservers: [feedbackRouteObserver],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: const PvpArenaScreen(
                matchId: 'match',
                initialPlayersData: [],
                totalQuestions: 10,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(find.text('What is 2 + 2?'), findsOneWidget);
          expect(find.text('Level 5'), findsOneWidget);
          if (size.width == 390 && scale == 1) {
            await capture(
              tester,
              key,
              'arena-active-${dark ? 'dark' : 'light'}',
            );
          }
          clock.milliseconds = 12000;
          await tester.pump(const Duration(milliseconds: 250));
          c.selectOption('B');
          socket.emit('ANSWER_ACCEPTED', {
            'matchId': 'match',
            'questionIndex': 0,
            'selectedOptionId': 'B',
          });
          clock.milliseconds = 24000;
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(find.text('48s at lock'), findsOneWidget);
          expect(find.text('36s'), findsOneWidget);
          expect(find.text('Submitted'), findsOneWidget);
          expect(
            find.text('Answer locked. Waiting for round to finish…'),
            findsOneWidget,
          );
          if (size.width == 390 && scale == 1) {
            await capture(
              tester,
              key,
              'arena-waiting-${dark ? 'dark' : 'light'}',
            );
          }
          socket.emit('MATCH_COMPLETED', matchResult());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          expect(find.byType(VictoryCelebration), findsOneWidget);
          expect(find.text('Return to Ranked'), findsOneWidget);
          if (size.width == 390 && scale == 1) {
            await capture(
              tester,
              key,
              'arena-victory-${dark ? 'dark' : 'light'}',
            );
          }
          await tester.pumpWidget(const SizedBox());
          feedback.onClose();
          await tester.pump();
        },
      );
      testWidgets(
        'level-up and settings support phone/short-height text $label at $scale',
        (tester) async {
          Get.put(AppearanceController()).mode.value = dark
              ? ThemeMode.dark
              : ThemeMode.light;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          final theme = dark ? AptiquTheme.darkTheme : AptiquTheme.lightTheme;
          Widget host(Widget child) => MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: Scaffold(body: child),
          );
          await tester.pumpWidget(
            host(
              LevelUpOverlay(
                levelUp: const LevelUpModel(
                  occurred: true,
                  fromLevel: 2,
                  toLevel: 5,
                  levelsGained: 3,
                  beforeProgress: XpProgressModel(
                    level: 2,
                    total: 50,
                    progress: .75,
                    xpRequiredForNextLevel: 40,
                  ),
                  afterProgress: XpProgressModel(
                    level: 5,
                    total: 230,
                    xpIntoCurrentLevel: 30,
                    xpRequiredForNextLevel: 100,
                    progress: .3,
                  ),
                ),
                onContinue: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 1900));
          expect(tester.takeException(), isNull);
          expect(find.text('+3 levels'), findsOneWidget);
          if (size.width == 390 && scale == 1) {
            await capture(tester, key, 'level-up-${dark ? 'dark' : 'light'}');
          }
          await tester.pumpWidget(
            host(
              const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: FeedbackSettings(),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Sound & Haptics'), findsOneWidget);
          expect(find.text('Last 10 seconds'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          feedback.onClose();
          await tester.pump();
        },
      );
    }
  }
  testWidgets(
    'settings apply immediately, retain timer choice while muted and persist reload',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(child: FeedbackSettings()),
          ),
        ),
      );
      await tester.tap(find.text('Last 10 seconds'));
      await tester.pump();
      final preferences = Get.find<FeedbackPreferences>();
      expect(preferences.timerAudio.value, TimerAudio.lastTen);
      await tester.tap(find.text('Sound effects'));
      await tester.pump();
      expect(preferences.sounds.value, false);
      final loaded = FeedbackPreferences();
      await loaded.load();
      expect(loaded.sounds.value, false);
      expect(loaded.timerAudio.value, TimerAudio.lastTen);
      expect(audio.played, isEmpty);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
    },
  );
  testWidgets(
    'victory reduced motion is static; finite motion schedules no repeating frames',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: VictoryCelebration(person: const {'name': 'Asha'}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byType(VictoryCelebration), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VictoryCelebration(
              key: const ValueKey('motion'),
              person: const {'name': 'Asha'},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      feedback.onClose();
    },
  );
}
