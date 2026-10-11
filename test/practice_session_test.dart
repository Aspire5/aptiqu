import 'package:dio/dio.dart';
import 'dart:async';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/practice/controllers/practice_session_controller.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/repositories/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class TestClock extends Stopwatch {
  int elapsedMs = 0;
  @override
  int get elapsedMilliseconds => elapsedMs;
  @override
  void reset() => elapsedMs = 0;
}

class FakeRepository extends PracticeRepository {
  int calls = 0;
  PracticeSessionModel? recovered;
  String? option;
  Completer<PracticeAnswerResultModel>? pending;
  @override
  Future<PracticeSessionModel> getSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) async => recovered!;
  @override
  Future<PracticeAnswerResultModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
    CancelToken? cancelToken,
  }) async {
    if (recovered != null) throw Exception('Response lost');
    calls++;
    option = selectedOptionId;
    if (pending != null) return pending!.future;
    return const PracticeAnswerResultModel(
      isCorrect: false,
      correctAnswer: 'B',
      explanation: 'Two plus two is four.',
      method: 'Add the numbers.',
      isComplete: false,
      totalAnswered: 1,
      correctCount: 0,
      xpAwarded: 0,
    );
  }
}

PracticeSessionModel fixture({bool timer = false, bool replay = false}) =>
    PracticeSessionModel.fromJson({
      'id': 'session',
      'timerEnabled': timer,
      'isReplay': replay,
      'totalQuestions': 10,
      'questions': List.generate(
        10,
        (i) => {
          'id': 'sq-$i',
          'sequence': i + 1,
          'isAnswered': false,
          'question': {
            'id': 'q-$i',
            'prompt': 'What is 2 + 2?',
            'options': [
              {'id': 'A', 'text': '3'},
              {'id': 'B', 'text': '4'},
              {'id': 'C', 'text': '5'},
              {'id': 'D', 'text': '6'},
            ],
            'hints': [],
          },
        },
      ),
    });
void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
  });
  tearDown(() => Get.reset());
  testWidgets('timer expires at 60 seconds once and resets for next question', (
    tester,
  ) async {
    final repo = FakeRepository();
    final clock = TestClock();
    final c = Get.put(
      PracticeSessionController(
        fixture(timer: true),
        repository: repo,
        stopwatch: clock,
      ),
    );
    c.begin(reduceMotion: true);
    await tester.pump();
    clock.elapsedMs = 59000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.remainingSeconds.value, 1);
    expect(repo.calls, 0);
    clock.elapsedMs = 60000;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(repo.option, 'TIMEOUT');
    expect(repo.calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, 1);
    c.nextQuestion();
    expect(c.remainingSeconds.value, 60);
    expect(c.currentQuestionIndex.value, 1);
    Get.delete<PracticeSessionController>();
  });
  testWidgets('untimed replay uses the same player without automatic answers', (
    tester,
  ) async {
    final repo = FakeRepository();
    final clock = TestClock();
    final c = Get.put(
      PracticeSessionController(
        fixture(replay: true),
        repository: repo,
        stopwatch: clock,
      ),
    );
    c.begin(reduceMotion: true);
    await tester.pump();
    clock.elapsedMs = 120000;
    await tester.pump(const Duration(seconds: 2));
    expect(repo.calls, 0);
    expect(c.remainingSeconds.value, 60);
    c.nextQuestion();
    expect(c.currentQuestionIndex.value, 0);
    c.selectOption('A');
    await c.submitAnswer();
    c.nextQuestion();
    expect(c.currentQuestionIndex.value, 1);
    expect(c.lastResult.value, isNull);
    Get.delete<PracticeSessionController>();
  });
  testWidgets(
    'double submissions and stale responses after close are ignored',
    (tester) async {
      final repo = FakeRepository()..pending = Completer();
      final c = Get.put(PracticeSessionController(fixture(), repository: repo));
      c.begin(reduceMotion: true);
      await tester.pump();
      c.selectOption('A');
      final request = c.submitAnswer();
      await c.submitAnswer();
      expect(repo.calls, 1);
      Get.delete<PracticeSessionController>();
      repo.pending!.complete(
        const PracticeAnswerResultModel(
          isCorrect: true,
          correctAnswer: 'A',
          explanation: '',
          method: '',
          isComplete: false,
          totalAnswered: 1,
          correctCount: 1,
          xpAwarded: 0,
        ),
      );
      await request;
      expect(c.lastResult.value, isNull);
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets('closing during ready splash cancels delayed start', (
    tester,
  ) async {
    final c = Get.put(
      PracticeSessionController(
        fixture(timer: true),
        repository: FakeRepository(),
      ),
    );
    c.begin();
    Get.delete<PracticeSessionController>();
    await tester.pump(const Duration(seconds: 2));
    expect(c.isReady.value, false);
  });
  testWidgets(
    'lost answer response restores feedback without submitting again',
    (tester) async {
      final recovered = PracticeSessionModel.fromJson({
        'id': 'session',
        'currentIndex': 1,
        'totalQuestions': 10,
        'correctCount': 1,
        'questions': List.generate(
          10,
          (i) => {
            'id': 'sq-$i',
            'sequence': i + 1,
            'isAnswered': i == 0,
            'isCorrect': i == 0,
            'question': {
              'id': 'q-$i',
              'prompt': 'What is 2 + 2?',
              'options': [],
              'correctAnswer': i == 0 ? 'B' : null,
              'explanation': i == 0 ? '2 + 2 = 4.' : null,
              'method': 'Add.',
            },
          },
        ),
      });
      final repo = FakeRepository()..recovered = recovered;
      final c = Get.put(PracticeSessionController(fixture(), repository: repo));
      c.begin(reduceMotion: true);
      c.selectOption('B');
      await c.submitAnswer();
      expect(c.lastResult.value?.isCorrect, true);
      expect(c.lastResult.value?.correctAnswer, 'B');
      c.nextQuestion();
      expect(c.currentQuestionIndex.value, 1);
      Get.delete<PracticeSessionController>();
      await tester.pump();
    },
  );
}
