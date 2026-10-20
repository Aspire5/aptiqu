import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'package:aptiqu/features/daily_challenge/models/daily_challenge_models.dart';
import 'package:aptiqu/features/daily_challenge/presentation/screens/daily_challenge_quiz_screen.dart';
import 'package:aptiqu/features/daily_challenge/presentation/screens/daily_streak_hub_screen.dart';
import 'package:aptiqu/features/practice/controllers/practice_catalog_controller.dart';
import 'package:aptiqu/features/practice/controllers/practice_session_controller.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/views/practice_catalog_view.dart';
import 'package:aptiqu/features/practice/views/practice_session_screen.dart';
import 'package:aptiqu/shared/widgets/questions/question_presentation.dart';
import 'package:aptiqu/features/daily_challenge/repositories/daily_challenge_repository.dart';
import 'package:flutter/material.dart';
import 'package:aptiqu/core/routing/app_router.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'practice_catalog_test.dart' show CatalogRepository;
import 'practice_session_test.dart' show FakeRepository, TestClock;
import 'support/presentation_fonts.dart';

const explanation =
    'Share 12 chocolates equally among 3 people. Each person gets 4, with none left over.\n\n12 ÷ 3 = 4\n\nCheck: 3 × 4 = 12.';
const reason =
    'The division uses the equal groups directly. The alternative method gives the same result by counting groups.';
Map<String, dynamic> questionData(int i, {bool long = false}) => {
  'id': 'q-$i',
  'prompt':
      'Share 12 chocolates equally among 3 people. How many chocolates does each person get?',
  'difficulty': 'EASY',
  'calculationMode': 'SPEED',
  'options': [
    {'id': 'A', 'text': '3 chocolates'},
    {'id': 'B', 'text': '4 chocolates'},
    {'id': 'C', 'text': '5 chocolates'},
    {
      'id': 'D',
      'text': long
          ? '6 chocolates, with a longer option that needs to wrap without hiding its meaning.'
          : '6 chocolates',
    },
  ],
  'hints': [
    'Think about sharing the chocolates into 3 equal groups.',
    'Divide the total number of chocolates by the number of people.',
  ],
  'pyq': long
      ? 'Sample exam · A long source label with date and examination details'
      : 'Sample exam · 2025',
  'explanation': explanation,
  'method': '12 ÷ 3 = 4',
  'alternativeExplanation': 'Count 3 groups of 4.\n\n4 + 4 + 4 = 12.',
  'preferredSolution': 'BOOK',
  'preferredReason': reason,
};
PracticeSessionModel practice({
  bool replay = false,
  bool timer = false,
  bool friendly = false,
  bool completed = false,
  bool long = false,
}) => PracticeSessionModel.fromJson({
  'id': 'session',
  'status': completed ? 'COMPLETED' : 'IN_PROGRESS',
  'isReplay': replay,
  'timerEnabled': timer,
  'isFriendlyDuel': friendly,
  'friendlyDuelId': friendly ? 'duel' : null,
  'totalQuestions': 2,
  'correctCount': completed ? 2 : 0,
  'xpAwarded': completed && !replay ? 10 : 0,
  'questions': [
    for (var i = 0; i < 2; i++)
      {
        'id': 'sq-$i',
        'sequence': i + 1,
        'isAnswered': false,
        'question': questionData(i, long: long),
      },
  ],
});
DailyChallengeSessionModel dailySession({bool long = false}) =>
    DailyChallengeSessionModel.fromJson({
      'participationId': 'daily',
      'totalQuestions': 2,
      'questions': [
        for (var i = 0; i < 2; i++)
          {
            'sequence': i + 1,
            'difficulty': 'MEDIUM',
            'question': questionData(i, long: long),
          },
      ],
    });
