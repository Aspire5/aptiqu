import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/presentation/global_overlay_gate.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:aptiqu/core/progression/models/xp_models.dart';
import 'package:aptiqu/core/routing/app_router.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/widgets/level_up_overlay.dart';
import 'package:aptiqu/features/lesson/views/lesson_feed_screen.dart';
import 'package:aptiqu/features/lesson/views/widgets/doubt_sheet_widget.dart';
import 'package:aptiqu/features/lesson/views/widgets/image_stub_dialog.dart';
import 'package:aptiqu/features/lesson/views/widgets/voice_stub_sheet.dart';
import 'package:aptiqu/features/lesson/views/widgets/text_input_widget.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/social_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'home_navigation_test.dart' show LocalAuth, LocalHome;
import 'social_test.dart' show FakeSocial, ManualStopwatch;
import 'phase_e_social_competitive_test.dart' show EAdapter, ESocket;
import 'support/presentation_fonts.dart';
import 'phase_d_learning_test.dart'
    show QuietDaily, dailySession, dailyResult, questionData;
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_lobby_controller.dart';
import 'package:aptiqu/features/daily_challenge/controllers/daily_challenge_controller.dart';

const longText =
    'Asha shares twelve chocolates equally among three people. '
    'Each person gets four chocolates, with none left over. '
    'Check the result by putting the three equal groups back together: 3 × 4 = 12. ';

Map<String, dynamic> lessonNode(
  String type, {
  String id = 'node-1',
  bool large = false,
}) => {
  'id': id,
  'type': type,
  'interruptible': true,
  'content': {
    'text': type == 'COMPLETION'
        ? 'You can share a quantity into equal groups and check the result.'
        : large
        ? longText * 3
        : type == 'CHOICE'
        ? 'Which part would you like to try next?'
        : type == 'QUESTION'
        ? 'Now try one yourself.'
        : type == 'TEXT_INPUT'
        ? 'Explain how you checked the equal groups.'
        : "Let's see how equal groups work. Asha shares 12 chocolates among 3 people.",
  },
  if (type == 'CHOICE' || type == 'CONTENT')
    'input': {
      'options': [
        {
          'id': 'continue-concrete',
          'label': large
              ? 'Continue with another example using equal groups of chocolates'
              : 'Continue',
        },
        if (type == 'CHOICE')
          {
            'id': 'review-concrete',
            'label': large
                ? 'Review how the number in each group was found'
                : 'Review',
          },
      ],
    },
  if (type == 'TEXT_INPUT') 'input': {'placeholder': 'Explain your check'},
  if (type == 'QUESTION')
    'questionReference': {
      'inlineData': {
        'prompt': large
            ? longText * 2
            : 'How many chocolates does each person get?',
        'difficulty': 'EASY',
        'pyq': large
            ? 'Sample examination with a long source name · 2025'
            : 'Sample exam · 2025',
        'options': [
          for (var i = 0; i < 4; i++)
            {
              'id': 'answer-${i + 1}',
              'label': large
                  ? '${i + 3} chocolates. ${longText * 2}'
                  : '${i + 3} chocolates',
            },
        ],
      },
    },
};

