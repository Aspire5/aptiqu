import 'dart:async';
import 'package:aptiqu/core/feedback/app_feedback_service.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/core/feedback/feedback_preferences.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/practice/controllers/practice_session_controller.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/repositories/practice_repository.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/practice/views/practice_session_screen.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'practice_session_test.dart' show fixture, TestClock;
import 'support/feedback_fakes.dart';
import 'support/presentation_fonts.dart';

class FeedbackPracticeRepository extends PracticeRepository {
  int calls = 0;
  bool failed = false, recoveryFailed = false;
  PracticeSessionModel? restored;
  Completer<PracticeAnswerResultModel>? pending;
  @override
  Future<PracticeSessionModel> getSession(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (recoveryFailed || restored == null) throw StateError('No snapshot');
    return restored!;
  }

  @override
  Future<PracticeAnswerResultModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
    CancelToken? cancelToken,
  }) async {
    calls++;
    if (failed) throw StateError('Rejected');
    return pending?.future ??
        const PracticeAnswerResultModel(
          isCorrect: true,
          correctAnswer: 'B',
          explanation: 'Four',
          method: 'Add',
          isComplete: false,
          totalAnswered: 1,
          correctCount: 1,
          xpAwarded: 0,
        );
  }
}

Map<String, dynamic> roundStart(
  int index, {
  String? deadline,
  String? serverNow,
}) => {
  'matchId': 'match',
  'questionIndex': index,
  'stateVersion': index * 3,
  'durationSeconds': 60,
  if (deadline != null) 'deadline': deadline,
  if (serverNow != null) 'serverNow': serverNow,
  'question': {
    'id': 'q-$index',
    'prompt': 'What is 2 + 2?',
    'options': [
      {'id': 'A', 'text': '3'},
      {'id': 'B', 'text': '4'},
      {'id': 'C', 'text': '5'},
      {'id': 'D', 'text': '6'},
    ],
  },
};
Map<String, dynamic> matchResult({String? winner = 'me', bool tie = false}) => {
  'matchId': 'match',
  'stateVersion': 40,
  'winnerId': winner,
  'isTie': tie,
  'players': [
    {'userId': 'me', 'score': 6, 'xpAwarded': 20},
    {'userId': 'other', 'score': 5},
  ],
};