DailyChallengeAnswerResultModel dailyResult({
  bool correct = true,
  bool complete = false,
  bool success = true,
}) => DailyChallengeAnswerResultModel.fromJson({
  'isCorrect': correct,
  'correctAnswer': 'B',
  'explanation': explanation,
  'method': '12 ÷ 3 = 4',
  'alternativeExplanation': 'Count 3 equal groups of 4.\n\n4 + 4 + 4 = 12.',
  'preferredSolution': 'ALTERNATIVE',
  'preferredReason': reason,
  'sequence': 1,
  'isComplete': complete,
  'answeredCount': complete ? 2 : 1,
  'totalQuestions': 2,
  'correctCount': success ? 2 : 1,
  'streak': success ? 12 : 0,
  'streakIncremented': success && complete,
  'xpAwarded': success && complete ? 10 : 0,
  'coinsAwarded': success && complete ? 5 : 0,
});
DailyChallengeStatusModel dailyStatus({
  bool finished = false,
  bool resume = false,
  bool failed = false,
}) => DailyChallengeStatusModel.fromJson({
  'streak': 11,
  'highestStreak': 15,
  'canAttempt': !finished,
  'isCompletedToday': finished,
  'questionCount': 2,
  'tierTitle': 'Daily learner',
  'msUntilMidnight': 7200000,
  if (resume || finished)
    'todayParticipation': {
      'id': 'daily',
      'status': resume
          ? 'IN_PROGRESS'
          : failed
          ? 'FAILED'
          : 'COMPLETED',
    },
});

class QuietDaily extends DailyChallengeController {
  QuietDaily({super.repository});
  @override
  // ignore: must_call_super
  void onInit() {}
}

class DailyFixture extends QuietDaily {
  int statusCalls = 0, historyCalls = 0, starts = 0;
  @override
  Future<void> fetchStatus() async {
    statusCalls++;
  }

  @override
  Future<void> fetchHistory({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    historyCalls++;
  }

  @override
  Future<void> startDailyChallenge(BuildContext context) async {
    starts++;
  }
}

class LearningRepository extends FakeRepository {
  @override
  Future<PracticeAnswerResultModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
    dynamic cancelToken,
  }) async {
    calls++;
    option = selectedOptionId;
    if (pending != null) return pending!.future;
    return PracticeAnswerResultModel(
      isCorrect: selectedOptionId == 'B',
      correctAnswer: 'B',
      explanation: explanation,
      method: '12 ÷ 3 = 4',
      alternativeExplanation: 'Count 3 equal groups of 4.\n\n4 + 4 + 4 = 12.',
      preferredSolution: 'BOOK',
      preferredReason: reason,
      isComplete: false,
      totalAnswered: 1,
      correctCount: selectedOptionId == 'B' ? 1 : 0,
      xpAwarded: 0,
    );
  }

  @override
  Future<({int remainingMs, PracticeSessionModel session})>
  startFriendlyQuestion(String sessionId) async =>
      (remainingMs: 60000, session: practice(friendly: true));
}

class FriendlyRepository extends LearningRepository {
  bool failClock = false;
  @override
  Future<({int remainingMs, PracticeSessionModel session})>
  startFriendlyQuestion(String sessionId) async {
    if (failClock) throw Exception('Clock unavailable');
    return (remainingMs: 60000, session: practice(friendly: true));
  }
}

