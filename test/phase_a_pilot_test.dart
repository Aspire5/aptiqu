import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/screens/home_screen.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/home/presentation/widgets/topic_details_sheet.dart';
import 'package:aptiqu/features/home/presentation/widgets/question_container_widget.dart';
import 'package:aptiqu/features/home/presentation/widgets/chat_playground_zone.dart';
import 'home_dashboard_test.dart' show fixture;
import 'learning_progress_test.dart' show learningMap, topic;
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'home_navigation_test.dart' show LocalAuth, LocalHome;
import 'practice_catalog_test.dart' show TestFontManifest;

class PilotHome extends LocalHome {
  int? selected;
  String? selectedMessage;
  String? submitted;
  @override
  Future<void> handleTextSubmission(String messageId, String text) async {
    selectedMessage = messageId;
    submitted = text;
  }

  @override
  Future<void> handleOptionSelection(String messageId, int optionIndex) async {
    selected = optionIndex;
    selectedMessage = messageId;
  }
}

final pilotTopic = LearningMapTopicItemModel(
  roadmapStepId: 'pilot-step',
  sequence: 1,
  topicId: 'pilot-topic',
  topicName: 'H.C.F. and L.C.M. of Numbers',
  topicSlug: 'hcf',
  description: 'Learn how factors and multiples help us compare numbers.',
  importance: 'medium',
  teachingMinutes: 30,
  teachingDepth: 2,
  state: 'IN_PROGRESS',
  scriptAvailable: true,
  totalSubtopics: 3,
  completedSubtopics: 1,
  subtopics: [
    SubtopicItemModel(
      id: 'factors',
      title: 'Factors, Multiples and Prime Factorization',
      sequence: 1,
      isCompleted: true,
      isLocked: false,
    ),
    SubtopicItemModel(
      id: 'hcf',
      title: 'Finding the Highest Common Factor',
      sequence: 2,
      isCompleted: false,
      isLocked: false,
    ),
    SubtopicItemModel(
      id: 'soon',
      title: 'Using Factors in Word Problems',
      sequence: 3,
      isCompleted: false,
      isLocked: true,
    ),
  ],
);

