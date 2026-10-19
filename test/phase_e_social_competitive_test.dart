import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/routing/app_router.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_lobby_controller.dart';
import 'package:aptiqu/features/pvp/services/pvp_socket_service.dart';
import 'package:aptiqu/features/pvp/views/pvp_arena_screen.dart';
import 'package:aptiqu/features/pvp/views/pvp_lobby_view.dart';
import 'package:aptiqu/features/social/duel_room_screen.dart';
import 'package:aptiqu/features/social/friend_requests_screen.dart';
import 'package:aptiqu/features/social/friends_screen.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/widgets/friendship_actions.dart';
import 'package:aptiqu/features/social/widgets/learner_activity_window.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/practice/views/practice_session_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'home_navigation_test.dart' show LocalAuth, LocalHome;
import 'social_test.dart' show FakeSocial, ManualStopwatch;
import 'package:aptiqu/features/social/social_overlay.dart';
import 'phase_d_learning_test.dart' show questionData;
import 'support/presentation_fonts.dart';

const longName = 'Bea Narayanaswamy Ananthakrishnan';
Map<String, dynamic> profile({
  String name = 'Bea Learner',
  String relation = 'FRIEND',
  bool empty = false,
  bool large = false,
}) => {
  'id': 'friend',
  'name': name,
  'level': large
      ? 111
      : empty
      ? 1
      : 3,
  'avatarUrl': null,
  'today': '2026-10-19',
  'friendshipId': 'invitation',
  'friendshipVersion': '2026-10-18T12:00:00Z',
  'totalXp': large
      ? 123456
      : empty
      ? 0
      : 75,
  'currentStreak': large
      ? 12345
      : empty
      ? 0
      : 3,
  'highestStreak': large
      ? 23456
      : empty
      ? 0
      : 12,
  'coins': large
      ? 987654
      : empty
      ? 0
      : 35,
  'online': null,
  'relation': relation,
  'performance': {
    'attempted': empty
        ? 0
        : large
        ? 123456
        : 10,
    'correct': empty
        ? 0
        : large
        ? 100000
        : 8,
    'accuracy': empty
        ? null
        : large
        ? 100000 / 123456
        : .8,
    'averageSolveTimeMs': empty ? null : 12500,
  },
  'badges': [
    if (!empty)
      {
        'title': 'A steady start',
        'description': 'Build a learning habit, one day at a time.',
        'unlocked': true,
        'progress': 3,
        'target': 3,
      },
  ],
  'difficulty': [
    if (!empty)
      for (final row in [
        ('EASY', large ? 40000 : 5, large ? 40000 : 4),
        ('MEDIUM', large ? 40000 : 3, large ? 40000 : 3),
        ('HARD', large ? 43456 : 2, large ? 20000 : 1),
      ])
        {'difficulty': row.$1, 'attempted': row.$2, 'correct': row.$3},
  ],
  'activity': [],
  'ranked': empty ? null : {'result': 'Win', 'correct': 8},
};
Map<String, dynamic> history(String id, {bool win = true, bool tie = false}) =>
    {
      'matchId': id,
      'score': win ? 8 : 5,
      'opponentScore': 5,
      'totalQuestions': 10,
      'isWinner': win,
      'isTie': tie,
      'xpAwarded': win ? 100 : 0,
      'joinedAt': '2026-10-18T12:00:00Z',
      'status': 'COMPLETED',
      'avgResponseTimeMs': 12000,
      'opponent': {'userId': 'friend', 'name': longName, 'level': 3},
    };