class FAdapter extends EAdapter {
  String type = 'CONTENT';
  String nextType = 'CHOICE';
  bool stubTutor = false;
  bool largeLesson = false,
      failStart = false,
      failAction = false,
      failTutor = false;
  String? title = 'Sharing into equal groups';
  Map<String, dynamic>? next;
  Completer<void>? lessonGate, tutorGate, actionGate;
  int version = 1;
  String nodeId = 'node-1';
  Map<String, dynamic> session(String slug) => {
    'sessionId': 'lesson-$slug',
    'scriptId': 'script-$slug',
    'scriptVersionId': 'script-version',
    'scriptSlug': slug,
    if (title != null) 'scriptTitle': title,
    'status': type == 'COMPLETION' ? 'COMPLETED' : 'ACTIVE',
    'stateVersion': version,
    'isCompleted': type == 'COMPLETION',
    'currentNode': lessonNode(type, id: nodeId, large: largeLesson),
    if (next != null) 'next': next,
  };
  ResponseBody response(Object data, {bool failed = false}) =>
      ResponseBody.fromString(
        jsonEncode({
          'success': !failed,
          'data': data,
          if (failed) 'message': 'Connection unavailable',
        }),
        failed ? 503 : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (o.path.endsWith('/lessons/sessions') ||
        o.path.contains('/roadmaps/steps/')) {
      calls.add(o);
      if (lessonGate != null) await lessonGate!.future;
      final data = o.data as Map;
      return response(
        session('${data['scriptSlug'] ?? 'by-step'}'),
        failed: failStart,
      );
    }
    if (o.path.endsWith('/actions')) {
      calls.add(o);
      if (actionGate != null) await actionGate!.future;
      if (!failAction) {
        type = nextType;
        version++;
        nodeId = 'node-$version';
      }
      return response(session('sharing'), failed: failAction);
    }
    if (o.path.endsWith('/interrupts')) {
      calls.add(o);
      if (tutorGate != null) await tutorGate!.future;
      return response({
        if (stubTutor) 'status': 'STUB_RESPONSE',
        'message': largeLesson
            ? longText * 15
            : 'Three equal groups of four make twelve. Multiply 3 × 4 to check.',
      }, failed: failTutor);
    }
    return super.fetch(o, stream, cancel);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FAdapter adapter;
  late AppearanceController appearance;
  late FakeSocial social;
  late XpController xp;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FAdapter();
    Get.put(
      DioClient(baseUrl: 'http://fixture.invalid/api/v1'),
    ).dio.httpClientAdapter = adapter;
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      firstName: 'Asha',
      email: 'asha@example.test',
      isRegistrationComplete: true,
    );
    social = Get.put<SocialController>(FakeSocial()) as FakeSocial;
    appearance = Get.put(AppearanceController());
    xp = Get.put(XpController());
  });
  tearDown(() {
    Get.reset();
  });
  Future<void> flush(WidgetTester tester, {int ms = 350}) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump();
  }

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
    bool reduced = true,
    GoRouter? router,
    bool global = false,
    Stopwatch? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget frame(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduced,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: RepaintBoundary(
        key: const ValueKey('capture-f'),
        child: global ? SocialOverlay(stopwatch: clock, child: child!) : child!,
      ),
    );
    await tester.pumpWidget(
      router != null
          ? MaterialApp.router(
              theme: AptiquTheme.lightTheme,
              routerConfig: router,
              scaffoldMessengerKey: global ? AppRouter.messengerKey : null,
              builder: frame,
            )
          : MaterialApp(
              theme: appearance.mode.value == ThemeMode.dark
                  ? AptiquTheme.darkTheme
                  : AptiquTheme.lightTheme,
              home: screen,
              builder: frame,
            ),
    );
    await loadProductionFontFixtures(tester);
    await flush(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await flush(tester);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        220,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await flush(tester);
    await tester.tap(target);
    await flush(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PHASE_F')) return;
    await flush(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final b = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-f')),
      );
      final img = await b.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_f/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    });
  }

  Future<void> teardownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  }

  Map<String, dynamic> invite({String id = 'duel', int remaining = 60000}) => {
    'id': id,
    'key': '$id-version-1',
    'remainingMs': remaining,
    'requester': {'id': 'friend', 'name': 'Bea Learner'},
    'timerEnabled': true,
    'smartPicks': false,
  };
  void award(int from, int to) => xp.handleXpUpdate(
    xp: XpProgressModel(level: to, total: to * (to - 1) * 10),
    levelUp: LevelUpModel(
      occurred: true,
      fromLevel: from,
      toLevel: to,
      levelsGained: to - from,
    ),
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final label = mode.name;
    testWidgets('routed content, choices, question and text $label', (
      tester,
    ) async {
      appearance.mode.value = mode;
      await show(tester, const LessonFeedScreen(slug: 'sharing'));
      await capture(tester, 'lesson-content-$label');
      expect(find.text('Sharing into equal groups'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await flush(tester, ms: 600);
      await capture(tester, 'lesson-choice-$label');
      expect(find.text('Review'), findsOneWidget);
      adapter.nextType = 'QUESTION';
      await tap(tester, find.text('Review'));
      await flush(tester, ms: 600);
      await capture(tester, 'lesson-question-$label');
      adapter.nextType = 'TEXT_INPUT';
      adapter.actionGate = Completer<void>();
      await tap(tester, find.widgetWithText(OutlinedButton, '4 chocolates'));
      await capture(tester, 'lesson-submitting-$label');
      final answer =
          adapter.calls.lastWhere((c) => c.path.endsWith('/actions')).data
              as Map;
      expect(answer['currentNodeId'], 'node-3');
      expect(answer['stateVersion'], 3);
      expect(answer['action']['type'], 'QUESTION_ANSWER');
      expect(answer['action']['answer'], 'answer-2');
      expect(answer['action']['responseTimeMs'], isNonNegative);
      adapter.actionGate!.complete();
      await flush(tester, ms: 600);
      await flush(tester);
      await tester.scrollUntilVisible(
        find.byType(TextInputWidget),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await capture(tester, 'lesson-text-$label');
      await tester.enterText(find.byType(TextField), '3 groups of 4 make 12.');
      adapter.nextType = 'COMPLETION';
      await tap(tester, find.byTooltip('Send answer'));
      await flush(tester, ms: 600);
      final text =
          adapter.calls.lastWhere((c) => c.path.endsWith('/actions')).data
              as Map;
      expect(text['action']['type'], 'TEXT_SUBMISSION');
      expect(text['action']['answer'], '3 groups of 4 make 12.');
      await capture(tester, 'lesson-completion-$label');
      expect(find.text('Lesson complete'), findsOneWidget);
      await teardownScreen(tester);
    });
    testWidgets('tutor help, failure/retry and long reply $label', (
      tester,
    ) async {
      appearance.mode.value = mode;
      await show(tester, const LessonFeedScreen(slug: 'sharing'));
      await tap(tester, find.text('Ask tutor'));
      await tester.enterText(find.byType(TextField), 'Why multiply to check?');
      adapter.failTutor = true;
      await tap(tester, find.widgetWithText(FilledButton, 'Ask tutor'));
      expect(
        find.text('Could not reach your tutor. Please try again.'),
        findsOneWidget,
      );
      await capture(tester, 'tutor-error-$label');
      adapter.failTutor = false;
      adapter.largeLesson = true;
      adapter.tutorGate = Completer<void>();
      await tap(tester, find.text('Try again'));
      await capture(tester, 'tutor-busy-$label');
      expect(find.text('Asking tutor…'), findsOneWidget);
      adapter.tutorGate!.complete();
      await flush(tester);
      await flush(tester);
      await capture(tester, 'tutor-reply-$label');
      expect(find.text('Tutor reply'), findsOneWidget);
      await tap(tester, find.byTooltip('Close'));
      expect(find.text('Sharing into equal groups'), findsOneWidget);
      final calls = adapter.calls
          .where((c) => c.path.endsWith('/interrupts'))
          .toList();
      expect(calls.length, 2);
      expect(
        (calls.last.data as Map)['questionText'],
        'Why multiply to check?',
      );
      await teardownScreen(tester);
    });
    testWidgets('initial error and retry keep actual route $label', (
      tester,
    ) async {
      appearance.mode.value = mode;
      adapter.failStart = true;
      await show(tester, const LessonFeedScreen(roadmapStepId: 'step-id'));
      await capture(tester, 'lesson-error-$label');
      expect(find.text('Loading lesson'), findsNothing);
      adapter.failStart = false;
      await tap(tester, find.text('Retry'));
      expect(
        adapter.calls
            .where((c) => c.path.endsWith('/roadmaps/steps/step-id/start'))
            .length,
        2,
      );
      expect(find.text('Sharing into equal groups'), findsOneWidget);
      await teardownScreen(tester);
    });
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      final suffix = '$label-${size.width.toInt()}';
      testWidgets('long question, controls and unknown fallback $suffix', (
        tester,
      ) async {
        appearance.mode.value = mode;
        adapter.type = 'QUESTION';
        adapter.largeLesson = true;
        await show(
          tester,
          const LessonFeedScreen(slug: 'long-question'),
          size: size,
          scale: 2,
        );
        await capture(tester, 'lesson-question-large-$suffix');
        await tester.scrollUntilVisible(
          find.text('D'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await flush(tester);
        expect(find.text('D').hitTestable(), findsOneWidget);
        await capture(tester, 'lesson-options-large-$suffix');
        await tap(tester, find.byTooltip('Lesson tools · Coming soon'));
        await capture(tester, 'lesson-tools-large-$suffix');
        await tap(tester, find.byTooltip('Close'));
        await tap(tester, find.text('Ask tutor'));
        await capture(tester, 'tutor-large-$suffix');
        await tap(tester, find.byTooltip('Close'));
        await teardownScreen(tester);
        adapter.type = 'UNKNOWN';
        adapter.largeLesson = false;
        await show(
          tester,
          const LessonFeedScreen(slug: 'unknown'),
          size: size,
          scale: 2,
        );
        await tester.scrollUntilVisible(
          find.textContaining('This lesson step cannot'),
          200,
        );
        await capture(tester, 'lesson-unknown-large-$suffix');
        await teardownScreen(tester);
      });
      testWidgets('large keyboard composer, stubs and level-up $suffix', (
        tester,
      ) async {
        appearance.mode.value = mode;
        adapter.type = 'TEXT_INPUT';
        await show(
          tester,
          const LessonFeedScreen(slug: 'text'),
          size: size,
          scale: 2,
          keyboard: 100,
        );
        await tester.scrollUntilVisible(
          find.byTooltip('Send answer'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await capture(tester, 'lesson-keyboard-$suffix');
        await tester.enterText(find.byType(TextField), 'A short explanation.');
        await flush(tester);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Send answer',
                ),
              )
              .onPressed,
          isNotNull,
        );
        await tap(tester, find.text('Ask tutor'));
        await capture(tester, 'tutor-keyboard-$suffix');
        final question = find.descendant(
          of: find.byType(DoubtSheetWidget),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(question);
        await flush(tester);
        await tester.enterText(question, 'Explain the check.');
        await flush(tester);
        adapter.largeLesson = true;
        await tap(tester, find.widgetWithText(FilledButton, 'Ask tutor'));
        await flush(tester);
        expect(find.text('Tutor reply'), findsOneWidget);
        await capture(tester, 'tutor-keyboard-reply-$suffix');
        await tap(tester, find.byTooltip('Close'));
        await teardownScreen(tester);
        await show(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Wrap(
                children: [
                  TextButton(
                    onPressed: () => VoiceStubSheet.show(context),
                    child: const Text('Voice'),
                  ),
                  TextButton(
                    onPressed: () => ImageStubDialog.show(context),
                    child: const Text('Scan'),
                  ),
                ],
              ),
            ),
          ),
          size: size,
          scale: 2,
        );
        await tap(tester, find.text('Voice'));
        await capture(tester, 'voice-large-$suffix');
        await tap(tester, find.byTooltip('Close'));
        await tap(tester, find.text('Scan'));
        await capture(tester, 'scan-large-$suffix');
        await tap(tester, find.text('Got it'));
        await teardownScreen(tester);
        await show(
          tester,
          Scaffold(
            body: LevelUpOverlay(
              levelUp: const LevelUpModel(
                occurred: true,
                fromLevel: 2,
                toLevel: 111,
                levelsGained: 109,
              ),
              onContinue: () {},
            ),
          ),
          size: size,
          scale: 2,
        );
        expect(find.text('LEVEL 111'), findsOneWidget);
        await capture(tester, 'level-up-large-$suffix');
        await teardownScreen(tester);
      });
    }
  }

  testWidgets('fast question failure retains selection and permits retry', (
    tester,
  ) async {
    adapter.type = 'QUESTION';
    adapter.failAction = true;
    await show(tester, const LessonFeedScreen(slug: 'retry'));
    await tap(tester, find.widgetWithText(OutlinedButton, '4 chocolates'));
    await flush(tester);
    expect(
      find.text('Could not send your response. Please try that action again.'),
      findsOneWidget,
    );
    expect(find.text('Now try one yourself.'), findsWidgets);
    adapter.failAction = false;
    await tap(tester, find.widgetWithText(OutlinedButton, '4 chocolates'));
    await flush(tester, ms: 600);
    expect(adapter.calls.where((c) => c.path.endsWith('/actions')).length, 2);
    expect(
      find.text('Could not send your response. Please try that action again.'),
      findsNothing,
    );
    expect(find.text('Review'), findsOneWidget);
    await teardownScreen(tester);
  });
  testWidgets(
    'dismissed tutor request cannot update a disposed sheet or lesson',
    (tester) async {
      await show(tester, const LessonFeedScreen(slug: 'help'));
      await tap(tester, find.text('Ask tutor'));
      adapter.tutorGate = Completer<void>();
      await tester.enterText(find.byType(TextField), 'Why is the group equal?');
      await tap(tester, find.widgetWithText(FilledButton, 'Ask tutor'));
      await tap(tester, find.byTooltip('Close'));
      await teardownScreen(tester);
      adapter.tutorGate!.complete();
      await flush(tester);
      await flush(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('fallback title and labelled tools never fabricate submissions', (
    tester,
  ) async {
    adapter.title = null;
    await show(
      tester,
      const LessonFeedScreen(roadmapStepId: 'opaque-id-49383'),
    );
    expect(find.textContaining('49383'), findsNothing);
    final count = adapter.calls.length;
    await tap(tester, find.byTooltip('Lesson tools · Coming soon'));
    await tap(tester, find.text('Voice · Coming soon'));
    expect(
      find.text(
        'Voice answers are not available yet. Use the answer choices or type your response.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.byTooltip('Close'));
    await tap(tester, find.byTooltip('Lesson tools · Coming soon'));
    await tap(tester, find.text('Scan work · Coming soon'));
    expect(
      find.text(
        'Scanning handwritten work is not available yet. Use the answer choices or type your response.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('Got it'));
    expect(adapter.calls.length, count);
    await teardownScreen(tester);
  });
  testWidgets(
    'busy answer prevents a second payload and theme changes retain the question',
    (tester) async {
      adapter.type = 'QUESTION';
      adapter.actionGate = Completer<void>();
      await show(tester, const LessonFeedScreen(slug: 'once'));
      await tester.tap(find.text('4 chocolates'));
      await tester.tap(find.text('5 chocolates'));
      await flush(tester);
      appearance.mode.value = ThemeMode.dark;
      await flush(tester);
      final actions = adapter.calls.where((c) => c.path.endsWith('/actions'));
      expect(actions.length, 1);
      expect((actions.single.data as Map)['action']['answer'], 'answer-2');
      expect(find.text('4 chocolates'), findsWidgets);
      adapter.actionGate!.complete();
      await flush(tester, ms: 600);
      await flush(tester);
      await teardownScreen(tester);
    },
  );
  testWidgets('text input ignores blank send and retains draft on failure', (
    tester,
  ) async {
    adapter.type = 'TEXT_INPUT';
    adapter.failAction = true;
    await show(tester, const LessonFeedScreen(slug: 'written'));
    await tester.scrollUntilVisible(
      find.byTooltip('Send answer'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Send answer',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  My check  ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await flush(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '  My check  ',
    );
    expect(
      (adapter.calls.lastWhere((c) => c.path.endsWith('/actions')).data
          as Map)['action']['answer'],
      'My check',
    );
    await teardownScreen(tester);
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'completion progression variants and long next title ${mode.name}',
      (tester) async {
        appearance.mode.value = mode;
        adapter.type = 'COMPLETION';
        adapter.largeLesson = true;
        for (final state in ['next', 'unpublished', 'complete']) {
          adapter.next = state == 'next'
              ? {
                  'type': 'lesson',
                  'available': true,
                  'roadmapStepId': 'next-step',
                  'scriptTitle':
                      'A long next lesson title about checking equal groups and building on the previous idea',
                }
              : state == 'unpublished'
              ? {
                  'type': 'lesson',
                  'available': false,
                  'reason': 'SCRIPT_NOT_PUBLISHED',
                  'topicName': 'Using equal groups in a new situation',
                }
              : {'type': 'roadmap_complete', 'available': false};
          await show(
            tester,
            const LessonFeedScreen(slug: 'completion'),
            size: const Size(320, 568),
            scale: 2,
          );
          await tester.scrollUntilVisible(
            find.text('Return to Home'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await capture(tester, 'completion-$state-large-${mode.name}');
          if (state == 'unpublished') {
            expect(
              find.textContaining('is not available yet.'),
              findsOneWidget,
            );
          }
          if (state == 'complete') {
            expect(find.text('Roadmap complete'), findsOneWidget);
          }
          await teardownScreen(tester);
        }
      },
    );
    testWidgets(
      'global invitations and celebration defer during routed work ${mode.name}',
      (tester) async {
        appearance.mode.value = mode;
        Get.put<HomeController>(LocalHome());
        AppRouter.router.go('/lesson/sharing');
        await show(
          tester,
          const SizedBox(),
          router: AppRouter.router,
          global: true,
        );
        expect(AppRouter.overlayGate.isTaskActive, isTrue);
        social.duelInvites.assignAll([invite()]);
        award(1, 5);
        await flush(tester);
        await flush(tester);
        expect(find.byType(SocialInvitationDialog), findsNothing);
        expect(find.byType(LevelUpOverlay), findsNothing);
        expect(find.byTooltip('Review duel invitation'), findsOneWidget);
        await capture(tester, 'invitation-deferred-${mode.name}');
        await tap(tester, find.byTooltip('Review duel invitation'));
        expect(find.text('Duel invitation'), findsOneWidget);
        await capture(tester, 'invitation-requested-${mode.name}');
        await tap(tester, find.text('Reject'));
        await flush(tester);
        expect(find.byType(LevelUpOverlay), findsNothing);
        AppRouter.router.go('/');
        await flush(tester);
        await flush(tester);
        expect(find.text('LEVEL 5'), findsOneWidget);
        await capture(tester, 'level-up-safe-boundary-${mode.name}');
        await tap(tester, find.text('Continue'));
        await flush(tester);
        expect(find.byType(LevelUpOverlay), findsNothing);
        expect(xp.progress.value.level, 5);
        await teardownScreen(tester);
      },
    );
  }
  testWidgets(
    'both production aliases preserve parameters and route-owned controller lifecycle',
    (tester) async {
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/lesson/first');
      await show(tester, const SizedBox(), router: AppRouter.router);
      expect(
        (adapter.calls
                .lastWhere((c) => c.path.endsWith('/lessons/sessions'))
                .data
            as Map)['scriptSlug'],
        'first',
      );
      AppRouter.router.go('/lesson/second?stepId=step-two');
      await flush(tester);
      expect(
        adapter.calls.any(
          (c) => c.path.endsWith('/roadmaps/steps/step-two/start'),
        ),
        isTrue,
      );
      AppRouter.router.go('/lesson-step/step-three');
      await flush(tester);
      expect(
        adapter.calls.any(
          (c) => c.path.endsWith('/roadmaps/steps/step-three/start'),
        ),
        isTrue,
      );
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'next lesson pushes once and back restores the completed lesson',
    (tester) async {
      Get.put<HomeController>(LocalHome());
      adapter.type = 'COMPLETION';
      adapter.next = {
        'type': 'lesson',
        'available': true,
        'roadmapStepId': 'next-step',
        'scriptTitle': 'Next equal groups lesson',
      };
      AppRouter.router.go('/lesson/first');
      await show(tester, const SizedBox(), router: AppRouter.router);
      adapter.type = 'CONTENT';
      adapter.title = 'The second lesson';
      await tap(tester, find.text('Continue to next lesson'));
      expect(find.text('The second lesson'), findsOneWidget);
      expect(
        adapter.calls
            .where((c) => c.path.endsWith('/roadmaps/steps/next-step/start'))
            .length,
        1,
      );
      await tap(tester, find.byTooltip('Back'));
      expect(find.text('Lesson complete'), findsOneWidget);
      expect(find.text('Sharing into equal groups'), findsOneWidget);
      await tap(tester, find.text('Return to Home'));
      expect(find.byType(LessonFeedScreen), findsNothing);
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'critical confirmation retains focus then invitation precedes queued celebration',
    (tester) async {
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      unawaited(
        showDialog<void>(
          context: AppRouter.navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Current decision'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep going'),
              ),
            ],
          ),
        ),
      );
      await flush(tester);
      social.duelInvites.assignAll([invite()]);
      award(1, 2);
      award(2, 5);
      await flush(tester);
      await flush(tester);
      expect(find.text('Current decision'), findsOneWidget);
      expect(find.byType(SocialInvitationDialog), findsNothing);
      expect(find.byType(LevelUpOverlay), findsNothing);
      await tap(tester, find.text('Keep going'));
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsOneWidget);
      expect(find.byType(LevelUpOverlay), findsNothing);
      await tap(tester, find.text('Reject'));
      await flush(tester);
      await flush(tester);
      expect(find.text('LEVEL 5'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await flush(tester);
      expect(xp.progress.value.level, 5);
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'deferred invitation keeps its original budget across inbox updates',
    (tester) async {
      final clock = ManualStopwatch();
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/lesson/sharing');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
        clock: clock,
      );
      social.duelInvites.assignAll([invite()]);
      await flush(tester);
      clock.milliseconds = 45000;
      social.duelInvites.assignAll([invite()]);
      await flush(tester);
      expect(find.text('Duel invitation · 15s left'), findsOneWidget);
      await tap(tester, find.byTooltip('Review duel invitation'));
      expect(find.text('15 seconds to respond'), findsOneWidget);
      await tap(tester, find.text('Reject'));
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'deferred invitation expires without a late popup or automatic response',
    (tester) async {
      final clock = ManualStopwatch();
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/lesson/sharing');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
        clock: clock,
      );
      social.duelInvites.assignAll([invite()]);
      await flush(tester);
      clock.milliseconds = 60000;
      await tester.pump(const Duration(seconds: 1));
      await flush(tester);
      await flush(tester);
      expect(find.byTooltip('Review duel invitation'), findsNothing);
      AppRouter.router.go('/');
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsNothing);
      expect(adapter.calls.where((c) => c.path.endsWith('/respond')), isEmpty);
      await teardownScreen(tester);
    },
  );
  testWidgets('pending celebration is discarded on account change', (
    tester,
  ) async {
    Get.put<HomeController>(LocalHome());
    AppRouter.router.go('/lesson/sharing');
    await show(
      tester,
      const SizedBox(),
      router: AppRouter.router,
      global: true,
    );
    award(1, 3);
    await flush(tester);
    Get.find<AuthController>().currentUser.value = const UserModel(
      id: 'other',
      firstName: 'Dev',
      email: 'dev@example.test',
      isRegistrationComplete: true,
    );
    AppRouter.router.go('/');
    await flush(tester);
    await flush(tester);
    expect(find.byType(LevelUpOverlay), findsNothing);
    expect(xp.pendingCelebration.value, isNull);
    await teardownScreen(tester);
  });
  testWidgets(
    'route and Home task guards release only after the scoped work ends',
    (tester) async {
      final gate = GlobalOverlayGate();
      final owner = Object();
      gate.setTask(owner, true);
      expect(gate.canPresentAutomatically, isFalse);
      gate.setTask(owner, false);
      expect(gate.canPresentAutomatically, isTrue);
      final home = Get.put<HomeController>(LocalHome());
      home.showHomeDashboard.value = false;
      AppRouter.router.go('/');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      award(1, 2);
      await flush(tester);
      expect(find.byType(LevelUpOverlay), findsNothing);
      home.exitToHome();
      await flush(tester);
      await flush(tester);
      expect(find.text('LEVEL 2'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await teardownScreen(tester);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
        'Ranked invitation banner preserves timed work ${mode.name}-${size.width.toInt()}',
        (tester) async {
          appearance.mode.value = mode;
          Get.put<HomeController>(LocalHome());
          final socket = ESocket();
          final c = Get.put(
            PvpArenaController(
              matchId: 'match',
              initialPlayersData: [
                {'userId': 'friend', 'firstName': 'Bea Learner'},
              ],
              totalQuestions: 10,
              socketService: socket,
            ),
          );
          socket.emit('QUESTION_STARTED', {
            'questionIndex': 0,
            'question': questionData(0),
            'durationSeconds': 60,
          });
          AppRouter.router.go(
            '/pvp-arena',
            extra: {
              'matchId': 'match',
              'initialPlayersData': <dynamic>[],
              'totalQuestions': 10,
            },
          );
          await show(
            tester,
            const SizedBox(),
            router: AppRouter.router,
            global: true,
            size: size,
            scale: 2,
          );
          social.duelInvites.assignAll([invite()]);
          await flush(tester);
          await flush(tester);
          expect(AppRouter.overlayGate.isTaskActive, isTrue);
          expect(find.byType(SocialInvitationDialog), findsNothing);
          expect(find.byTooltip('Review duel invitation'), findsOneWidget);
          await capture(
            tester,
            'ranked-invitation-large-${mode.name}-${size.width.toInt()}',
          );
          final seconds = c.remainingSeconds.value;
          await tap(tester, find.byTooltip('Review duel invitation'));
          await tap(tester, find.text('Reject'));
          await flush(tester);
          expect(Get.find<PvpArenaController>(), same(c));
          expect(c.currentQuestionIndex.value, 0);
          expect(c.remainingSeconds.value, lessThanOrEqualTo(seconds));
          expect(socket.answers, isEmpty);
          await teardownScreen(tester);
          await socket.events.close();
        },
      );
    }
    testWidgets(
      'Daily answer feedback keeps focus above invitation entry ${mode.name}',
      (tester) async {
        appearance.mode.value = mode;
        Get.put<HomeController>(LocalHome());
        final c = Get.put<DailyChallengeController>(QuietDaily());
        c.activeSession.value = dailySession(long: true);
        c.lastAnswerResult.value = dailyResult();
        c.showExplanation.value = true;
        AppRouter.router.go('/daily-challenge-quiz');
        await show(
          tester,
          const SizedBox(),
          router: AppRouter.router,
          global: true,
          size: const Size(568, 320),
          scale: 2,
        );
        social.duelInvites.assignAll([invite()]);
        award(1, 2);
        await flush(tester);
        await flush(tester);
        expect(find.byType(SocialInvitationDialog), findsNothing);
        expect(find.byType(LevelUpOverlay), findsNothing);
        expect(c.showExplanation.value, isTrue);
        await capture(tester, 'daily-feedback-invitation-large-${mode.name}');
        await tap(tester, find.byTooltip('Review duel invitation'));
        await tap(tester, find.text('Reject'));
        await flush(tester);
        expect(c.showExplanation.value, isTrue);
        await teardownScreen(tester);
      },
    );
  }
  testWidgets(
    'routed controls satisfy native targets, labels and text contrast',
    (tester) async {
      adapter.type = 'QUESTION';
      await show(tester, const LessonFeedScreen(slug: 'accessible'));
      await flush(tester);
      final semantics = tester.ensureSemantics();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        appearance.mode.value = mode;
        await flush(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      semantics.dispose();
      await teardownScreen(tester);
    },
  );
  testWidgets('invitation review restores the active draft and text focus', (
    tester,
  ) async {
    adapter.type = 'TEXT_INPUT';
    Get.put<HomeController>(LocalHome());
    AppRouter.router.go('/lesson/written');
    await show(
      tester,
      const SizedBox(),
      router: AppRouter.router,
      global: true,
    );
    await tester.enterText(find.byType(TextField), 'My unfinished check');
    await flush(tester);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
    social.duelInvites.assignAll([invite()]);
    await flush(tester);
    await flush(tester);
    expect(field.focusNode.hasFocus, isTrue);
    await tap(tester, find.byTooltip('Review duel invitation'));
    await tap(tester, find.text('Reject'));
    await flush(tester);
    await flush(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My unfinished check',
    );
    expect(field.focusNode.hasFocus, isTrue);
    await teardownScreen(tester);
  });
  testWidgets(
    'queued invitations are single and the next one keeps its own budget',
    (tester) async {
      final clock = ManualStopwatch();
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/lesson/sharing');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
        clock: clock,
      );
      social.duelInvites.assignAll([
        invite(),
        invite(id: 'second', remaining: 20000),
      ]);
      await flush(tester);
      clock.milliseconds = 10000;
      await tap(tester, find.byTooltip('Review duel invitation'));
      expect(find.byType(SocialInvitationDialog), findsOneWidget);
      await tap(tester, find.text('Reject'));
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsNothing);
      expect(find.text('Duel invitation · 10s left'), findsOneWidget);
      clock.milliseconds = 20000;
      await tester.pump(const Duration(seconds: 1));
      await flush(tester);
      await flush(tester);
      expect(find.byTooltip('Review duel invitation'), findsNothing);
      expect(adapter.calls.where((c) => c.path.endsWith('/respond')).length, 1);
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'editable focus defers celebration without a keyboard and finishing editing preserves search',
    (tester) async {
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/friends');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      await tester.enterText(find.byType(TextField), 'bea');
      await flush(tester);
      expect(AppRouter.overlayGate.isTaskActive, isFalse);
      award(1, 2);
      await flush(tester);
      await flush(tester);
      expect(find.byType(LevelUpOverlay), findsNothing);
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
        keyboard: 100,
      );
      expect(find.byType(LevelUpOverlay), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await flush(tester);
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      await flush(tester);
      await flush(tester);
      expect(find.text('LEVEL 2'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await flush(tester);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'bea',
      );
      await teardownScreen(tester);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'explicit tutor stub is unavailable rather than a reply ${mode.name}',
      (tester) async {
        appearance.mode.value = mode;
        adapter.stubTutor = true;
        await show(tester, const LessonFeedScreen(slug: 'preview'));
        await tap(tester, find.text('Ask tutor'));
        await tester.enterText(
          find.byType(TextField),
          'Why multiply to check?',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Ask tutor'));
        await flush(tester);
        expect(find.text('Tutor · Coming soon'), findsOneWidget);
        expect(find.text('Tutor reply'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Ask tutor'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Why multiply to check?',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );
        expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);
        await capture(tester, 'tutor-unavailable-${mode.name}');
        await tap(tester, find.byTooltip('Close'));
        expect(
          adapter.calls.where((c) => c.path.endsWith('/interrupts')).length,
          1,
        );
        await teardownScreen(tester);
      },
    );
  }
  testWidgets(
    'Back dismisses invitation without responding and leaves its timed review entry',
    (tester) async {
      Get.put<HomeController>(LocalHome());
      AppRouter.router.go('/');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      social.duelInvites.assignAll([invite()]);
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsNothing);
      expect(find.byTooltip('Review duel invitation'), findsOneWidget);
      expect(adapter.calls.where((c) => c.path.endsWith('/respond')), isEmpty);
      await tap(tester, find.byTooltip('Review duel invitation'));
      await tap(tester, find.text('Reject'));
      await flush(tester);
      await flush(tester);
      expect(find.byTooltip('Review duel invitation'), findsNothing);
      expect(adapter.calls.where((c) => c.path.endsWith('/respond')).length, 1);
      await teardownScreen(tester);
    },
  );
  testWidgets(
    'background matchmaking keeps automatic overlays deferred after changing tabs',
    (tester) async {
      final home = Get.put<HomeController>(LocalHome());
      home.selectedNavIndex.value = 3;
      final socket = ESocket();
      final lobby = Get.put(PvpLobbyController(socketService: socket));
      AppRouter.router.go('/');
      await show(
        tester,
        const SizedBox(),
        router: AppRouter.router,
        global: true,
      );
      await lobby.startMatchmaking();
      home.selectHomeTab();
      await flush(tester);
      social.duelInvites.assignAll([invite()]);
      award(1, 2);
      await flush(tester);
      await flush(tester);
      expect(AppRouter.overlayGate.isTaskActive, isTrue);
      expect(find.byType(SocialInvitationDialog), findsNothing);
      expect(find.byType(LevelUpOverlay), findsNothing);
      lobby.cancelMatchmaking();
      socket.emit('QUEUE_STATUS', {'status': 'LEFT_QUEUE'});
      await flush(tester);
      await flush(tester);
      expect(find.byType(SocialInvitationDialog), findsOneWidget);
      await tap(tester, find.text('Reject'));
      await flush(tester);
      await flush(tester);
      expect(find.text('LEVEL 2'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      expect(socket.joins, 1);
      expect(socket.leaves, 1);
      await teardownScreen(tester);
      await socket.events.close();
    },
  );
}