QuestionData question({bool evaluated = false}) => QuestionData(
  title: 'Factors',
  desc: 'Which number divides 12 exactly, with nothing left over?',
  inputType: QuestionInputType.select,
  options: ['5', '3', '7', 'A number that is larger than 12'],
  optionIds: ['five', 'three', 'seven', 'larger'],
  hints: ['Try sharing 12 objects equally.'],
  isCompleted: evaluated,
  hasEvaluated: evaluated,
  selectedOptionIndex: evaluated ? 0 : null,
  isUserCorrect: evaluated ? false : null,
  correctOptionId: evaluated ? 'three' : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PilotHome home;
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    font_test.assetManifest = TestFontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (!key.startsWith('test/fonts/')) return null;
          final filename = key
              .split('/')
              .last
              .replaceFirst('SpaceGrotesk', 'Outfit');
          final path = 'test/fonts/phase_a/$filename';
          return ByteData.sublistView(File(path).readAsBytesSync());
        });
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
    Get.put<AuthController>(LocalAuth());
    home = PilotHome();
    Get.put<HomeController>(home);
    Get.put(AppearanceController()).mode.value = ThemeMode.dark;
  });
  tearDown(() => Get.reset());

  Future<void> show(
    WidgetTester tester,
    Widget child,
    ThemeData theme, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('capture'),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts();
      var directory = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final icons = File(
          '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync()) {
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync())),
              ))
              .load();
          break;
        }
        directory = directory.parent;
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PHASE_A')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_a/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final mode in [Brightness.light, Brightness.dark]) {
    ThemeData themeForMode() => mode == Brightness.light
        ? AptiquTheme.lightTheme
        : AptiquTheme.darkTheme;
    test(
      'paired text, controls and answer feedback contrast: ${mode.name}',
      () {
        final theme = themeForMode();
        final c = theme.colorScheme;
        final s = theme.extension<AptiquStatus>()!;
        double contrast(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
        }

        for (final pair in [
          (c.onPrimary, c.primary),
          (c.onPrimaryContainer, c.primaryContainer),
          (c.onSurface, c.surface),
          (c.onSurfaceVariant, c.surfaceContainerHigh),
          (s.success, s.successContainer),
          (c.onErrorContainer, c.errorContainer),
          (s.warning, s.warningContainer),
          (c.onSecondaryContainer, c.secondaryContainer),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
      },
    );

    for (final config in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(430, 932), 1.3),
      (const Size(844, 390), 2.0),
      (const Size(768, 1024), 1.0),
    ]) {
      testWidgets('pilot layout ${mode.name} ${config.$1} scale ${config.$2}', (
        tester,
      ) async {
        final theme = themeForMode();
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
          theme,
          size: config.$1,
          scale: config.$2,
        );
        expect(find.text('Continue learning'), findsOneWidget);
        if (config.$1.width == 390) await capture(tester, 'home-${mode.name}');
        await tester.scrollUntilVisible(
          find.text('View difficulty details'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('View difficulty details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View difficulty details'));
        await tester.pumpAndSettle();
        expect(find.text('By difficulty'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final scroll = ScrollController();
        await show(
          tester,
          TopicDetailsSheet(
            topic: pilotTopic,
            scrollController: scroll,
            onPracticeTopic: () {},
            onPlayTopic: () {},
            onPracticeSubtopic: (_) {},
            onPlaySubtopic: (_) {},
          ),
          theme,
          size: config.$1,
          scale: config.$2,
        );
        if (config.$1.width == 390) await capture(tester, 'topic-${mode.name}');
        await tester.scrollUntilVisible(
          find.text('Using Factors in Word Problems'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await show(
          tester,
          SingleChildScrollView(
            child: QuestionContainerWidget(
              messageId: 'question-id',
              question: question(),
              controller: home,
            ),
          ),
          theme,
          size: config.$1,
          scale: config.$2,
        );
        await tester.ensureVisible(find.text('3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3'));
        expect(home.selected, 1);
        expect(home.selectedMessage, 'question-id');
        expect(
          tester.getSize(find.byType(OutlinedButton).first).height,
          greaterThanOrEqualTo(56),
        );
        await tester.ensureVisible(find.text('Hint (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hint (1)'));
        await tester.pump();
        expect(
          find.text('Hint 1: Try sharing 12 objects equally.'),
          findsOneWidget,
        );
        await show(
          tester,
          SingleChildScrollView(
            child: QuestionContainerWidget(
              messageId: 'question-id',
              question: question(evaluated: true),
              controller: home,
            ),
          ),
          theme,
          size: config.$1,
          scale: config.$2,
        );
        expect(find.text('Correct answer'), findsOneWidget);
        expect(find.text('Your answer · incorrect'), findsOneWidget);
        expect(
          tester
              .widgetList<OutlinedButton>(find.byType(OutlinedButton))
              .every((button) => button.onPressed == null),
          true,
        );
        if (config.$1.width == 390) {
          await capture(tester, 'answer-${mode.name}');
        }
        expect(tester.takeException(), isNull);
        await show(
          tester,
          ConstellationRoadmapView(
            learningMap: learningMap(
              'quant',
              active: 'pilot-step',
              topics: [
                pilotTopic,
                topic('Next topic', state: 'COMING_SOON', playable: false),
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
            onTopicTap: (_) {},
            onRefresh: () async {},
            onToggleFullScreen: () {},
          ),
          theme,
          size: config.$1,
          scale: config.$2,
        );
        if (config.$1.width == 390) {
          await capture(tester, 'topics-${mode.name}');
        }
        await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byType(TopicDetailsSheet), findsOneWidget);
        if (config.$1.width == 390) {
          await capture(tester, 'topic-sheet-${mode.name}');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
      });
    }
  }

  testWidgets('text answer retains message ID and entered answer', (
    tester,
  ) async {
    await show(
      tester,
      SingleChildScrollView(
        child: QuestionContainerWidget(
          messageId: 'text-node',
          question: QuestionData(
            title: 'Answer',
            desc: 'Enter your answer.',
            inputType: QuestionInputType.text,
          ),
          controller: home,
        ),
      ),
      AptiquTheme.lightTheme,
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.enterText(find.byType(TextField), '42');
    await tester.ensureVisible(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    expect(home.submitted, '42');
    expect(home.selectedMessage, 'text-node');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview switch preserves an active conversation and selected answer',
    (tester) async {
      home.showHomeDashboard.value = false;
      final q = question()..selectedOptionIndex = 1;
      home.messages.add(
        ChatMessageModel(
          id: 'saved-question',
          sender: MessageSender.ai,
          text:
              'Share 12 chocolates equally among 3 people. Each person gets 4.',
          time: '10:30',
          question: q,
        ),
      );
      await show(tester, const HomeScreen(), AptiquTheme.darkTheme);
      expect(find.byType(ChatPlaygroundZone), findsOneWidget);
      await capture(tester, 'lesson-dark');
      {
        Get.find<AppearanceController>().mode.value = ThemeMode.light;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(ChatPlaygroundZone))).brightness,
          Brightness.light,
        );
        await capture(tester, 'lesson-light');
        expect(identical(Get.find<HomeController>(), home), true);
        expect(home.messages.single.question?.selectedOptionIndex, 1);
        Get.find<AppearanceController>().mode.value = ThemeMode.system;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(ChatPlaygroundZone))).brightness,
          Brightness.dark,
        );
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(ChatPlaygroundZone))).brightness,
          Brightness.light,
        );
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      }
      await show(
        tester,
        const HomeScreen(),
        AptiquTheme.darkTheme,
        size: const Size(320, 568),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'lesson-small-2x');
      await tester.tap(find.byTooltip('Close lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeDashboardView), findsOneWidget);
      expect(home.messages.single.id, 'saved-question');
    },
  );
}
