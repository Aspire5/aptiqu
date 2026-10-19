import 'dart:typed_data';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:aptiqu/core/progression/models/xp_models.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'phase_e_social_competitive_test.dart' show ESocket;

class PhaseOneAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class RecordingXp extends XpController {
  int applications = 0;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void handleXpUpdate({
    required XpProgressModel xp,
    LevelUpModel? levelUp,
    BuildContext? context,
  }) {
    applications++;
    progress.value = xp;
  }
}

class ProgressAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (options.path != '/user/progress') {
      throw StateError('Unexpected request');
    }
    return ResponseBody.fromString(
      '{"success":true,"data":{"total":1115,"earned":0,"level":11}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ESocket socket;
  late RecordingXp xp;
  late AuthController auth;
  late ProgressAdapter adapter;

  PvpArenaController arena() => Get.put(
    PvpArenaController(
      matchId: 'match',
      initialPlayersData: const [],
      totalQuestions: 10,
      socketService: socket,
    ),
  );
  Map<String, dynamic> result({bool absolute = true}) => {
    'matchId': 'match',
    'status': 'COMPLETED',
    'winnerId': 'me',
    'isTie': false,
    'players': [
      {'userId': 'me', 'score': 1, 'xpAwarded': 115},
      {'userId': 'other', 'score': 0, 'xpAwarded': 0},
    ],
    if (absolute) 'xp': {'total': 1115, 'earned': 0, 'level': 11},
  };

  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    socket = ESocket();
    final client = DioClient(baseUrl: 'https://phase-one.invalid/api/v1');
    adapter = ProgressAdapter();
    client.dio.httpClientAdapter = adapter;
    Get.put<DioClient>(client);
    auth = Get.put<AuthController>(PhaseOneAuth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'test@example.invalid',
      firstName: 'Learner',
    );
    xp = RecordingXp();
    xp.progress.value = const XpProgressModel(total: 1000);
    Get.put<XpController>(xp);
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });

  testWidgets(
    'server-confirmed system void is terminal without rewards or stale revival',
    (tester) async {
      final c = arena();
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'CANCELLED',
        'outcomeReason': 'SYSTEM_VOID',
      });
      expect(c.isMatchVoided.value, isTrue);
      expect(c.recoveredCompletion.value, isTrue);
      expect(c.isMatchCompleted.value, isFalse);
      expect(c.isTie.value, isFalse);
      expect(xp.applications, 0);
      socket.emit('MATCH_COMPLETED', result());
      expect(c.isMatchCompleted.value, isFalse);
      expect(xp.progress.value.total, 1000);
    },
  );

  testWidgets(
    'duplicate results and controller recreation never add the historical XP again',
    (tester) async {
      final c = arena();
      socket.emit('MATCH_COMPLETED', result());
      socket.emit('MATCH_COMPLETED', result());
      expect(c.xpAwarded.value, 115);
      expect(c.isMatchCompleted.value, isTrue);
      expect(xp.progress.value.total, 1115);
      expect(xp.applications, 1);
      await Get.delete<PvpArenaController>();
      final restored = arena();
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'COMPLETED',
        'players': [],
      });
      expect(restored.recoveredCompletion.value, isTrue);
      socket.emit('MATCH_RECONNECTED', result());
      expect(restored.isMatchCompleted.value, isTrue);
      expect(restored.recoveredCompletion.value, isFalse);
      expect(restored.xpAwarded.value, 115);
      expect(xp.progress.value.total, 1115);
      expect(adapter.calls, 0);
    },
  );

  testWidgets(
    'lost ACK snapshot restores accepted selection and closed-round feedback',
    (tester) async {
      final c = arena();
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 0,
        'remainingMs': 45000,
        'question': {
          'id': 'q0',
          'prompt': '2 + 2?',
          'options': [
            {'id': 'B', 'text': '4'},
          ],
        },
        'ownAnswer': {'questionIndex': 0, 'selectedOptionId': 'B'},
        'players': [],
      });
      expect(c.selectedOptionId.value, 'B');
      expect(c.hasSubmittedAnswer.value, isTrue);
      c.selectOption('A');
      expect(socket.answers, isEmpty);
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'QUESTION_TRANSITION',
        'currentQuestionIndex': 0,
        'remainingMs': 0,
        'question': {'id': 'q0', 'prompt': '2 + 2?', 'options': []},
        'ownAnswer': {'questionIndex': 0, 'selectedOptionId': 'B'},
        'players': [],
        'roundResult': {
          'questionIndex': 0,
          'correctAnswer': 'B',
          'explanation': '2 + 2 = 4',
          'scores': [],
        },
      });
      expect(c.isRoundEnded.value, isTrue);
      expect(c.roundCorrectAnswer.value, 'B');
    },
  );

  testWidgets(
    'other matches, stale rounds, stale XP totals and account changes are ignored',
    (tester) async {
      final c = arena();
      socket.emit('MATCH_COMPLETED', {...result(), 'matchId': 'unrelated'});
      expect(c.isMatchCompleted.value, isFalse);
      socket.emit('QUESTION_STARTED', {
        'matchId': 'match',
        'questionIndex': 1,
        'durationSeconds': 60,
        'question': {'id': 'q1', 'prompt': 'Current', 'options': []},
      });
      socket.emit('QUESTION_STARTED', {
        'matchId': 'match',
        'questionIndex': 0,
        'question': {'id': 'q0', 'prompt': 'Old', 'options': []},
      });
      socket.emit('ANSWER_ACCEPTED', {'matchId': 'match', 'questionIndex': 0});
      expect(c.currentQuestionIndex.value, 1);
      expect(c.hasSubmittedAnswer.value, isFalse);
      auth.currentUser.value = const UserModel(
        id: 'changed',
        email: 'changed@example.invalid',
        firstName: 'Other',
      );
      socket.emit('MATCH_COMPLETED', result());
      expect(c.isMatchCompleted.value, isFalse);
      auth.currentUser.value = const UserModel(
        id: 'me',
        email: 'test@example.invalid',
        firstName: 'Learner',
      );
      xp.progress.value = const XpProgressModel(total: 2000);
      socket.emit('MATCH_COMPLETED', result());
      expect(xp.progress.value.total, 2000);
    },
  );

  testWidgets(
    'old completion payload refreshes absolute progression once instead of incrementing XP',
    (tester) async {
      arena();
      socket.emit('MATCH_COMPLETED', result(absolute: false));
      socket.emit('MATCH_COMPLETED', result(absolute: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.calls, 1);
      expect(xp.progress.value.total, 1115);
    },
  );

  testWidgets(
    'stale snapshots cannot reopen feedback or replace an accepted answer',
    (tester) async {
      final c = arena();
      final snapshot = <String, dynamic>{
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 1,
        'remainingMs': 40000,
        'question': {'id': 'q1', 'prompt': 'Current', 'options': []},
        'ownAnswer': null,
        'players': [],
      };
      socket.emit('MATCH_RECONNECTED', snapshot);
      socket.emit('ANSWER_ACCEPTED', {
        'matchId': 'match',
        'questionIndex': 1,
        'selectedOptionId': 'B',
      });
      socket.emit('MATCH_RECONNECTED', snapshot);
      expect(c.hasSubmittedAnswer.value, isTrue);
      expect(c.selectedOptionId.value, 'B');
      socket.emit('QUESTION_ENDED', {
        'matchId': 'match',
        'questionIndex': 1,
        'correctAnswer': 'B',
        'explanation': 'Released',
        'scores': [],
      });
      socket.emit('MATCH_RECONNECTED', snapshot);
      expect(c.isRoundEnded.value, isTrue);
      expect(c.roundCorrectAnswer.value, 'B');
      socket.emit('MATCH_RECONNECTED', {
        ...snapshot,
        'currentQuestionIndex': 0,
      });
      expect(c.currentQuestionIndex.value, 1);
    },
  );
}