class EAdapter implements HttpClientAdapter {
  String relation = 'NONE', profileName = 'Bea Learner', duelStatus = 'PENDING';
  bool recipient = false,
      ownFinished = false,
      fail = false,
      failHistory = false,
      failActivity = false,
      empty = false,
      large = false;
  bool duelTie = false;
  int remainingMs = 60000, replayCalls = 0, practiceGets = 0;
  Completer<void>? gate;
  final calls = <RequestOptions>[];
  final requests = <Map<String, dynamic>>[
    {
      'id': 'invitation',
      'version': '2026-10-18T12:00:00Z',
      'sender': {'id': 'friend', 'name': 'Bea Learner', 'level': 3},
    },
  ];
  Map<String, dynamic> get duel => {
    'id': 'duel',
    'status': duelStatus,
    'remainingMs': remainingMs,
    'requester': {
      'id': recipient ? 'friend' : 'me',
      'name': recipient ? profileName : 'Asha',
    },
    'recipient': {
      'id': recipient ? 'me' : 'friend',
      'name': recipient ? 'Asha' : profileName,
    },
    'smartPicks': true,
    'timerEnabled': false,
    'selectionNotes': <String>[],
    'sessionId': 'friendly-session',
    'winnerId': duelStatus == 'COMPLETED' && !duelTie ? 'me' : null,
    'isTie': duelTie,
    'sessions': [
      if (['ACTIVE', 'COMPLETED', 'ABANDONED'].contains(duelStatus))
        for (final id in ['me', 'friend'])
          {
            'userId': id,
            'status': duelStatus == 'COMPLETED' || id == 'me' && ownFinished
                ? 'COMPLETED'
                : 'ACTIVE',
            'correctCount': id == 'me' || duelTie ? 8 : 5,
            'xpAwarded': duelStatus == 'COMPLETED' ? 10 : 0,
          },
    ],
  };
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    if (gate != null && o.method == 'POST') await gate!.future;
    var status = 200;
    Object data = {};
    var failed =
        fail ||
        failHistory && o.path.endsWith('/pvp/history') ||
        failActivity && o.path.endsWith('/activity');
    if (o.path.endsWith('/social/friends') ||
        o.path.endsWith('/social/search')) {
      data = {
        'items': empty
            ? []
            : [
                o.path.endsWith('/friends')
                    ? {
                        ...profile(name: profileName),
                        'online': false,
                        'friendsSince': '2026-10-01T00:00:00Z',
                      }
                    : profile(name: profileName, relation: relation),
              ],
        'nextCursor': o.queryParameters['cursor'] == null ? 'page-2' : null,
      };
    } else if (o.path.endsWith('/social/inbox')) {
      data = {'friends': requests, 'duels': [], 'activeDuelId': null};
    } else if (o.path.contains('/social/profiles/') &&
        !o.path.endsWith('/activity')) {
      data = profile(
        name: profileName,
        relation: relation,
        empty: empty,
        large: large,
      );
    } else if (o.path.endsWith('/activity')) {
      data = {'activity': []};
    } else if (o.path.endsWith('/social/duels/duel')) {
      data = duel;
    } else if (o.path.endsWith('/social/duels/duel/respond')) {
      final action = (o.data as Map)['action'];
      if (action == 'accept') {
        duelStatus = 'ACTIVE';
      } else {
        duelStatus = action == 'cancel' ? 'CANCELLED' : 'REJECTED';
      }
      data = duel;
    } else if (o.path.endsWith('/social/duels/duel/leave')) {
      duelStatus = 'ABANDONED';
      data = duel;
    } else if (o.path.contains('/social/friend-invitations/') &&
        o.path.endsWith('/respond')) {
      if (!failed) {
        relation = (o.data as Map)['accept'] == true ? 'FRIEND' : 'NONE';
        requests.clear();
      }
    } else if (o.path.endsWith('/invite')) {
      relation = 'INVITED';
    } else if (o.path.endsWith('/social/friends/friend') &&
        o.method == 'DELETE') {
      relation = 'NONE';
    } else if (o.path.endsWith('/pvp/history')) {
      data = {
        'history': empty
            ? []
            : [history('match'), history('draw', win: false, tie: true)],
      };
    } else if (o.path.contains('/pvp/replay/')) {
      replayCalls++;
      status = 201;
      data = practiceJson(replay: true);
    } else if (o.path.endsWith('/practice/sessions/friendly-session')) {
      practiceGets++;
      data = practiceJson();
    } else if (o.path.endsWith('/start-question')) {
      data = {'remainingMs': 60000};
    } else {
      throw StateError('Unexpected request ${o.method} ${o.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': !failed,
        if (failed) 'message': 'Connection unavailable. Please retry.',
        'data': data,
      }),
      failed ? 503 : status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> practiceJson({bool replay = false}) => {
    'id': 'friendly-session',
    'isFriendlyDuel': !replay,
    'friendlyDuelId': replay ? null : 'duel',
    'isReplay': replay,
    'timerEnabled': false,
    'totalQuestions': 10,
    'questions': [
      for (var i = 0; i < 10; i++)
        {'id': 'sq-$i', 'sequence': i + 1, 'question': questionData(i)},
    ],
  };
}

class ESocket implements PvpSocketService {
  final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Stream<Map<String, dynamic>> get eventStream => events.stream;
  @override
  bool isConnected = true;
  @override
  bool isAuthenticated = true;
  int connects = 0, joins = 0, leaves = 0, reconnects = 0;
  final answers = <Map<String, dynamic>>[];
  Completer<void>? connectGate;
  @override
  Future<void> connect() async {
    connects++;
    if (connectGate != null) await connectGate!.future;
  }

  @override
  Future<void> joinMatchmaking() async {
    joins++;
  }

  @override
  void leaveMatchmaking() {
    leaves++;
  }

  @override
  void reconnectMatch(String matchId) {
    reconnects++;
  }

  @override
  void submitAnswer({
    required String matchId,
    required int questionIndex,
    required String? selectedOptionId,
    required int responseTimeMs,
  }) {
    answers.add({
      'matchId': matchId,
      'questionIndex': questionIndex,
      'selectedOptionId': selectedOptionId,
      'responseTimeMs': responseTimeMs,
    });
  }

  @override
  void send(String type, [Map<String, dynamic>? payload]) {}
  @override
  void disconnect() {
    isConnected = false;
    isAuthenticated = false;
  }

