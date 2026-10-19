import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/screens/home_screen.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'package:aptiqu/features/home/presentation/widgets/topic_details_sheet.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/home/presentation/widgets/question_container_widget.dart';
import 'package:aptiqu/features/home/models/home_dashboard_model.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/profile/presentation/screens/profile_screen.dart';
import 'package:aptiqu/features/profile/presentation/widgets/appearance_setting.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import 'package:aptiqu/shared/widgets/indicators/aptiqu_loading_indicator.dart';
import 'home_navigation_test.dart' show LocalAuth;
import 'home_dashboard_test.dart' show fixture;
import 'phase_a_pilot_test.dart' show PilotHome, pilotTopic, question;
import 'learning_progress_test.dart' show learningMap, topic;
import 'support/presentation_fonts.dart';

class ControlledStorage extends FlutterSecureStorage {
  bool failRead = false, failWrite = false;
  String? saved;
  Completer<String?>? readGate;
  Completer<void>? firstWriteGate;
  int writes = 0;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw PlatformException(code: 'unavailable');
    return readGate != null ? readGate!.future : saved;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    if (writes == 1 && firstWriteGate != null) await firstWriteGate!.future;
    if (failWrite) throw PlatformException(code: 'unavailable');
    saved = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppearanceController appearance;
  late PilotHome home;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    appearance = Get.put(AppearanceController());
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'learner',
      email: 'asha@example.test',
      firstName: 'Asha',
      lastName: 'Learner',
      level: 3,
      totalXp: 140,
      progress: .5,
      xpIntoCurrentLevel: 20,
      xpRequiredForNextLevel: 40,
    );
    home = PilotHome();
    Get.put<HomeController>(home);
  });
  tearDown(() => Get.reset());

  test(
    'System default, saved overrides, restart and unrelated storage',
    () async {
      expect(appearance.mode.value, ThemeMode.system);
      await appearance.load();
      expect(appearance.mode.value, ThemeMode.system);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'existing_session', value: 'keep');
      await appearance.setMode(ThemeMode.light);
      final restarted = AppearanceController();
      await restarted.load();
      expect(restarted.mode.value, ThemeMode.light);
      await restarted.setMode(ThemeMode.system);
      await appearance.load();
      expect(appearance.mode.value, ThemeMode.system);
      expect(await storage.read(key: 'existing_session'), 'keep');
      await storage.write(
        key: AppearanceController.storageKey,
        value: 'invalid',
      );
      await appearance.load();
      expect(appearance.mode.value, ThemeMode.system);
    },
  );
  test(
    'late load and serialized rapid choices preserve the last user choice',
    () async {
      final storage = ControlledStorage()
        ..readGate = Completer<String?>()
        ..firstWriteGate = Completer<void>();
      final controller = AppearanceController(storage: storage);
      final loading = controller.load();
      final dark = controller.setMode(ThemeMode.dark);
      final light = controller.setMode(ThemeMode.light);
      final system = controller.setMode(ThemeMode.system);
      expect(controller.mode.value, ThemeMode.system);
      storage.readGate!.complete('light');
      await loading;
      expect(controller.mode.value, ThemeMode.system);
      storage.firstWriteGate!.complete();
      await Future.wait([dark, light, system]);
      expect(storage.saved, 'system');
    },
  );
  test('storage failure has an honest session-only state and retry', () async {
    final storage = ControlledStorage()
      ..failRead = true
      ..failWrite = true;
    final controller = AppearanceController(storage: storage);
    await controller.load();
    expect(controller.mode.value, ThemeMode.system);
    await controller.setMode(ThemeMode.light);
    expect(controller.mode.value, ThemeMode.light);
    expect(controller.saveError.value, isNotNull);
    storage.failWrite = false;
    await controller.setMode(ThemeMode.light);
    expect(storage.saved, 'light');
    expect(controller.saveError.value, isNull);
  });

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AptiquTheme.darkTheme,
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('phase-b-capture'),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
        home: AppearanceTheme(builder: (context) => Scaffold(body: child)),
      ),
    );
    await loadProductionFontFixtures(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PHASE_B')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('phase-b-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_b/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final config in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(844, 390), 2.0),
      (const Size(568, 320), 2.0),
      (const Size(768, 1024), 1.3),
    ]) {
      testWidgets(
        'Profile, Topics and calendar ${mode.name} ${config.$1} ${config.$2}',
        (tester) async {
          appearance.mode.value = mode;
          await show(
            tester,
            const ProfileScreen(autoFetch: false),
            size: config.$1,
            scale: config.$2,
          );
          await tester.ensureVisible(find.byType(AppearanceSetting));
          await tester.pumpAndSettle();
          if (config.$1.width == 390) {
            await capture(tester, 'profile-appearance-${mode.name}');
          }
          final label = find.byKey(ValueKey('appearance-${mode.name}'));
          final chip = find.ancestor(
            of: label,
            matching: find.byType(ChoiceChip),
          );
          final control = chip.evaluate().isNotEmpty ? chip : label;
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(appearance.mode.value, mode);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Sign out'));
          await tester.tap(find.text('Sign out'));
          await tester.pumpAndSettle();
          expect(find.text('Sign out?'), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(AlertDialog))).brightness,
            mode == ThemeMode.light ? Brightness.light : Brightness.dark,
          );
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(ProfileScreen), findsOneWidget);
          expect(Get.find<AuthController>().currentUser.value, isNotNull);
          String? launched;
          await show(
            tester,
            ConstellationRoadmapView(
              learningMap: learningMap(
                'quant',
                active: 'pilot-step',
                topics: [
                  pilotTopic,
                  topic('Future lesson', state: 'COMING_SOON', playable: false),
                ],
              ),
              subjects: [
                RoadmapSubjectSummary(
                  id: 'quant',
                  slug: 'quant',
                  name: 'Quantitative Aptitude',
                  sequence: 1,
                ),
              ],
              selectedSubjectId: 'quant',
              onSelectSubject: (_) {},
              onTopicTap: (value) => launched = value.roadmapStepId,
              onRefresh: () async {},
              onToggleFullScreen: () {},
            ),
            size: config.$1,
            scale: config.$2,
          );
          await tester.tap(find.text('List'));
          await tester.pumpAndSettle();
          final topicScroll = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          );
          await tester.scrollUntilVisible(
            find.text('Future lesson'),
            120,
            scrollable: topicScroll,
          );
          expect(find.text('Future lesson'), findsOneWidget);
          if (config.$1.width == 390) {
            await capture(tester, 'topics-list-${mode.name}');
          }
          tester.state<ScrollableState>(topicScroll).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.text(pilotTopic.topicName));
          await tester.pumpAndSettle();
          expect(find.byType(TopicDetailsSheet), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('topic-actions')),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(TopicDetailsSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          final action = find.descendant(
            of: find.byKey(const ValueKey('topic-actions')),
            matching: find.byType(FilledButton),
          );
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(launched, 'pilot-step');
          await show(
            tester,
            SingleChildScrollView(
              child: ActivityCalendar(
                today: '2026-10-01',
                days: const [
                  HomeActivityDay('2026-10-01', 0, 0),
                  HomeActivityDay(
                    '2026-10-02',
                    8,
                    6,
                    dailyChallengeCompleted: true,
                  ),
                ],
              ),
            ),
            size: config.$1,
            scale: config.$2,
          );
          final day = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    '2026-10-02: 8 submissions, 6 correct, Daily Challenge completed',
          );
          expect(tester.getSize(day).width, greaterThanOrEqualTo(48));
          await tester.ensureVisible(find.text('View dates as list'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('View dates as list'));
          await tester.pumpAndSettle();
          if (config.$1.width == 390) {
            await capture(tester, 'calendar-dates-${mode.name}');
          }
          await tester.tap(find.text('Fri, 2 Oct'));
          await tester.pumpAndSettle();
          expect(find.text('8 answers submitted\n6 correct'), findsOneWidget);
          expect(find.text('Asia/Kolkata · IST'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Home sheets and embedded lesson ${mode.name}', (tester) async {
      appearance.mode.value = mode;
      await show(
        tester,
        HomeDashboardContent(
          data: fixture(populated: true),
          onRefresh: () async {},
          onResume: (_) {},
          onTopics: () {},
          onRanked: () {},
          onPractice: () {},
          onDaily: () {},
        ),
      );
      await capture(tester, 'home-${mode.name}');
      await tester.ensureVisible(find.text('View difficulty details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View difficulty details'));
      await tester.pumpAndSettle();
      await capture(tester, 'difficulty-${mode.name}');
      expect(find.text('By difficulty'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      home.showHomeDashboard.value = false;
      home.activeScriptTitle.value = 'Factors and multiples';
      home.messages.add(
        ChatMessageModel(
          id: 'lesson',
          sender: MessageSender.ai,
          text:
              'Share 12 chocolates equally among 3 people. Each person gets 4.',
          time: '10:30',
          question: question(evaluated: true),
        ),
      );
      await show(tester, const HomeScreen());
      await capture(tester, 'lesson-${mode.name}');
      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('Your answer · incorrect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'shared button supports keyboard activation and reduced-motion busy semantics',
    (tester) async {
      var calls = 0;
      await show(
        tester,
        Center(
          child: AptiquButton(label: 'Continue', onPressed: () => calls++),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
      final handle = tester.ensureSemantics();
      await show(tester, const AptiquLoadingIndicator());
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.bySemanticsLabel('70%'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'Profile setting updates a live Home conversation without reset',
    (tester) async {
      home.showHomeDashboard.value = false;
      final saved = question()..selectedOptionIndex = 1;
      home.messages.add(
        ChatMessageModel(
          id: 'saved',
          sender: MessageSender.ai,
          text: 'Keep this teaching.',
          time: '10:30',
          question: saved,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(autoFetch: false),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AptiquTheme.darkTheme, routerConfig: router),
      );
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('appearance-light')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance-light')));
      await tester.pumpAndSettle();
      expect(appearance.mode.value, ThemeMode.light);
      expect(
        Theme.of(tester.element(find.byType(AppearanceSetting))).brightness,
        Brightness.light,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(home.messages.single.id, 'saved');
      expect(home.messages.single.question?.selectedOptionIndex, 1);
      expect(identical(Get.find<HomeController>(), home), true);
      expect(find.text('Keep this teaching.'), findsOneWidget);
      expect(find.text('Design preview'), findsNothing);
      expect(
        await const FlutterSecureStorage().read(
          key: AppearanceController.storageKey,
        ),
        'light',
      );
    },
  );

  testWidgets(
    'open sheet follows System; zoom controls stay within gesture limits',
    (tester) async {
      appearance.mode.value = ThemeMode.system;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await show(
        tester,
        ConstellationRoadmapView(
          learningMap: learningMap('q', topics: [pilotTopic]),
          subjects: [
            RoadmapSubjectSummary(
              id: 'q',
              slug: 'q',
              name: 'Quantitative',
              sequence: 1,
            ),
          ],
          selectedSubjectId: 'q',
          onSelectSubject: (_) {},
          onTopicTap: (_) {},
          onRefresh: () async {},
          onToggleFullScreen: () {},
        ),
      );
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byTooltip('Zoom In'));
        await tester.pump();
      }
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        lessThanOrEqualTo(2.200001),
      );
      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byTooltip('Zoom Out'));
        await tester.pump();
      }
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThanOrEqualTo(.349999),
      );
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pilotTopic.topicName));
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(TopicDetailsSheet))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native loading button keeps its label and unavailable tools do not submit',
    (tester) async {
      var calls = 0;
      await show(
        tester,
        AptiquButton(
          label: 'Continue learning',
          isLoading: true,
          onPressed: () => calls++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Continue learning'), findsOneWidget);
      await tester.tap(find.text('Continue learning'));
      expect(calls, 0);
      expect(find.byType(AptiquLoadingIndicator), findsOneWidget);
      for (final type in [QuestionInputType.voice, QuestionInputType.scan]) {
        final q = QuestionData(
          title: 'Tool',
          desc: 'Explain your answer.',
          inputType: type,
        );
        await show(
          tester,
          QuestionContainerWidget(
            messageId: 'tool',
            question: q,
            controller: home,
          ),
        );
        expect(find.textContaining('Coming soon'), findsOneWidget);
        expect(q.isCompleted, false);
        expect(home.messages, isEmpty);
      }
    },
  );
}