class FailingPracticeRepository extends LearningRepository {
  bool fail = true;
  @override
  Future<PracticeAnswerResultModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
    dynamic cancelToken,
  }) async {
    if (fail) throw Exception('Connection failed. Please try again.');
    return super.submitAnswer(
      sessionId: sessionId,
      questionId: questionId,
      selectedOptionId: selectedOptionId,
      responseTimeMs: responseTimeMs,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<PracticeSessionModel> getSession(
    String sessionId, {
    dynamic cancelToken,
  }) async => practice();
}

class HistoryRepository extends CatalogRepository {
  bool fail = false;
  final pages = <int>[];
  @override
  Future<PracticeHistoryResponseModel> getHistory({
    int page = 1,
    int limit = 20,
  }) async {
    pages.add(page);
    if (fail) throw Exception('offline');
    return PracticeHistoryResponseModel(
      history: [
        PracticeHistoryItemModel.fromJson({
          'id': 'session-$page',
          'createdAt': '2026-10-18T12:00:00Z',
          'status': 'COMPLETED',
          'correctCount': 8,
          'xpAwarded': 10,
        }),
      ],
      completedDrillsCount: 3,
      overallAccuracy: 80,
      avgResponseTimeMs: 12000,
      page: page,
      totalPages: 2,
    );
  }
}

class DailyAdapter extends DailyChallengeRepository {
  int answerCalls = 0, startCalls = 0;
  final pages = <int>[];
  bool failHistory = false, failAnswer = false, failStart = false;
  Map<String, dynamic>? answerPayload;
  Completer<void>? answerGate, startGate;
  @override
  Future<DailyChallengeStatusModel> getStatus() async => dailyStatus();
  @override
  Future<DailyHistoryResponseModel> getHistory({
    int page = 1,
    int limit = 10,
  }) async {
    pages.add(page);
    if (failHistory) throw Exception('Connection failed. Please try again.');
    return DailyHistoryResponseModel.fromJson({
      'history': [
        {
          'id': 'daily-$page',
          'dateString': '2026-10-${20 - page}',
          'status': 'COMPLETED',
          'correctCount': 2,
          'totalQuestions': 2,
          'xpAwarded': 10,
        },
      ],
      'pagination': {'page': page, 'totalPages': 2},
    });
  }

  @override
  Future<DailyChallengeSessionModel> startChallenge() async {
    startCalls++;
    if (startGate != null) await startGate!.future;
    if (failStart) throw Exception('Connection failed. Please try again.');
    return dailySession();
  }

  @override
  Future<DailyChallengeAnswerResultModel> submitAnswer({
    required String participationId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
  }) async {
    answerCalls++;
    answerPayload = {
      'participationId': participationId,
      'questionId': questionId,
      'selectedOptionId': selectedOptionId,
      'responseTimeMs': responseTimeMs,
    };
    if (answerGate != null) await answerGate!.future;
    if (failAnswer) throw Exception('Connection failed. Please try again.');
    return dailyResult(correct: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppearanceController appearance;
  late DailyAdapter adapter;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://fixture.invalid'));
    adapter = DailyAdapter();
    appearance = Get.put(AppearanceController());
  });
  tearDown(() => Get.reset());
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    GoRouter? router,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget frame(BuildContext context, Widget child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: RepaintBoundary(key: const ValueKey('capture-d'), child: child),
    );
    await tester.pumpWidget(
      router == null
          ? MaterialApp(
              theme: appearance.mode.value == ThemeMode.light
                  ? AptiquTheme.lightTheme
                  : AptiquTheme.darkTheme,
              builder: (context, child) => frame(context, child!),
              home: screen,
            )
          : MaterialApp.router(
              theme: AptiquTheme.darkTheme,
              routerConfig: router,
              builder: (context, child) => frame(context, child!),
            ),
    );
    await loadProductionFontFixtures(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PHASE_D')) return;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-d')),
      );
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_d/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  DailyFixture hub() {
    final c = Get.put<DailyChallengeController>(DailyFixture()) as DailyFixture;
    c.status.value = dailyStatus();
    c.isLoadingStatus.value = false;
    return c;
  }

  PracticeSessionController player({
    bool replay = false,
    bool timer = false,
    bool completed = false,
    bool long = false,
  }) => Get.put(
    PracticeSessionController(
      practice(replay: replay, timer: timer, completed: completed, long: long),
      repository: LearningRepository(),
      stopwatch: TestClock(),
    ),
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode.name;
    testWidgets('practice setup and custom selection $suffix', (tester) async {
      appearance.mode.value = mode;
      final c = Get.put(
        PracticeCatalogController(repository: CatalogRepository()),
      );
      await show(tester, const Scaffold(body: PracticeCatalogView()));
      await capture(tester, 'practice-setup-$suffix');
      for (final title in [
        'Friendly duel',
        'Smart AI Picks',
        '60-second timer',
      ]) {
        await tap(tester, find.text(title));
      }
      expect(
        c.friendlyDuel.value && c.smartPicks.value && c.timerEnabled.value,
        isTrue,
      );
      for (final title in [
        'Friendly duel',
        'Smart AI Picks',
        '60-second timer',
      ]) {
        await tap(tester, find.text(title));
      }

      await tap(tester, find.text('Custom'));
      c.toggleTopic('numbers');
      expect(c.isTopicFullySelected('numbers'), isTrue);
      c.toggleSubtopic('n1');
      expect(c.isTopicPartiallySelected('numbers'), isTrue);
      await tap(tester, find.text('All'));
      expect(c.selectedSubtopicIds.length, 3);
      await tester.drag(
        find.byKey(const PageStorageKey('practice-setup')),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'practice-custom-$suffix');
      await tap(tester, find.text('Clear'));
      expect(c.selectedSubtopicIds, isEmpty);
      expect(
        find.text('Select at least one subtopic to continue.'),
        findsOneWidget,
      );
      await show(
        tester,
        const Scaffold(body: PracticeCatalogView()),
        size: const Size(320, 568),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('practice answer, hints and preferred reason $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = player();
      await show(
        tester,
        PracticeSessionScreen(initialSession: c.session.value),
      );
      await capture(tester, 'practice-player-$suffix');
      await tap(tester, find.byTooltip('Hints'));
      expect(c.hintsRevealed.value, 0);
      await tap(tester, find.text('Reveal hint 1'));
      expect(c.hintsRevealed.value, 1);
      await tap(tester, find.text('Reveal hint 2'));
      expect(c.hintsRevealed.value, 2);
      await capture(tester, 'practice-hints-$suffix');
      await tap(tester, find.byTooltip('Close'));
      await tap(tester, find.text('4 chocolates'));
      expect(c.selectedOptionId.value, 'B');
      await tap(tester, find.text('Submit answer'));
      expect(c.lastResult.value, isNotNull);
      await tester.ensureVisible(find.byType(AnswerFeedback));
      await tester.pumpAndSettle();
      await capture(tester, 'practice-feedback-$suffix');
      await tap(tester, find.text('AI preferred'));
      expect(find.text(reason), findsOneWidget);
      await capture(tester, 'practice-reason-$suffix');
      await tap(tester, find.text('Got it'));
      await tap(tester, find.text('Next question'));
      expect(c.currentQuestionIndex.value, 1);
      expect(c.hintsRevealed.value, 0);
    });
    testWidgets('practice replay completion fits enlarged landscape $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = player(replay: true, completed: true);
      await show(
        tester,
        PracticeSessionScreen(initialSession: c.session.value),
        size: const Size(568, 320),
        scale: 2,
      );
      await tester.ensureVisible(find.text('Return to practice'));
      await tester.pumpAndSettle();
      expect(find.text('Replays do not earn rewards.'), findsOneWidget);
      await capture(tester, 'practice-result-large-$suffix');
    });
    testWidgets('daily hub composition, preparation and history $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = hub();
      await show(tester, const DailyStreakHubScreen());
      await capture(tester, 'daily-hub-$suffix');
      await tap(tester, find.text('Start daily challenge'));
      expect(c.starts, 1);
      c.status.value = dailyStatus(resume: true);
      await tester.pumpAndSettle();
      await capture(tester, 'daily-resume-$suffix');
      expect(find.text('Resume challenge'), findsOneWidget);
      c.historyList.assignAll([
        DailyHistoryItemModel.fromJson({
          'id': 'd',
          'dateString': '2026-10-18',
          'status': 'COMPLETED',
          'correctCount': 2,
          'totalQuestions': 2,
          'xpAwarded': 10,
          'coinsAwarded': 5,
          'avgTimeMs': 14000,
        }),
      ]);
      await tap(tester, find.byTooltip('Daily history'));
      await capture(tester, 'daily-history-$suffix');
      await tap(tester, find.byTooltip('Close'));
      c.isStarting.value = true;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.history_rounded),
            )
            .onPressed,
        isNull,
      );
      await capture(tester, 'daily-preparing-$suffix');
    });
    testWidgets('practice history and daily completed states $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final repo = HistoryRepository();
      final c = Get.put(PracticeCatalogController(repository: repo));
      await tester.pumpAndSettle();
      await c.fetchHistory();
      c.showHistory.value = true;
      await show(tester, const Scaffold(body: PracticeCatalogView()));
      await capture(tester, 'practice-history-$suffix');
      repo.fail = true;
      await c.fetchHistory(refresh: true);
      await tester.pumpAndSettle();
      await capture(tester, 'practice-history-error-$suffix');
      final d = hub();
      d.status.value = dailyStatus(finished: true);
      await show(tester, const DailyStreakHubScreen());
      await capture(tester, 'daily-completed-$suffix');
      d.statusErrorMessage.value =
          'Availability could not be refreshed. Please try again.';
      await tester.pumpAndSettle();
      expect(find.text('Completed for today'), findsOneWidget);
      await capture(tester, 'daily-status-error-$suffix');
    });
    testWidgets('daily options, persistent feedback and result $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = hub();
      c.activeSession.value = dailySession();
      await show(tester, const DailyChallengeQuizScreen());
      await capture(tester, 'daily-player-$suffix');
      await tap(tester, find.text('4 chocolates'));
      expect(c.selectedOptionId.value, 'B');
      c.lastAnswerResult.value = dailyResult();
      c.showExplanation.value = true;
      await tester.pumpAndSettle();
      await capture(tester, 'daily-feedback-$suffix');
      expect(
        tester
            .widgetList<IgnorePointer>(find.byType(IgnorePointer))
            .any((w) => w.ignoring),
        isTrue,
      );
      c.lastAnswerResult.value = dailyResult(complete: true);
      await tester.pumpAndSettle();
      await tap(tester, find.text('View result'));
      await capture(tester, 'daily-result-$suffix');
      expect(find.text('12 days'), findsOneWidget);
    });
    testWidgets('daily enlarged phone and landscape feedback $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = hub();
      c.activeSession.value = dailySession(long: true);
      await show(
        tester,
        const DailyChallengeQuizScreen(),
        size: const Size(320, 568),
        scale: 2,
      );
      c.lastAnswerResult.value = dailyResult(correct: false);
      c.showExplanation.value = true;
      await tester.pumpAndSettle();
      await capture(tester, 'daily-feedback-large-$suffix');
      await show(
        tester,
        const DailyChallengeQuizScreen(),
        size: const Size(568, 320),
        scale: 2,
      );
      await tap(tester, find.text('Next question'));
      expect(c.currentQuestionIndex.value, 1);
      await capture(tester, 'daily-landscape-$suffix');
      await tester.pumpWidget(const SizedBox());
      Get.delete<DailyChallengeController>();
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      final label = '${mode.name}-${size.width.toInt()}';
      testWidgets('sheets and confirmations remain usable at 2x $label', (
        tester,
      ) async {
        appearance.mode.value = mode;
        final c = player(long: true);
        await show(
          tester,
          PracticeSessionScreen(initialSession: c.session.value),
          size: size,
          scale: 2,
        );
        await tap(tester, find.byTooltip('Hints'));
        await tap(tester, find.text('Reveal hint 1'));
        await tap(tester, find.text('Reveal hint 2'));
        await capture(tester, 'practice-hints-large-$label');
        await tap(tester, find.byTooltip('Close'));
        await tap(tester, find.text('3 chocolates'));
        await tap(tester, find.text('Submit answer'));
        await tap(tester, find.text('AI preferred'));
        await tap(tester, find.text('Got it'));
        await tap(tester, find.byTooltip('Exit practice'));
        await capture(tester, 'practice-exit-large-$label');
        await tap(tester, find.text('Keep practicing'));
        expect(c.currentQuestionIndex.value, 0);
        expect(c.selectedOptionId.value, 'A');
        await tester.pumpWidget(const SizedBox());
        final daily = hub();
        daily.historyList.add(
          DailyHistoryItemModel.fromJson({
            'id': 'daily',
            'dateString': '2026-10-18',
            'status': 'IN_PROGRESS',
            'correctCount': 1,
            'totalQuestions': 2,
            'avgTimeMs': 12000,
          }),
        );
        await show(tester, const DailyStreakHubScreen(), size: size, scale: 2);
        await tap(tester, find.byTooltip('Daily history'));
        await capture(tester, 'daily-history-large-$label');
        await tap(tester, find.byTooltip('Close'));
        daily.activeSession.value = dailySession(long: true);
        await show(
          tester,
          const DailyChallengeQuizScreen(),
          size: size,
          scale: 2,
        );
        await tap(tester, find.byTooltip('Leave daily challenge'));
        await capture(tester, 'daily-exit-large-$label');
        await tap(tester, find.text('Stay'));
        expect(daily.currentQuestionIndex.value, 0);
        daily.lastAnswerResult.value = dailyResult(
          correct: false,
          complete: true,
          success: false,
        );
        daily.showExplanation.value = true;
        await tester.pumpAndSettle();
        await tap(tester, find.text('View result'));
        await capture(tester, 'daily-result-large-$label');
        expect(find.text('0 days'), findsOneWidget);
        expect(
          tester
              .getSize(
                find.widgetWithText(FilledButton, 'Return to daily challenge'),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('practice setup scrolls actions in a short shell viewport', (
    tester,
  ) async {
    Get.put(PracticeCatalogController(repository: CatalogRepository()));
    await show(
      tester,
      const Scaffold(body: SizedBox(height: 150, child: PracticeCatalogView())),
      size: const Size(568, 320),
      scale: 2,
    );
    await tester.drag(
      find.byKey(const PageStorageKey('practice-setup')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start practice'));
    await tester.pumpAndSettle();
    expect(find.text('Start practice').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('practice failed submission keeps selection and offers retry', (
    tester,
  ) async {
    final repo = FailingPracticeRepository();
    final c = Get.put(PracticeSessionController(practice(), repository: repo));
    await show(tester, PracticeSessionScreen(initialSession: c.session.value));
    await tap(tester, find.text('4 chocolates'));
    await tap(tester, find.text('Submit answer'));
    expect(c.selectedOptionId.value, 'B');
    expect(c.submitError.isNotEmpty, isTrue);
    repo.fail = false;
    await tap(tester, find.text('Retry answer'));
    expect(c.lastResult.value?.isCorrect, isTrue);
  });
  testWidgets('friendly scores and clock failures stay readable', (
    tester,
  ) async {
    final repo = FriendlyRepository();
    final c = Get.put(
      PracticeSessionController(practice(friendly: true), repository: repo),
    );
    c.friendlyScores.assignAll([
      {'name': 'A learner with a long display name', 'correctCount': 1},
      {'name': 'Asha', 'correctCount': 2},
    ]);
    await show(
      tester,
      PracticeSessionScreen(initialSession: c.session.value),
      size: const Size(320, 568),
      scale: 2,
    );
    repo.failClock = true;
    c.lastResult.value = const PracticeAnswerResultModel(
      isCorrect: true,
      correctAnswer: 'B',
      explanation: explanation,
      method: '12 ÷ 3 = 4',
      isComplete: false,
      totalAnswered: 1,
      correctCount: 1,
      xpAwarded: 0,
    );
    c.nextQuestion();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repo.failClock = false;
    await tap(tester, find.text('Retry'));
    expect(c.isReady.value, isTrue);
    expect(c.clockError.value, isEmpty);
    c.duelEnded.value =
        'This friendly duel ended before both players finished. No XP was awarded.';
    await tester.pumpAndSettle();
    expect(find.text('Return to practice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('daily invalid session and unavailable hub have recovery', (
    tester,
  ) async {
    final c = hub();
    c.activeSession.value = null;
    await show(tester, const DailyChallengeQuizScreen());
    expect(find.text('Return to daily challenge'), findsOneWidget);
    await show(tester, const DailyStreakHubScreen());
    c.status.value = dailyStatus(finished: true, failed: true);
    await tester.pumpAndSettle();
    expect(find.text('Today’s attempt is finished'), findsOneWidget);
    c.status.value = null;
    c.statusErrorMessage.value = 'Connection unavailable';
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('daily history empty/error and start failure remain actionable', (
    tester,
  ) async {
    final c = hub();
    await show(tester, const DailyStreakHubScreen());
    c.historyError.value = 'History could not be loaded. Please try again.';
    await tap(tester, find.byTooltip('Daily history'));
    expect(find.text('Could not load history'), findsOneWidget);
    await tap(tester, find.text('Retry'));
    expect(c.historyCalls, 2);
    c.historyError.value = '';
    await tester.pumpAndSettle();
    expect(find.text('No daily history yet'), findsOneWidget);
    await tap(tester, find.byTooltip('Close'));
    c.startError.value = 'Connection failed. Please try again.';
    await tester.pumpAndSettle();
    expect(find.text('Connection failed. Please try again.'), findsOneWidget);
  });
  testWidgets('Practice route without a session recovers without casting', (
    tester,
  ) async {
    final route = AppRouter.router.configuration.routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == '/practice-session');
    final router = GoRouter(
      initialLocation: '/practice-session',
      routes: [
        route,
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await show(tester, const SizedBox(), router: router);
    expect(find.text('No practice session'), findsOneWidget);
    await tap(tester, find.text('Return to Home'));
    expect(find.text('Home destination'), findsOneWidget);
  });

  testWidgets('practice hint availability and missing reason stay honest', (
    tester,
  ) async {
    final c = player();
    c.session.value = PracticeSessionModel.fromJson({
      'id': 'one-hint',
      'totalQuestions': 1,
      'questions': [
        {
          'question': {
            ...questionData(0),
            'hints': ['Share into equal groups.'],
            'preferredReason': null,
          },
        },
      ],
    });
    await show(tester, PracticeSessionScreen(initialSession: c.session.value));
    await tap(tester, find.byTooltip('Hints'));
    await tap(tester, find.text('Reveal hint 1'));
    expect(find.text('Reveal hint 2'), findsNothing);
    expect(find.text('1 of 1 revealed'), findsOneWidget);
    await tap(tester, find.byTooltip('Close'));
    c.session.value = PracticeSessionModel.fromJson({
      'id': 'no-hints',
      'totalQuestions': 1,
      'questions': [
        {
          'question': {
            ...questionData(0),
            'hints': [],
            'preferredReason': null,
          },
        },
      ],
    });
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.lightbulb_outline_rounded),
          )
          .onPressed,
      isNull,
    );
    c.lastResult.value = const PracticeAnswerResultModel(
      isCorrect: true,
      correctAnswer: 'B',
      explanation: '',
      method: '',
      isComplete: false,
      totalAnswered: 1,
      correctCount: 1,
      xpAwarded: 0,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('AI preferred'));
    expect(
      find.text('A reason for this preference is not available.'),
      findsOneWidget,
    );
  });
  testWidgets('daily Next cannot advance twice before rebuilding', (
    tester,
  ) async {
    final c = hub();
    c.activeSession.value = dailySession();
    c.lastAnswerResult.value = dailyResult();
    c.showExplanation.value = true;
    await show(tester, const DailyChallengeQuizScreen());
    final action = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Next question'),
        )
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(c.currentQuestionIndex.value, 1);
    await tester.pumpWidget(const SizedBox());
    Get.delete<DailyChallengeController>();
  });
  testWidgets('daily preparation failure unlocks controls for retry', (
    tester,
  ) async {
    final c = Get.put<DailyChallengeController>(
      QuietDaily(repository: adapter),
    );
    c.status.value = dailyStatus();
    c.isLoadingStatus.value = false;
    await show(tester, const DailyStreakHubScreen());
    adapter.failStart = true;
    await tap(tester, find.text('Start daily challenge'));
    expect(adapter.startCalls, 1);
    expect(c.isStarting.value, isFalse);
    expect(c.startError.isNotEmpty, isTrue);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.history_rounded),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('practice no catalog and load error keep clear recovery', (
    tester,
  ) async {
    final c = Get.put(
      PracticeCatalogController(repository: CatalogRepository()),
    );
    await tester.pumpAndSettle();
    c.liveTopics.clear();
    await show(tester, const Scaffold(body: PracticeCatalogView()));
    expect(
      find.text('Practice questions are not available yet.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start practice'),
          )
          .onPressed,
      isNull,
    );
    c.errorMessage.value = 'Could not load the catalog';
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tap(tester, find.text('Retry'));
    expect(c.liveTopics.isNotEmpty, isTrue);
  });
  testWidgets('practice history retains cache on failure and paginates', (
    tester,
  ) async {
    final repo = HistoryRepository();
    final c = Get.put(PracticeCatalogController(repository: repo));
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.fetchHistory());
    await tester.runAsync(() => c.fetchHistory(loadMore: true));
    expect(repo.pages, [1, 2]);
    expect(c.historyList.length, 2);
    repo.fail = true;
    await tester.runAsync(() => c.fetchHistory(refresh: true));
    expect(c.historyList.length, 2);
    expect(c.historyError.isNotEmpty, isTrue);
    c.showHistory.value = true;
    await show(
      tester,
      const Scaffold(body: PracticeCatalogView()),
      size: const Size(320, 568),
      scale: 2,
    );
    expect(find.text('History could not be refreshed'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(c.showHistory.value, isFalse);
  });
  testWidgets(
    'daily history error is distinct from empty and pagination retries same page',
    (tester) async {
      final c = Get.put<DailyChallengeController>(
        QuietDaily(repository: adapter),
      );
      await tester.runAsync(() => c.fetchHistory());
      adapter.failHistory = true;
      await tester.runAsync(() => c.fetchHistory(loadMore: true));
      expect(c.historyList.length, 1);
      expect(c.historyError.isNotEmpty, isTrue);
      expect(c.historyPage.value, 1);
      adapter.failHistory = false;
      await tester.runAsync(() => c.fetchHistory(loadMore: true));
      expect(adapter.pages, [1, 2, 2]);
      expect(c.historyList.length, 2);
      await tester.runAsync(() => c.fetchHistory(refresh: true));
      expect(c.historyList.length, 1);
    },
  );
  testWidgets(
    'daily selected option and timeout preserve request payload and one submission',
    (tester) async {
      final c = Get.put<DailyChallengeController>(
        QuietDaily(repository: adapter),
      );
      c.activeSession.value = dailySession();
      adapter.answerGate = Completer<void>();
      c.selectOption('B');
      final request = c.submitAnswer();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await c.submitAnswer();
      expect(adapter.answerCalls, 1);
      c.selectOption('A');
      expect(c.selectedOptionId.value, 'B');
      adapter.answerGate!.complete();
      await tester.runAsync(() => request);
      expect(adapter.answerPayload!['selectedOptionId'], 'B');
      expect(adapter.answerPayload!['questionId'], 'q-0');
      expect(c.showExplanation.value, isTrue);
    },
  );
  testWidgets('daily start guard, timer expiry and next reset remain intact', (
    tester,
  ) async {
    final c = Get.put<DailyChallengeController>(
      QuietDaily(repository: adapter),
    );
    c.status.value = dailyStatus();
    c.isLoadingStatus.value = false;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DailyStreakHubScreen()),
        GoRoute(
          path: '/daily-challenge-quiz',
          builder: (_, __) => const DailyChallengeQuizScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await show(tester, const SizedBox(), router: router);
    adapter.startGate = Completer<void>();
    final context = tester.element(find.byType(DailyStreakHubScreen));
    final start = c.startDailyChallenge(context);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await c.startDailyChallenge(context);
    expect(adapter.startCalls, 1);
    adapter.startGate!.complete();
    await tester.runAsync(() => start);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(adapter.answerCalls, 1);
    expect(adapter.answerPayload!['selectedOptionId'], 'TIMEOUT');
    expect(c.secondsRemaining.value, 0);
    await tap(tester, find.text('Next question'));
    expect(c.currentQuestionIndex.value, 1);
    expect(c.secondsRemaining.value, 60);
    await tester.pumpWidget(const SizedBox());
    Get.delete<DailyChallengeController>();
  });
  testWidgets('daily failed answer preserves selection and retries', (
    tester,
  ) async {
    final c = Get.put<DailyChallengeController>(
      QuietDaily(repository: adapter),
    );
    c.activeSession.value = dailySession();
    c.isLoadingStatus.value = false;
    await show(tester, const DailyChallengeQuizScreen());
    adapter.failAnswer = true;
    await tap(tester, find.text('4 chocolates'));
    await tap(tester, find.text('Confirm answer'));
    expect(c.selectedOptionId.value, 'B');
    expect(c.answerError.isNotEmpty, isTrue);
    expect(find.text('Retry answer'), findsOneWidget);
    adapter.failAnswer = false;
    await tap(tester, find.text('Retry answer'));
    expect(c.showExplanation.value, isTrue);
    expect(adapter.answerCalls, 2);
  });
  testWidgets('answer controls expose selection and semantic color pairs', (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(
        body: AnswerOption(
          id: 'B',
          text: '4 chocolates',
          selected: true,
          onPressed: () {},
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final node = tester.getSemantics(find.text('4 chocolates'));
    expect(node.flagsCollection.isSelected, isTrue);
    final descendants = <SemanticsNode>[node];
    node.visitChildren((child) {
      descendants.add(child);
      return true;
    });
    expect(descendants.any((n) => n.flagsCollection.isButton), isTrue);
    expect(
      descendants.any(
        (n) => n.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      ),
      isTrue,
    );
    final context = tester.element(find.byType(AnswerOption));
    final fg = context.colors.onPrimaryContainer.computeLuminance(),
        bg = context.colors.primaryContainer.computeLuminance();
    expect(
      (fg > bg ? (fg + .05) / (bg + .05) : (bg + .05) / (fg + .05)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });
  test('question and action semantic pairs retain readable contrast', () {
    for (final theme in [AptiquTheme.lightTheme, AptiquTheme.darkTheme]) {
      final s = theme.colorScheme;
      final status = theme.extension<AptiquStatus>()!;
      for (final pair in [
        (s.onPrimary, s.primary),
        (s.onPrimaryContainer, s.primaryContainer),
        (s.onSurface, s.surface),
        (s.onErrorContainer, s.errorContainer),
        (status.success, status.successContainer),
      ]) {
        final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
        expect(
          (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}