  void emit(String type, [Map<String, dynamic> data = const {}]) =>
      events.add({'event': type, 'data': data});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EAdapter adapter;
  late ESocket socket;
  late AppearanceController appearance;
  late FakeSocial social;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    final client = Get.put(DioClient(baseUrl: 'http://fixture.invalid/api/v1'));
    adapter = EAdapter();
    client.dio.httpClientAdapter = adapter;
    social = Get.put<SocialController>(FakeSocial()) as FakeSocial;
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      firstName: 'Asha',
      lastName: 'Kumar',
      email: 'asha@example.test',
      isRegistrationComplete: true,
    );
    appearance = Get.put(AppearanceController());
    socket = ESocket();
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
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
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: RepaintBoundary(key: const ValueKey('capture-e'), child: child),
    );
    await tester.pumpWidget(
      router == null
          ? MaterialApp(
              theme: appearance.mode.value == ThemeMode.dark
                  ? AptiquTheme.darkTheme
                  : AptiquTheme.lightTheme,
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
    await flush(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await flush(tester);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
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
    if (!const bool.fromEnvironment('CAPTURE_PHASE_E')) return;
    await flush(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-e')),
      );
      final img = await boundary.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_e/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  PvpArenaController arena({bool long = false}) => Get.put(
    PvpArenaController(
      matchId: 'match',
      initialPlayersData: [
        {'userId': 'friend', 'firstName': long ? longName : 'Bea Learner'},
      ],
      totalQuestions: 10,
      socketService: socket,
    ),
  );
  PvpArenaScreen arenaScreen() => const PvpArenaScreen(
    matchId: 'match',
    initialPlayersData: [],
    totalQuestions: 10,
  );
  void question({int index = 0, bool long = false}) =>
      socket.emit('QUESTION_STARTED', {
        'questionIndex': index,
        'durationSeconds': 60,
        'question': questionData(index, long: long),
      });
  void complete({bool win = true, bool tie = false, bool afk = false}) =>
      socket.emit('MATCH_COMPLETED', {
        'winnerId': win ? 'me' : 'friend',
        'isTie': tie,
        'players': [
          {'userId': 'me', 'score': 8, 'xpAwarded': win ? 100 : 0},
          {'userId': 'friend', 'score': 5, 'isAfk': afk},
        ],
      });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode.name;
    testWidgets('Friends search, identity and paging $suffix', (tester) async {
      appearance.mode.value = mode;
      await show(tester, const FriendsScreen(embedded: true));
      await capture(tester, 'friends-$suffix');
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
        'Search learners',
      );
      await tap(tester, find.byKey(const ValueKey('next-friends-page')));
      expect(find.text('2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bea');
      await tester.pump(const Duration(milliseconds: 400));
      await flush(tester);
      await capture(tester, 'friends-search-$suffix');
      await tap(tester, find.text('Add Friend'));
      expect(adapter.relation, 'INVITED');
      expect(find.text('Request sent'), findsOneWidget);
    });
    testWidgets('requests and profile relationship actions $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      adapter.relation = 'INCOMING';
      await show(tester, const FriendRequestsScreen());
      await capture(tester, 'friend-requests-$suffix');
      await tap(tester, find.text('Bea Learner'));
      await capture(tester, 'learner-profile-$suffix');
      expect(find.text('N/A'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('reject-request')));
      expect(adapter.requests, isEmpty);
      expect(
        (adapter.calls.firstWhere((o) => o.path.endsWith('/respond')).data
            as Map)['version'],
        '2026-10-18T12:00:00Z',
      );
      await tester.binding.handlePopRoute();
      await flush(tester);
      expect(find.text('You’re all caught up'), findsOneWidget);
    });
    testWidgets('learner profile metrics and activity $suffix', (tester) async {
      appearance.mode.value = mode;
      adapter.relation = 'FRIEND';
      await show(tester, const FriendProfileScreen(id: 'friend'));
      await tap(tester, find.text('Remove friend'));
      await capture(tester, 'remove-friend-$suffix');
      await tap(tester, find.text('Cancel'));
      await tester.scrollUntilVisible(
        find.byType(LearnerActivityWindow),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await flush(tester);
      await capture(tester, 'learner-activity-$suffix');
    });
    testWidgets('friendly requester recipient and completed room $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      await show(tester, const DuelRoomScreen(id: 'duel'));
      expect(find.text('Waiting for your friend'), findsOneWidget);
      await capture(tester, 'duel-requester-$suffix');
      adapter.recipient = true;
      social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
      await flush(tester);
      expect(find.text('You’re invited to a duel'), findsOneWidget);
      await capture(tester, 'duel-recipient-$suffix');
      await tap(tester, find.text('Accept duel'));
      expect(adapter.duelStatus, 'ACTIVE');
      await capture(tester, 'duel-active-$suffix');
      await tap(tester, find.text('Leave duel (no reward)'));
      await capture(tester, 'duel-leave-$suffix');
      await tap(tester, find.text('Stay'));
      expect(adapter.duelStatus, 'ACTIVE');
      adapter.duelStatus = 'COMPLETED';
      social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
      await flush(tester);
      expect(find.text('You won'), findsOneWidget);
      await capture(tester, 'duel-completed-$suffix');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('Ranked lobby action queue and history $suffix', (
      tester,
    ) async {
      appearance.mode.value = mode;
      final c = Get.put(PvpLobbyController(socketService: socket));
      await tester.runAsync(c.fetchHistory);
      await show(tester, const Scaffold(body: PvpLobbyView()));
      await capture(tester, 'ranked-lobby-$suffix');
      await tap(tester, find.text('Find match'));
      expect(socket.joins, 1);
      socket.emit('QUEUE_STATUS', {'status': 'WAITING_FOR_OPPONENT'});
      await flush(tester);
      await capture(tester, 'ranked-queue-$suffix');
      await tap(tester, find.text('Cancel matchmaking'));
      expect(socket.leaves, 1);
      await capture(tester, 'ranked-cancelling-$suffix');
      socket.emit('QUEUE_STATUS', {'status': 'LEFT_QUEUE'});
      await flush(tester);
      c.historyError.value = 'Could not load match history. Please try again.';
      await tester.scrollUntilVisible(find.text('Recent matches'), 250);
      await flush(tester);
      await capture(tester, 'ranked-history-error-$suffix');
      Get.delete<PvpLobbyController>();
    });
    testWidgets(
      'Ranked immediate answer acknowledgement feedback and result $suffix',
      (tester) async {
        appearance.mode.value = mode;
        final c = arena();
        await show(tester, arenaScreen());
        await capture(tester, 'ranked-waiting-$suffix');
        question();
        await flush(tester);
        await capture(tester, 'ranked-player-$suffix');
        await tap(tester, find.text('4 chocolates'));
        expect(socket.answers.single['selectedOptionId'], 'B');
        expect(
          find.textContaining(RegExp(r'^\d+s remaining$')).hitTestable(),
          findsOneWidget,
        );
        expect(c.hasSubmittedAnswer.value, isFalse);
        await capture(tester, 'ranked-pending-$suffix');
        c.selectOption('A');
        expect(socket.answers.length, 1);
        socket.emit('ANSWER_ACCEPTED', {'questionIndex': 0});
        await flush(tester);
        await capture(tester, 'ranked-locked-$suffix');
        socket.emit('QUESTION_ENDED', {
          'correctAnswer': 'B',
          'explanation': '12 ÷ 3 = 4. Each person gets 4 chocolates.',
          'scores': [
            {'userId': 'me', 'score': 1},
            {'userId': 'friend', 'score': 0},
          ],
        });
        await flush(tester);
        await tester.scrollUntilVisible(find.text('Correct!'), 250);
        await capture(tester, 'ranked-feedback-$suffix');
        complete();
        await flush(tester);
        await capture(tester, 'ranked-result-$suffix');
        expect(c.xpAwarded.value, 100);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      final label = '${mode.name}-${size.width.toInt()}';
      testWidgets('social large controls, keyboard and confirmations $label', (
        tester,
      ) async {
        appearance.mode.value = mode;
        adapter.profileName = longName;
        adapter.large = true;
        adapter.relation = 'FRIEND';
        await show(
          tester,
          const FriendsScreen(picker: true),
          size: size,
          scale: 2,
          keyboard: 100,
        );
        await capture(tester, 'friend-picker-large-$label');
        await show(tester, const FriendRequestsScreen(), size: size, scale: 2);
        await capture(tester, 'requests-large-$label');
        expect(
          tester.getSize(find.byKey(const ValueKey('accept-request'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('reject-request'))).height,
          greaterThanOrEqualTo(48),
        );
        await show(
          tester,
          const FriendProfileScreen(id: 'friend'),
          size: size,
          scale: 2,
        );
        await tap(tester, find.text('Remove friend'));
        await capture(tester, 'remove-large-$label');
        await tap(tester, find.text('Cancel'));
        await tester.scrollUntilVisible(
          find.text('Performance'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await flush(tester);
        await capture(tester, 'profile-large-$label');
        await show(
          tester,
          const DuelRoomScreen(id: 'duel'),
          size: size,
          scale: 2,
        );
        await tap(tester, find.byTooltip('Back'));
        await capture(tester, 'duel-back-large-$label');
        await tap(tester, find.text('Stay'));
        await tester.pumpWidget(const SizedBox());
        final clock = ManualStopwatch();
        await show(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SocialInvitationDialog(
                    invitation: {
                      'id': 'duel',
                      'remainingMs': 60000,
                      'requester': {'name': longName},
                      'smartPicks': true,
                      'timerEnabled': true,
                    },
                    duel: true,
                    stopwatch: clock,
                  ),
                ),
                child: const Text('Open invitation'),
              ),
            ),
          ),
          size: size,
          scale: 2,
        );
        await tap(tester, find.text('Open invitation'));
        await capture(tester, 'duel-invitation-large-$label');
        clock.milliseconds = 60000;
        await tester.pump(const Duration(seconds: 1));
        await flush(tester);
        expect(find.text('Duel invitation'), findsNothing);
      });
      testWidgets('Ranked large policy, question and draw result $label', (
        tester,
      ) async {
        appearance.mode.value = mode;
        final c = arena(long: true);
        await show(tester, arenaScreen(), size: size, scale: 2);
        await tap(tester, find.byTooltip('About leaving this match'));
        await capture(tester, 'ranked-policy-large-$label');
        await tap(tester, find.text('Got it'));
        question(long: true);
        await flush(tester);
        await capture(tester, 'ranked-player-large-$label');
        complete(win: false, tie: true);
        await flush(tester);
        await tester.scrollUntilVisible(find.text('Return to Ranked'), 250);
        await capture(tester, 'ranked-result-large-$label');
        expect(c.isTie.value, isTrue);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('social empty and recoverable error states ${mode.name}', (
      tester,
    ) async {
      appearance.mode.value = mode;
      adapter.empty = true;
      await show(tester, const FriendsScreen(embedded: true));
      expect(find.text('Learn better together'), findsOneWidget);
      await capture(tester, 'friends-empty-${mode.name}');
      await show(tester, const FriendProfileScreen(id: 'friend'));
      expect(find.text('N/A'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);
      await capture(tester, 'profile-empty-${mode.name}');
      adapter.fail = true;
      await show(tester, const DuelRoomScreen(id: 'duel'));
      await capture(tester, 'duel-error-${mode.name}');
      expect(find.text('Loading friendly duel'), findsNothing);
      adapter.fail = false;
      await tap(tester, find.text('Retry'));
      expect(find.text('Waiting for your friend'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('friendly terminal states and own completion ${mode.name}', (
      tester,
    ) async {
      appearance.mode.value = mode;
      for (final state in [
        ('EXPIRED', 'Invitation expired'),
        ('REJECTED', 'Invitation declined'),
        ('CANCELLED', 'Invitation cancelled'),
        ('ABANDONED', 'Duel ended'),
        ('COMPLETED', 'Draw'),
      ]) {
        adapter.duelStatus = state.$1;
        adapter.duelTie = state.$1 == 'COMPLETED';
        await show(tester, const DuelRoomScreen(id: 'duel'));
        expect(find.text(state.$2), findsOneWidget);
        expect(find.text('Resume duel'), findsNothing);
        expect(find.text('Accept duel'), findsNothing);
        await capture(
          tester,
          'duel-${state.$1 == 'COMPLETED' ? 'draw' : state.$1.toLowerCase()}-${mode.name}',
        );
        await tester.pumpWidget(const SizedBox());
      }
      adapter.duelStatus = 'ACTIVE';
      adapter.ownFinished = true;
      await show(tester, const DuelRoomScreen(id: 'duel'));
      expect(find.textContaining('You finished. Waiting'), findsOneWidget);
      expect(find.text('Resume duel'), findsNothing);
      await capture(tester, 'duel-own-finished-${mode.name}');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('Ranked loss, interruption and recovered result ${mode.name}', (
      tester,
    ) async {
      appearance.mode.value = mode;
      arena();
      question();
      await show(tester, arenaScreen());
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      socket.emit('CONNECTION_LOST', {'message': 'Connection interrupted'});
      await flush(tester);
      await capture(tester, 'ranked-interruption-${mode.name}');
      await tap(tester, find.text('Refresh match'));
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'COMPLETED',
        'players': [
          {'userId': 'me', 'score': 2},
          {'userId': 'friend', 'score': 8},
        ],
      });
      await flush(tester);
      expect(find.text('Match finished'), findsOneWidget);
      expect(find.text('XP awarded'), findsNothing);
      await capture(tester, 'ranked-recovered-result-${mode.name}');
      await tester.pumpWidget(const SizedBox());
      final next = arena();
      await show(tester, arenaScreen());
      socket.emit('MATCH_COMPLETED', {
        'winnerId': 'friend',
        'isTie': false,
        'players': [
          {'userId': 'me', 'score': 2, 'xpAwarded': 0},
          {'userId': 'friend', 'score': 8, 'isAfk': true},
        ],
      });
      await flush(tester);
      expect(find.text('Defeat'), findsOneWidget);
      expect(
        find.textContaining('Your opponent left or disconnected'),
        findsOneWidget,
      );
      expect(next.xpAwarded.value, 0);
      await capture(tester, 'ranked-defeat-afk-${mode.name}');
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('invitation response stays single while busy across expiry', (
    tester,
  ) async {
    final clock = ManualStopwatch();
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => SocialInvitationDialog(
                invitation: {
                  'id': 'duel',
                  'remainingMs': 60000,
                  'requester': {'name': 'Bea Learner'},
                  'smartPicks': false,
                  'timerEnabled': true,
                },
                duel: true,
                stopwatch: clock,
              ),
            ),
            child: const Text('Open invitation'),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open invitation'));
    adapter.gate = Completer<void>();
    await tap(tester, find.text('Accept'));
    expect(find.text('Responding…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reject'))
          .onPressed,
      isNull,
    );
    clock.milliseconds = 60000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Duel invitation'), findsOneWidget);
    adapter.gate!.complete();
    await flush(tester);
    await flush(tester);
    expect(find.text('Duel invitation'), findsNothing);
    expect(adapter.calls.where((o) => o.path.endsWith('/respond')).length, 1);
  });
  testWidgets('invitation failure keeps a readable retry and accepts once', (
    tester,
  ) async {
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SocialInvitationDialog(
                invitation: {
                  'id': 'invitation',
                  'version': '2026-10-18T12:00:00Z',
                  'sender': {'name': 'Bea Learner'},
                },
              ),
            ),
            child: const Text('Open invitation'),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open invitation'));
    adapter.fail = true;
    await tap(tester, find.text('Accept'));
    await flush(tester);
    expect(find.text('Connection unavailable. Please retry.'), findsOneWidget);
    adapter.fail = false;
    await tap(tester, find.text('Accept'));
    await flush(tester);
    expect(find.text('Friend invitation'), findsNothing);
    expect(adapter.calls.where((o) => o.path.endsWith('/respond')).length, 2);
  });
  testWidgets(
    'requests cached failure remains scrollable at enlarged landscape',
    (tester) async {
      appearance.mode.value = ThemeMode.dark;
      await show(
        tester,
        const FriendRequestsScreen(),
        size: const Size(568, 320),
        scale: 2,
      );
      adapter.fail = true;
      social.events.add({'event': 'INBOX_CHANGED'});
      await flush(tester);
      expect(find.text('Could not load friend requests.'), findsOneWidget);
      expect(find.text('Bea Learner'), findsOneWidget);
      await capture(tester, 'requests-error-large-dark-568');
      adapter.fail = false;
      await tap(tester, find.text('Retry'));
      expect(find.text('Could not load friend requests.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('automatic friendly play opens the same session only once', (
    tester,
  ) async {
    adapter.duelStatus = 'ACTIVE';
    AppRouter.router.go('/friendly-duel/duel?play=1');
    await show(tester, const SizedBox(), router: AppRouter.router);
    await flush(tester);
    await flush(tester);
    expect(find.byType(PracticeSessionScreen), findsOneWidget);
    expect(adapter.practiceGets, 1);
    social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
    await flush(tester);
    expect(adapter.practiceGets, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'match found remains authoritative during cancellation and opens once',
    (tester) async {
      final home = Get.put<HomeController>(LocalHome());
      home.selectedNavIndex.value = 3;
      final lobby = Get.put(PvpLobbyController(socketService: socket));
      final c = arena();
      AppRouter.router.go('/');
      await show(tester, const SizedBox(), router: AppRouter.router);
      await lobby.startMatchmaking();
      lobby.cancelMatchmaking();
      socket.emit('MATCH_FOUND', {
        'matchId': 'match',
        'players': [],
        'totalQuestions': 10,
      });
      socket.emit('MATCH_FOUND', {
        'matchId': 'match',
        'players': [],
        'totalQuestions': 10,
      });
      await flush(tester);
      expect(find.byType(PvpArenaScreen), findsOneWidget);
      expect(lobby.isOpeningMatch.value, isTrue);
      complete(win: false, afk: true);
      await flush(tester);
      expect(c.isMatchCompleted.value, isTrue);
      await tap(tester, find.text('Return to Ranked'));
      expect(find.byType(PvpArenaScreen), findsNothing);
      expect(lobby.isOpeningMatch.value, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Ranked replay has one existing API request and opens Practice', (
    tester,
  ) async {
    final home = Get.put<HomeController>(LocalHome());
    home.selectedNavIndex.value = 3;
    final lobby = Get.put(PvpLobbyController(socketService: socket));
    AppRouter.router.go('/');
    await show(tester, const SizedBox(), router: AppRouter.router);
    adapter.gate = Completer<void>();
    final first = lobby.replayMatchInPractice('match');
    await lobby.replayMatchInPractice('match');
    await flush(tester);
    expect(adapter.replayCalls, 0);
    adapter.gate!.complete();
    await flush(tester);
    await flush(tester);
    expect(adapter.replayCalls, 1);
    expect(find.byType(PracticeSessionScreen), findsOneWidget);
    expect(find.text('Practice replay'), findsOneWidget);
    AppRouter.router.pop();
    await flush(tester);
    await first;
    expect(lobby.isReplayingMatch.value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'learner month caching and retry retain the requested IST month',
    (tester) async {
      adapter.failActivity = true;
      await show(tester, const FriendProfileScreen(id: 'friend'));
      await tester.scrollUntilVisible(
        find.byType(LearnerActivityWindow),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await flush(tester);
      final calendar = find.descendant(
        of: find.byType(YearActivityCalendar),
        matching: find.byType(ListView),
      );
      await tester.ensureVisible(calendar);
      await flush(tester);
      adapter.failActivity = true;
      await tester.drag(calendar, const Offset(0, 350));
      await flush(tester);
      expect(find.text('Could not load this month. Retry'), findsWidgets);
      adapter.failActivity = false;
      await tap(tester, find.text('Could not load this month. Retry').first);
      final months = adapter.calls
          .where((o) => o.path.endsWith('/activity'))
          .map((o) => o.queryParameters['month']);
      expect(
        months.where((m) => m == '2026-09').length,
        greaterThanOrEqualTo(2),
      );
      final count = adapter.calls
          .where(
            (o) =>
                o.path.endsWith('/activity') &&
                o.queryParameters['month'] == '2026-09',
          )
          .length;
      await tester.drag(calendar, const Offset(0, -350));
      await flush(tester);
      await tester.drag(calendar, const Offset(0, 350));
      await flush(tester);
      expect(
        adapter.calls
            .where(
              (o) =>
                  o.path.endsWith('/activity') &&
                  o.queryParameters['month'] == '2026-09',
            )
            .length,
        count,
      );
    },
  );
  testWidgets(
    'friend presence and cached refresh failure keep identity visible',
    (tester) async {
      await show(tester, const FriendsScreen(embedded: true));
      social.events.add({
        'event': 'PRESENCE',
        'items': [
          {'id': 'friend', 'online': true},
        ],
      });
      await flush(tester);
      expect(find.text('Level 3 · Online'), findsOneWidget);
      adapter.fail = true;
      social.events.add({'event': 'RECONNECTED'});
      await flush(tester);
      expect(find.text('Bea Learner'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );
  testWidgets('friend removal confirms the existing delete operation once', (
    tester,
  ) async {
    adapter.relation = 'FRIEND';
    await show(tester, const FriendProfileScreen(id: 'friend'));
    await tap(tester, find.text('Remove friend'));
    await tap(tester, find.text('Remove'));
    expect(adapter.relation, 'NONE');
    expect(adapter.calls.where((o) => o.method == 'DELETE').length, 1);
  });
  testWidgets(
    'reconnect waits for authentication and sends one snapshot request',
    (tester) async {
      final c = arena();
      socket.isAuthenticated = false;
      await c.recoverConnection();
      expect(socket.reconnects, 0);
      socket.isAuthenticated = true;
      socket.emit('AUTH_SUCCESS');
      socket.emit('AUTH_SUCCESS');
      expect(socket.reconnects, 1);
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'STARTING',
        'remainingMs': 0,
        'question': questionData(0),
        'players': [],
      });
      expect(c.currentQuestion.value, isNull);
      expect(c.remainingSeconds.value, 0);
      Get.delete<PvpArenaController>();
    },
  );
  testWidgets('friend picker returns identity instead of opening a profile', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              selected = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => const FriendsScreen(picker: true),
                ),
              );
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open picker'));
    await tap(tester, find.text('Bea Learner'));
    expect(selected?['id'], 'friend');
    expect(find.byType(FriendProfileScreen), findsNothing);
  });
  testWidgets('friendship busy guard keeps one response and server version', (
    tester,
  ) async {
    adapter.gate = Completer<void>();
    final person = profile(relation: 'INCOMING');
    await show(
      tester,
      Scaffold(
        body: FriendshipActions(
          person: person,
          fullWidth: true,
          onChanged: () async {},
        ),
      ),
    );
    await tap(tester, find.text('Accept'));
    final action = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Accept'))
        .onPressed;
    expect(action, isNull);
    expect(adapter.calls.where((o) => o.path.endsWith('/respond')).length, 1);
    adapter.gate!.complete();
    await flush(tester);
    expect(adapter.requests, isEmpty);
  });
  testWidgets('friendly initial error has retry without spinner', (
    tester,
  ) async {
    adapter.fail = true;
    await show(tester, const DuelRoomScreen(id: 'duel'));
    expect(find.text('Could not load this duel'), findsOneWidget);
    expect(find.text('Loading friendly duel'), findsNothing);
    adapter.fail = false;
    await tap(tester, find.text('Retry'));
    expect(find.text('Waiting for your friend'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'friendly role-specific back and active leave preserve existing actions',
    (tester) async {
      adapter.recipient = true;
      await show(tester, const DuelRoomScreen(id: 'duel'));
      await tap(tester, find.byTooltip('Back'));
      await tap(tester, find.text('Stay'));
      expect(adapter.calls.where((o) => o.method == 'POST'), isEmpty);
      await tap(tester, find.text('Reject invitation'));
      expect(
        (adapter.calls.firstWhere((o) => o.method == 'POST').data
            as Map)['action'],
        'reject',
      );
      adapter.duelStatus = 'ACTIVE';
      social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
      await flush(tester);
      await tap(tester, find.text('Leave duel (no reward)'));
      await tap(tester, find.widgetWithText(FilledButton, 'Leave duel'));
      expect(adapter.duelStatus, 'ABANDONED');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'friendly update during confirmation cannot change the agreed consequence',
    (tester) async {
      adapter.duelStatus = 'ACTIVE';
      await show(tester, const DuelRoomScreen(id: 'duel'));
      await tap(tester, find.text('Leave duel (no reward)'));
      adapter.duelStatus = 'COMPLETED';
      social.events.add({'event': 'DUEL_CHANGED', 'id': 'duel'});
      await flush(tester);
      await tap(tester, find.widgetWithText(FilledButton, 'Leave duel'));
      expect(adapter.calls.where((o) => o.path.endsWith('/leave')), isEmpty);
      expect(find.text('You won'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('queue cancellation before connecting cannot join later', (
    tester,
  ) async {
    final c = Get.put(PvpLobbyController(socketService: socket));
    await flush(tester);
    socket.isConnected = false;
    socket.connectGate = Completer<void>();
    final start = c.startMatchmaking();
    c.cancelMatchmaking();
    socket.isConnected = true;
    socket.connectGate!.complete();
    await start;
    expect(socket.joins, 0);
    expect(c.isInQueue.value, isFalse);
    await flush(tester);
    Get.delete<PvpLobbyController>();
  });
  testWidgets(
    'queue cancellation waits for acknowledgement and exposes failed history',
    (tester) async {
      final c = Get.put(PvpLobbyController(socketService: socket));
      await flush(tester);
      await c.startMatchmaking();
      await c.startMatchmaking();
      expect(socket.joins, 1);
      c.cancelMatchmaking();
      c.cancelMatchmaking();
      expect(socket.leaves, 1);
      expect(c.isCancelling.value, isTrue);
      socket.emit('QUEUE_STATUS', {'status': 'LEFT_QUEUE'});
      expect(c.isInQueue.value, isFalse);
      expect(c.isCancelling.value, isFalse);
      adapter.failHistory = true;
      await tester.runAsync(c.fetchHistory);
      expect(c.matchHistory.length, 2);
      expect(c.historyError.isNotEmpty, isTrue);
      await flush(tester);
      Get.delete<PvpLobbyController>();
    },
  );
  testWidgets(
    'Ranked reconnect restores remaining time without resetting a minute',
    (tester) async {
      final c = arena();
      await c.recoverConnection();
      expect(socket.reconnects, 1);
      await c.recoverConnection();
      expect(socket.reconnects, 1);
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 2,
        'remainingMs': 23000,
        'question': questionData(2),
        'players': [
          {'userId': 'me', 'score': 4},
          {'userId': 'friend', 'score': 2},
        ],
      });
      expect(c.remainingSeconds.value, 23);
      expect(c.myScore.value, 4);
      c.selectOption('B');
      expect(
        socket.answers.single['responseTimeMs'] as int,
        greaterThanOrEqualTo(37000),
      );
      await tester.pump(const Duration(seconds: 24));
      expect(socket.answers.length, 1);
      Get.delete<PvpArenaController>();
    },
  );
  testWidgets(
    'Ranked reconnect preserves a pending choice and handles completion honestly',
    (tester) async {
      final c = arena();
      question();
      c.selectOption('A');
      await c.recoverConnection();
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'QUESTION_ACTIVE',
        'currentQuestionIndex': 0,
        'remainingMs': 12000,
        'question': questionData(0),
        'players': [],
      });
      expect(c.selectedOptionId.value, 'A');
      c.selectOption('B');
      expect(socket.answers.length, 1);
      await c.recoverConnection();
      socket.emit('MATCH_RECONNECTED', {
        'matchId': 'match',
        'status': 'COMPLETED',
        'players': [
          {'userId': 'me', 'score': 8},
          {'userId': 'friend', 'score': 5},
        ],
      });
      expect(c.recoveredCompletion.value, isTrue);
      expect(c.isMatchCompleted.value, isFalse);
      await show(tester, arenaScreen());
      expect(find.text('Match finished'), findsOneWidget);
      expect(find.text('XP awarded'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Ranked connection interruption is visible and retry can time out safely',
    (tester) async {
      final c = arena();
      question();
      socket.emit('CONNECTION_LOST', {'message': 'Connection interrupted'});
      await show(tester, arenaScreen());
      expect(find.textContaining('Match timing continues'), findsOneWidget);
      c.selectOption('A');
      expect(socket.answers, isEmpty);
      await c.recoverConnection();
      await tester.pump(const Duration(seconds: 15));
      expect(c.connectionError.isNotEmpty, isTrue);
      expect(c.isRecovering.value, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Ranked invalid route recovers without creating a match', (
    tester,
  ) async {
    final route = AppRouter.router.configuration.routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == '/pvp-arena');
    final router = GoRouter(
      initialLocation: '/pvp-arena',
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
    expect(find.text('No active Ranked match'), findsOneWidget);
    await tap(tester, find.text('Return to Home'));
    expect(find.text('Home destination'), findsOneWidget);
  });
  testWidgets(
    'live theme changes retain Ranked question selection and controller',
    (tester) async {
      final c = arena();
      question();
      await show(tester, arenaScreen());
      await tap(tester, find.text('4 chocolates'));
      appearance.mode.value = ThemeMode.dark;
      await flush(tester);
      expect(Get.find<PvpArenaController>(), same(c));
      expect(c.selectedOptionId.value, 'B');
      expect(c.currentQuestionIndex.value, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
