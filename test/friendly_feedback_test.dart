import 'package:aptiqu/core/feedback/app_feedback_service.dart';
import 'package:aptiqu/core/feedback/feedback_cue.dart';
import 'package:aptiqu/core/feedback/feedback_preferences.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/practice/controllers/practice_session_controller.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/repositories/practice_repository.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/social_api.dart';
import 'package:aptiqu/features/social/duel_room_screen.dart';
import 'package:aptiqu/shared/widgets/feedback/victory_celebration.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'support/feedback_fakes.dart';
import 'support/presentation_fonts.dart';

class _Auth extends AuthController {
  @override
  Future<void> fetchUserProfile() async {}
}

class _DuelApi extends SocialApi {
  String status = 'ACTIVE';
  String? winner = 'me';
  bool tie = false;
  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  ]) async => {
    'id': 'duel',
    'status': status,
    'winnerId': status == 'COMPLETED' ? winner : null,
    'isTie': status == 'COMPLETED' && tie,
    'remainingMs': 60000,
    'timerEnabled': true,
    'requester': {'id': 'me', 'name': 'Asha', 'level': 4},
    'recipient': {'id': 'other', 'name': 'Dev', 'level': 5},
    'sessions': [
      {
        'id': 'session',
        'userId': 'me',
        'correctCount': 6,
        'currentIndex': 10,
        'status': 'COMPLETED',
        'xpAwarded': status == 'COMPLETED' ? 10 : 0,
      },
      {
        'id': 'other-session',
        'userId': 'other',
        'correctCount': 5,
        'currentIndex': 10,
        'status': status == 'COMPLETED' ? 'COMPLETED' : 'ACTIVE',
        'xpAwarded': 0,
      },
    ],
    'selectionNotes': [],
    'subtopicIds': [],
    'sessionId': 'session',
  };
}

class _Social extends SocialController {
  final _DuelApi _api = _DuelApi();
  @override
  _DuelApi get api => _api;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> syncInbox() async {}
}

PracticeSessionModel _session({bool completed = false}) =>
    PracticeSessionModel.fromJson({
      'id': 'session',
      'status': completed ? 'COMPLETED' : 'ACTIVE',
      'isFriendlyDuel': true,
      'friendlyDuelId': 'duel',
      'timerEnabled': true,
      'totalQuestions': 10,
      'questions': [
        {
          'id': 'sq-0',
          'sequence': 1,
          'question': {
            'id': 'q-0',
            'prompt': '2 + 2',
            'options': [],
            'hints': [],
          },
        },
      ],
    });

class _Repository extends PracticeRepository {
  @override
  Future<PracticeSessionModel> getSession(
    String id, {
    CancelToken? cancelToken,
  }) async => _session(completed: true);
  @override
  Future<({int remainingMs, PracticeSessionModel session})>
  startFriendlyQuestion(String id) async =>
      (remainingMs: 60000, session: _session());
}

void main() {
  late _Social social;
  late RecordingFeedbackAudio audio;
  late AppFeedbackService feedback;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(DioClient(baseUrl: 'https://friendly.invalid'));
    final auth = Get.put<AuthController>(_Auth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'me@invalid',
      firstName: 'Asha',
    );
    social = _Social();
    Get.put<SocialController>(social);
    audio = RecordingFeedbackAudio();
    feedback = Get.put(
      AppFeedbackService(
        preferences: Get.put(FeedbackPreferences()),
        audio: audio,
        haptics: RecordingHaptics(),
      ),
    );
  });
  tearDown(() {
    Get.reset();
  });
  for (final outcome in ['win', 'loss', 'draw', 'abandoned']) {
    testWidgets(
      'Friendly $outcome waits for shared server outcome and deduplicates across room navigation',
      (tester) async {
        final c = Get.put(
          PracticeSessionController(_session(), repository: _Repository()),
        );
        c.begin(reduceMotion: true);
        await tester.pump();
        c.setFeedbackVisible(true);
        c.feedbackPresented();
        c.finishSession();
        c.feedbackPresented();
        await tester.pump();
        expect(
          audio.played.where(
            (c) => c == FeedbackCue.complete || c == FeedbackCue.victory,
          ),
          isEmpty,
        );
        social.api.status = outcome == 'abandoned' ? 'ABANDONED' : 'COMPLETED';
        social.api.winner = outcome == 'win' ? 'me' : 'other';
        social.api.tie = outcome == 'draw';
        social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
        await tester.pump();
        await tester.pump();
        c.feedbackPresented();
        c.feedbackPresented();
        await tester.pump();
        final terminal = audio.played
            .where((c) => c == FeedbackCue.victory || c == FeedbackCue.complete)
            .toList();
        expect(
          terminal,
          outcome == 'abandoned'
              ? []
              : [outcome == 'win' ? FeedbackCue.victory : FeedbackCue.complete],
        );
        expect(c.celebrateVictory.value, outcome == 'win');
        await Get.delete<PracticeSessionController>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AptiquTheme.lightTheme,
            home: const DuelRoomScreen(id: 'duel'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          audio.played
              .where(
                (c) => c == FeedbackCue.victory || c == FeedbackCue.complete,
              )
              .length,
          terminal.length,
        );
        expect(find.byType(VictoryCelebration), findsNothing);
        await tester.pumpWidget(const SizedBox());
        feedback.onClose();
        await tester.pump();
      },
    );
  }
  testWidgets('Friendly historical completion never starts a new victory', (
    tester,
  ) async {
    social.api.status = 'COMPLETED';
    await tester.pumpWidget(
      MaterialApp(
        theme: AptiquTheme.lightTheme,
        home: const DuelRoomScreen(id: 'duel'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(audio.played, isEmpty);
    expect(find.byType(VictoryCelebration), findsNothing);
    await tester.pumpWidget(const SizedBox());
    feedback.onClose();
    await tester.pump();
  });
}