void main() {
  late RecordingFeedbackAudio audio;
  late RecordingHaptics haptics;
  late FeedbackClock feedbackClock;
  late AppFeedbackService feedback;
  late FeedbackSocket socket;
  late AuthController auth;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(DioClient(baseUrl: 'https://session.invalid'));
    auth = Get.put(AuthController());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'test@invalid',
      firstName: 'Asha',
      level: 4,
    );
    audio = RecordingFeedbackAudio();
    haptics = RecordingHaptics();
    feedbackClock = FeedbackClock();
    final preferences = Get.put(FeedbackPreferences());
    feedback = Get.put(
      AppFeedbackService(
        preferences: preferences,
        audio: audio,
        haptics: haptics,
        clock: feedbackClock,
      ),
    );
    socket = FeedbackSocket();
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });
  void sessionTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (Get.isRegistered<PracticeSessionController>()) {
          await Get.delete<PracticeSessionController>();
        }
        if (Get.isRegistered<PvpArenaController>()) {
          await Get.delete<PvpArenaController>();
        }
        feedback.onClose();
        await tester.pump();
      }
    });
  }

  PracticeSessionController practice({
    bool timed = true,
    FeedbackPracticeRepository? repo,
    TestClock? clock,
  }) {
    final c = Get.put(
      PracticeSessionController(
        fixture(timer: timed),
        repository: repo ?? FeedbackPracticeRepository(),
        stopwatch: clock,
      ),
    );
    c.begin(reduceMotion: true);
    c.setFeedbackVisible(true);
    c.feedbackPresented();
    feedbackClock.milliseconds = 10000;
    return c;
  }

  PvpArenaController pvp({FeedbackClock? clock, bool resume = false}) {
    final c = Get.put(
      PvpArenaController(
        matchId: 'match',
        initialPlayersData: const [
          {'userId': 'me', 'firstName': 'Asha', 'level': 4},
          {'userId': 'other', 'firstName': 'Dev', 'level': 5},
        ],
        totalQuestions: 10,
        socketService: socket,
        roundClock: clock,
        resume: resume,
      ),
    );
    c.setFeedbackVisible(true);
    return c;
  }

  sessionTest(
    'Practice start is delivered after a playable frame, never loading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.lightTheme,
          home: PracticeSessionScreen(initialSession: fixture(timer: true)),
        ),
      );
      expect(audio.played, isEmpty);
      expect(haptics.starts, 0);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(
        audio.played.where((c) => c == FeedbackCue.sessionStart).length,
        1,
      );
      expect(haptics.starts, 1);
      await tester.pump();
      expect(haptics.starts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  sessionTest(
    'Practice option highlights keep ticks; Submit locks instantly, explanation stays silent',
    (tester) async {
      final clock = TestClock();
      final repo = FeedbackPracticeRepository()..pending = Completer();
      final c = practice(repo: repo, clock: clock);
      await tester.pump();
      c.selectOption('B');
      clock.elapsedMs = 12000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(audio.played.last, FeedbackCue.tick);
      final submitting = c.submitAnswer();
      final stops = audio.tickStops;
      clock.elapsedMs = 15000;
      await tester.pump(const Duration(seconds: 3));
      expect(c.isSubmitting.value, true);
      expect(audio.tickStops, stops);
      expect(repo.calls, 1);
      repo.pending!.complete(
        const PracticeAnswerResultModel(
          isCorrect: true,
          correctAnswer: 'B',
          explanation: 'Four',
          method: 'Add',
          isComplete: false,
          totalAnswered: 1,
          correctCount: 1,
          xpAwarded: 0,
        ),
      );
      await submitting;
      await tester.pump();
      final ticks = audio.played.where((c) => c.isTick).length;
      clock.elapsedMs = 25000;
      await tester.pump(const Duration(seconds: 4));
      expect(audio.played.where((c) => c.isTick).length, ticks);
      expect(audio.played.where((c) => c == FeedbackCue.correct).length, 1);
      c.nextQuestion();
      c.feedbackPresented();
      feedbackClock.milliseconds += 2000;
      clock.elapsedMs = 51000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.remainingSeconds.value, 9);
      expect(audio.played.last, FeedbackCue.urgentTick);
    },
  );
  sessionTest(
    'Practice definitive rejection restores same clock without resetting',
    (tester) async {
      final clock = TestClock();
      final repo = FeedbackPracticeRepository()
        ..failed = true
        ..recoveryFailed = true;
      final c = practice(repo: repo, clock: clock);
      clock.elapsedMs = 12000;
      await tester.pump(const Duration(milliseconds: 250));
      c.selectOption('B');
      await c.submitAnswer();
      expect(c.lastResult.value, isNull);
      expect(c.isSubmitting.value, false);
      clock.elapsedMs = 13000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.remainingSeconds.value, 47);
      expect(audio.played.last, FeedbackCue.tick);
      expect(audio.played.contains(FeedbackCue.correct), false);
    },
  );
  sessionTest(
    'Practice lost response recovery confirms once; untimed never ticks',
    (tester) async {
      final repo = FeedbackPracticeRepository()..failed = true;
      final raw = {
        'id': 'session',
        'timerEnabled': false,
        'totalQuestions': 10,
        'questions': [
          {
            'id': 'sq-0',
            'sequence': 1,
            'isAnswered': true,
            'isCorrect': true,
            'question': {
              'id': 'q-0',
              'correctAnswer': 'B',
              'prompt': '2 + 2',
              'options': [],
              'hints': [],
            },
          },
        ],
      };
      repo.restored = PracticeSessionModel.fromJson(raw);
      final c = practice(timed: false, repo: repo);
      c.selectOption('B');
      await c.submitAnswer();
      await tester.pump();
      await c.submitAnswer();
      await tester.pump(const Duration(seconds: 65));
      expect(audio.played.where((c) => c.isTick), isEmpty);
      expect(audio.played.where((c) => c == FeedbackCue.correct).length, 1);
    },
  );
  sessionTest('Practice zero is silent until authoritative timeout response', (
    tester,
  ) async {
    final clock = TestClock();
    final repo = FeedbackPracticeRepository()..pending = Completer();
    practice(repo: repo, clock: clock);
    clock.elapsedMs = 60000;
    await tester.pump(const Duration(milliseconds: 250));
    expect(audio.played.contains(FeedbackCue.incorrect), false);
    repo.pending!.complete(
      const PracticeAnswerResultModel(
        isCorrect: false,
        correctAnswer: 'B',
        explanation: '',
        method: '',
        isComplete: false,
        totalAnswered: 1,
        correctCount: 0,
        xpAwarded: 0,
      ),
    );
    await tester.pump();
    expect(audio.played.where((c) => c == FeedbackCue.incorrect).length, 1);
  });
  sessionTest(
    'PvP answer at 12s silences personal clock; shared round keeps moving until server advances',
    (tester) async {
      final clock = FeedbackClock();
      final c = pvp(clock: clock);
      socket.emit('QUESTION_STARTED', roundStart(0));
      c.feedbackPresented();
      feedbackClock.milliseconds = 10000;
      clock.milliseconds = 12000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.remainingSeconds.value, 48);
      expect(audio.played.last, FeedbackCue.tick);
      c.selectOption('B');
      expect(c.personalRemainingSeconds.value, 48);
      expect(socket.answers.length, 1);
      final count = audio.played.length;
      socket.emit('ANSWER_ACCEPTED', {
        'matchId': 'match',
        'questionIndex': 0,
        'selectedOptionId': 'B',
      });
      clock.milliseconds = 24000;
      await tester.pump(const Duration(seconds: 1));
      expect(c.currentQuestionIndex.value, 0);
      expect(c.remainingSeconds.value, 36);
      expect(c.personalRemainingSeconds.value, 48);
      expect(audio.played.length, count);
      expect(c.roundCorrectAnswer.value, isEmpty);
      socket.emit('QUESTION_ENDED', {
        'matchId': 'match',
        'questionIndex': 0,
        'stateVersion': 2,
        'correctAnswer': 'B',
        'scores': [
          {'userId': 'me', 'score': 1, 'isCorrect': true},
          {'userId': 'other', 'score': 0, 'isCorrect': false},
        ],
      });
      await tester.pump();
      expect(audio.played.last, FeedbackCue.correct);
      socket.emit('QUESTION_STARTED', roundStart(1));
      c.feedbackPresented();
      feedbackClock.milliseconds += 2000;
      clock.milliseconds = 51000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.currentQuestionIndex.value, 1);
      expect(c.canAnswer, true);
      expect(audio.played.last, FeedbackCue.urgentTick);
    },
  );
  sessionTest('PvP duplicate, old round and ACK events do not replay cues', (
    tester,
  ) async {
    final c = pvp();
    socket.emit('QUESTION_STARTED', roundStart(0));
    c.feedbackPresented();
    socket.emit('QUESTION_STARTED', roundStart(0));
    c.feedbackPresented();
    expect(haptics.starts, 1);
    final closed = {
      'matchId': 'match',
      'questionIndex': 0,
      'stateVersion': 2,
      'correctAnswer': 'B',
      'scores': [
        {'userId': 'me', 'score': 1, 'isCorrect': true},
      ],
    };
    socket.emit('QUESTION_ENDED', closed);
    socket.emit('QUESTION_ENDED', closed);
    socket.emit('ANSWER_ACCEPTED', {'matchId': 'match', 'questionIndex': 0});
    await tester.pump();
    expect(audio.played.where((c) => c == FeedbackCue.correct).length, 1);
    socket.emit('QUESTION_STARTED', roundStart(1));
    socket.emit('QUESTION_ENDED', closed);
    expect(c.currentQuestionIndex.value, 1);
    expect(c.isRoundEnded.value, false);
  });
  sessionTest(
    'PvP deadline anchors actual remaining time; reconnect never starts again',
    (tester) async {
      final clock = FeedbackClock();
      final c = pvp(clock: clock, resume: true);
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'stateVersion': 2,
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 0,
        'remainingMs': 7000,
        'question': roundStart(0)['question'],
        'ownAnswer': null,
        'players': [
          {'userId': 'other', 'firstName': 'Dev', 'level': 5},
        ],
      });
      c.feedbackPresented();
      expect(c.remainingSeconds.value, 7);
      expect(haptics.starts, 0);
      clock.milliseconds = 2000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.remainingSeconds.value, 5);
      expect(audio.played.last, FeedbackCue.urgentTick);
      socket.emit('QUESTION_STARTED', roundStart(0));
      c.feedbackPresented();
      expect(c.remainingSeconds.value, 5);
    },
  );
  sessionTest(
    'new PvP question uses server deadline budget rather than fresh 60s',
    (tester) async {
      final c = pvp();
      socket.emit(
        'QUESTION_STARTED',
        roundStart(
          0,
          serverNow: '2026-10-24T12:00:40Z',
          deadline: '2026-10-24T12:01:00Z',
        ),
      );
      expect(c.remainingSeconds.value, 20);
    },
  );
  for (final outcome in ['win', 'loss', 'draw', 'void', 'history']) {
    sessionTest(
      'PvP $outcome has only the corresponding confirmed terminal feedback',
      (tester) async {
        final c = pvp();
        if (outcome == 'void') {
          socket.emit('MATCH_RECONNECTED', {
            'matchId': 'match',
            'status': 'CANCELLED',
            'outcomeReason': 'SYSTEM_VOID',
          });
        } else if (outcome == 'history') {
          socket.emit('MATCH_RECONNECTED', {
            ...matchResult(),
            'status': 'COMPLETED',
          });
        } else {
          socket.emit(
            'MATCH_COMPLETED',
            matchResult(
              winner: outcome == 'win' ? 'me' : 'other',
              tie: outcome == 'draw',
            ),
          );
        }
        c.feedbackPresented();
        c.feedbackPresented();
        await tester.pump();
        final cues = audio.played
            .where((c) => c == FeedbackCue.victory || c == FeedbackCue.complete)
            .toList();
        expect(
          cues,
          outcome == 'void' || outcome == 'history'
              ? []
              : [outcome == 'win' ? FeedbackCue.victory : FeedbackCue.complete],
        );
        expect(c.celebrateVictory.value, outcome == 'win');
      },
    );
  }
  sessionTest(
    'PvP expired display waits silently for closed-round timeout confirmation',
    (tester) async {
      final clock = FeedbackClock();
      final c = pvp(clock: clock);
      socket.emit('QUESTION_STARTED', roundStart(0));
      c.feedbackPresented();
      clock.milliseconds = 60000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.canAnswer, false);
      expect(c.isRoundEnded.value, false);
      expect(audio.played.contains(FeedbackCue.incorrect), false);
      final ended = {
        'matchId': 'match',
        'questionIndex': 0,
        'stateVersion': 2,
        'correctAnswer': 'B',
        'scores': [
          {'userId': 'me', 'score': 0, 'isCorrect': false},
        ],
      };
      socket.emit('QUESTION_ENDED', ended);
      socket.emit('QUESTION_ENDED', ended);
      await tester.pump();
      expect(audio.played.where((c) => c == FeedbackCue.incorrect).length, 1);
    },
  );
  sessionTest(
    'duplicate active snapshot never increases the clock or repeats start',
    (tester) async {
      final clock = FeedbackClock();
      final c = pvp(clock: clock, resume: true);
      final snapshot = {
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 0,
        'stateVersion': 1,
        'remainingMs': 7000,
        'question': roundStart(0)['question'],
        'ownAnswer': null,
        'players': [],
      };
      socket.emit('MATCH_RECONNECTED', snapshot);
      c.feedbackPresented();
      clock.milliseconds = 2000;
      await tester.pump(const Duration(milliseconds: 250));
      socket.emit('MATCH_RECONNECTED', {...snapshot, 'remainingMs': 9000});
      c.feedbackPresented();
      expect(c.remainingSeconds.value, 5);
      expect(haptics.starts, 0);
    },
  );
  sessionTest('a resumed live match can celebrate a later new confirmed win', (
    tester,
  ) async {
    final c = pvp(resume: true);
    socket.emit('MATCH_RECONNECTED', {
      'matchId': 'match',
      'status': 'QUESTION_ACTIVE',
      'currentQuestionIndex': 4,
      'stateVersion': 15,
      'remainingMs': 7000,
      'question': roundStart(4)['question'],
      'ownAnswer': null,
      'players': [],
    });
    c.feedbackPresented();
    socket.emit('MATCH_COMPLETED', matchResult());
    c.feedbackPresented();
    await tester.pump();
    expect(audio.played.where((c) => c == FeedbackCue.victory).length, 1);
    expect(c.celebrateVictory.value, true);
  });
  sessionTest(
    'submitted reconnect shows Submitted without fabricating a lock timestamp',
    (tester) async {
      final c = pvp(resume: true);
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 2,
        'stateVersion': 7,
        'remainingMs': 7000,
        'question': roundStart(2)['question'],
        'ownAnswer': {'selectedOptionId': 'B'},
        'players': [],
      });
      c.feedbackPresented();
      await tester.pump();
      expect(c.hasSubmittedAnswer.value, true);
      expect(c.canAnswer, false);
      expect(c.personalRemainingSeconds.value, isNull);
      expect(audio.played, isEmpty);
    },
  );
  sessionTest(
    'two participants receive unchanged shared question/options and no early correctness',
    (tester) async {
      await Get.delete<AuthController>();
      final c = pvp();
      c.currentUserId = 'me';
      final second = PvpArenaController(
        matchId: 'match',
        initialPlayersData: const [],
        totalQuestions: 10,
        socketService: socket,
      );
      second.onInit();
      second.currentUserId = 'other';
      socket.emit('QUESTION_STARTED', roundStart(0));
      expect(
        c.currentQuestion.value!.prompt,
        second.currentQuestion.value!.prompt,
      );
      expect(
        c.currentQuestion.value!.options
            .map((o) => '${o.id}:${o.text}')
            .toList(),
        second.currentQuestion.value!.options
            .map((o) => '${o.id}:${o.text}')
            .toList(),
      );
      expect(c.roundCorrectAnswer.value, isEmpty);
      expect(second.roundCorrectAnswer.value, isEmpty);
      expect(
        roundStart(0)['question'].toString().contains('correctAnswer'),
        false,
      );
      second.onClose();
    },
  );
}
