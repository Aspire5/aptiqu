import 'package:aptiqu/features/pvp/services/pvp_socket_service.dart';
import 'package:aptiqu/features/pvp/views/pvp_arena_screen.dart';
import 'package:dio/dio.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/profile/presentation/screens/profile_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/models/home_dashboard_model.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_lobby_controller.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_browser_screen.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_models.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_repository.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_result.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_widgets.dart';
import 'package:aptiqu/features/pvp/views/pvp_lobby_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'phase_e_social_competitive_test.dart' show ESocket;
import 'support/presentation_fonts.dart';

Map<String, dynamic> rankedSummary({
  bool qualified = true,
  String month = '2026-10',
  int version = 3,
  String? active,
}) => {
  'serverNow': '2026-10-20T12:00:00Z',
  'asOf': '2026-10-20T12:00:00Z',
  'currentSeasonId': month,
  'season': {
    'id': month,
    'startsAt': '2026-09-30T18:30:00Z',
    'endsAt': '2026-10-31T18:30:00Z',
    'status': 'ACTIVE',
  },
  'standing': {
    'league': qualified ? 'PLATINUM' : 'UNRANKED',
    'rating': qualified ? 1500 : 1200,
    'position': qualified ? 123456 : null,
    'played': qualified ? 30 : 2,
    'wins': qualified ? 20 : 1,
    'losses': qualified ? 8 : 1,
    'draws': qualified ? 2 : 0,
    'version': version,
    'qualified': qualified,
    'ratingIsProvisional': !qualified,
    'hasRecord': true,
    'peakRating': qualified ? 1512 : null,
    'placements': {
      'completed': qualified ? 10 : 2,
      'required': 10,
      'remaining': qualified ? 0 : 8,
      'qualified': qualified,
    },
    'nextLeague': qualified
        ? {
            'league': 'DIAMOND',
            'rating': 1700,
            'remaining': 200,
            'progress': .2,
          }
        : null,
  },
  'activeMatch': active == null
      ? null
      : {
          'matchId': active,
          'seasonId': '2026-09',
          'status': 'QUESTION_TRANSITION',
          'recoveryState': 'RESUMABLE',
        },
  'seedPending': false,
  'capabilities': {'ratedAdmission': true, 'admissionPaused': false},
};
Map<String, dynamic> changeJson({
  String event = 'event',
  String kind = 'PROMOTION',
  String month = '2026-10',
}) => {
  'eventId': event,
  'seasonId': month,
  'userId': 'me',
  'before': 1434,
  'delta': 16,
  'after': 1450,
  'leagueBefore': 'GOLD',
  'leagueAfter': 'PLATINUM',
  'changeKind': kind,
  'seasonVersionAfter': 4,
  'qualification': {'completed': 10, 'required': 10},
};
Map<String, dynamic> boardEntry(String id, int position) => {
  'userId': id,
  'name': 'Bea Narayanaswamy Ananthakrishnan',
  'avatarUrl': null,
  'rating': 1500,
  'position': position,
  'league': 'PLATINUM',
};

class RankedTestAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class RankedTestRepo extends RankedRepository {
  String account = 'me';
  Map<String, dynamic> summary = rankedSummary();
  Completer<RankedSummary>? meGate;
  Completer<Map<String, dynamic>>? boardGate;
  bool cursorReset = false, failBoard = false, failMe = false;
  final cursors = <String?>[];
  @override
  String? get owner => account;
  @override
  Future<RankedSummary> me({String? seasonId}) async {
    if (meGate != null) return meGate!.future;
    if (failMe) throw const RankedFailure('UNAVAILABLE');
    return RankedSummary.fromJson(summary);
  }

  @override
  Future<Map<String, dynamic>> board({String? seasonId, String? cursor}) async {
    cursors.add(cursor);
    if (boardGate != null) return boardGate!.future;
    if (cursorReset && cursor != null) {
      throw const RankedFailure('CURSOR_RESET');
    }
    if (failBoard) throw const RankedFailure('UNAVAILABLE');
    return {
      'season': summary['season'],
      'entries': cursor == null
          ? [boardEntry('a', 1)]
          : [boardEntry('a', 2), boardEntry('b', 3)],
      'nextCursor': cursor == null ? 'signed-page' : null,
      'asOf': summary['asOf'],
      'pagination': 'LIVE_MAY_MOVE',
    };
  }

  @override
  Future<Map<String, dynamic>> seasons({String? before}) async => {
    'currentSeason': summary['season'],
    'entries': [
      {
        'season': {...rankedMap(summary['season']), 'status': 'FINALIZED'},
        'standing': summary['standing'],
        'resultsFinalizing': false,
      },
    ],
    'nextBefore': null,
  };
  @override
  Future<Map<String, dynamic>> history({int page = 1}) async => {
    'history': [],
    'pagination': {'totalPages': 0},
  };
}

class DeferredRankedTokenClient extends DioClient {
  final pending = Completer<String?>();
  DeferredRankedTokenClient()
    : super(baseUrl: 'https://never-connect.invalid/api/v1');
  @override
  Future<String?> getAccessToken() => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RankedTestAuth auth;
  late ESocket socket;
  late RankedTestRepo repo;
  final widgetReceipts = <String>{};
  Future<bool> consumeForWidget(String owner, RankedChange change) async =>
      widgetReceipts.add('$owner:${change.seasonId}:${change.eventId}');
  setUp(() {
    widgetReceipts.clear();
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(DioClient(baseUrl: 'https://ranked.invalid/api/v1'));
    auth = Get.put<RankedTestAuth>(RankedTestAuth());
    Get.put<AuthController>(auth);
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'me@example.invalid',
      firstName: 'Learner',
      isRegistrationComplete: true,
    );
    Get.put(AppearanceController());
    socket = ESocket();
    repo = RankedTestRepo();
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduce = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.find<AppearanceController>().mode.value = dark
        ? ThemeMode.dark
        : ThemeMode.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AptiquTheme.darkTheme : AptiquTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduce,
          ),
          child: RepaintBoundary(
            key: const ValueKey('ranked-capture'),
            child: child!,
          ),
        ),
        home: child,
      ),
    );
    await loadProductionFontFixtures(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // Decode exactly the resized providers used on screen before reviewing pixels.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate().toList()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_RANKED_PHASE4')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('ranked-capture')),
      );
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ranked_phase4/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  test(
    'optional sections preserve unknown/unavailable and separate XP from Elo',
    () {
      expect(RankedSection.parse(null), isNull);
      expect(RankedSection.parse({'status': 'DISABLED'})!.summary, isNull);
      expect(
        RankedSection.parse({'status': 'AVAILABLE', 'standing': {}})!.status,
        'UNAVAILABLE',
      );
      final user = UserModel.fromJson({
        'id': 'me',
        'totalXp': 100,
        'rankedLeague': {'status': 'AVAILABLE', ...rankedSummary()},
      });
      expect(user.totalXp, 100);
      expect(user.rankedLeague!.summary!.standing.rating, 1500);
      expect(user.copyWith(totalXp: 200).rankedLeague, user.rankedLeague);
      final d = HomeDashboardModel.fromJson({
        'performance': {'attempted': 0, 'correct': 0},
        'difficulty': [],
        'activity': [],
        'badges': [],
        'ranked': {'result': 'Win', 'correct': 8, 'questions': 10},
        'rankedLeague': {'status': 'AVAILABLE', ...rankedSummary()},
      });
      expect(d.ranked!.correct, 8);
      expect(d.rankedLeague!.summary!.standing.position, 123456);
    },
  );
  test(
    'unqualified rating and zero/negative deltas are not invented ranks or bonuses',
    () {
      final s = RankedSummary.fromJson(
        rankedSummary(qualified: false),
      ).standing;
      expect(s.position, isNull);
      expect(s.peakRating, isNull);
      expect(s.placementLabel, 'Placements 2 of 10');
      for (final delta in [-13, 0, 16]) {
        final c = RankedChange.fromJson({...changeJson(), 'delta': delta});
        expect(c.delta, delta);
      }
      expect(signedElo(-13), '−13');
      expect(signedElo(0), '0');
    },
  );
  test('UTC instants display the exclusive monthly boundary as IST', () {
    expect(
      istInstant(DateTime.parse('2026-10-31T18:30:00Z')),
      '1 Nov, 00:00 IST',
    );
    expect(seasonLabel('2028-02'), 'February 2028');
  });
  test(
    'persisted cosmetic receipts serialize duplicates and isolate account and season',
    () async {
      final change = RankedChange.fromJson(changeJson());
      final result = await Future.wait([
        RankedMotionReceipts.consume('me', change),
        RankedMotionReceipts.consume('me', change),
      ]);
      expect(result, [true, false]);
      expect(await RankedMotionReceipts.consume('other', change), isTrue);
      expect(
        await RankedMotionReceipts.consume(
          'me',
          RankedChange.fromJson(changeJson(month: '2026-11')),
        ),
        isTrue,
      );
    },
  );
  test(
    'queue waits for a real PAIRING decision and only server state widens search',
    () async {
      final c = Get.put(
        PvpLobbyController(socketService: socket, repository: repo),
      );
      await c.refreshRanked();
      await c.startMatchmaking();
      expect(socket.joins, 1);
      c.cancelMatchmaking();
      expect(c.isCancelling.value, isTrue);
      socket.emit('QUEUE_STATUS', {
        'status': 'PAIRING',
        'waitedMs': 75000,
        'searchExpanded': true,
      });
      expect(c.isPairing.value, isTrue);
      expect(c.isCancelling.value, isFalse);
      expect(c.secondsInQueue.value, 75);
      expect(c.searchExpanded.value, isTrue);
      c.cancelMatchmaking();
      expect(socket.leaves, 1);
      socket.emit('QUEUE_STATUS', {'status': 'LEFT_QUEUE'});
      expect(c.isInQueue.value, isTrue);
    },
  );
  test('cancel during the standing read cannot join late', () async {
    final c = Get.put(
      PvpLobbyController(socketService: socket, repository: repo),
    );
    await c.refreshRanked();
    repo.meGate = Completer<RankedSummary>();
    final start = c.startMatchmaking();
    c.cancelMatchmaking();
    repo.meGate!.complete(RankedSummary.fromJson(rankedSummary()));
    await start;
    expect(socket.joins, 0);
  });
  test(
    'active match blocks a new search and stale owner responses are discarded',
    () async {
      repo.summary = rankedSummary(active: 'old-month-match');
      final c = Get.put(
        PvpLobbyController(socketService: socket, repository: repo),
      );
      await c.refreshRanked();
      await c.startMatchmaking();
      expect(socket.joins, 0);
      expect(c.summary.value!.activeMatchId, 'old-month-match');
      repo.meGate = Completer<RankedSummary>();
      final read = c.fetchSummary();
      repo.account = 'other';
      auth.currentUser.value = const UserModel(
        id: 'other',
        email: 'other@example.invalid',
        firstName: 'Other',
      );
      repo.meGate!.complete(RankedSummary.fromJson(rankedSummary(version: 99)));
      await read;
      expect(c.summary.value, isNull);
      expect(c.matchHistory, isEmpty);
    },
  );
  test('arena uses committed own event and ignores older state versions', () {
    final c = Get.put(
      PvpArenaController(
        matchId: 'match',
        initialPlayersData: const [],
        totalQuestions: 10,
        socketService: socket,
      ),
    );
    socket.emit('QUESTION_STARTED', {
      'matchId': 'match',
      'stateVersion': 10,
      'questionIndex': 2,
      'durationSeconds': 12,
      'question': {'id': 'q', 'prompt': 'Question', 'options': []},
    });
    socket.emit('ANSWER_ACCEPTED', {
      'matchId': 'match',
      'stateVersion': 9,
      'questionIndex': 2,
      'selectedOptionId': 'a',
    });
    expect(c.hasSubmittedAnswer.value, isFalse);
    final completed = {
      'matchId': 'match',
      'stateVersion': 11,
      'ratingMode': 'RATED',
      'disposition': 'RATED',
      'winnerId': 'me',
      'isTie': false,
      'rating': changeJson(),
      'settledAt': '2026-10-20T12:00:00Z',
      'players': [
        {'userId': 'me', 'score': 8, 'xpAwarded': 100},
      ],
    };
    socket.emit('MATCH_COMPLETED', completed);
    socket.emit('MATCH_COMPLETED', {
      ...completed,
      'rating': {...changeJson(), 'delta': 999},
    });
    expect(c.ratingChange.value!.delta, 16);
    expect(c.xpAwarded.value, 100);
  });
  test('pending rated settlement does not manufacture a terminal result', () {
    final c = Get.put(
      PvpArenaController(
        matchId: 'match',
        initialPlayersData: const [],
        totalQuestions: 10,
        socketService: socket,
      ),
    );
    socket.emit('MATCH_COMPLETED', {
      'matchId': 'match',
      'ratingMode': 'RATED',
      'disposition': 'PENDING',
    });
    expect(c.isMatchCompleted.value, isFalse);
    expect(c.ratingChange.value, isNull);
    expect(c.connectionError.value, contains('Result updating'));
  });
  test(
    'repository honors Retry-After and resets cooldown on account change',
    () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['5'],
                  }),
                  data: {'code': 'RATE_LIMITED'},
                ),
              ),
            );
          },
        ),
      );
      final repository = RankedRepository(dio: dio);
      await expectLater(
        repository.me(),
        throwsA(isA<RankedFailure>().having((e) => e.retryAfter, 'wait', 5)),
      );
      await expectLater(
        repository.me(),
        throwsA(
          isA<RankedFailure>().having((e) => e.code, 'code', 'RETRY_LATER'),
        ),
      );
      expect(calls, 1);
      auth.currentUser.value = const UserModel(
        id: 'other',
        email: 'other@example.invalid',
        firstName: 'Other',
      );
      await expectLater(repository.me(), throwsA(isA<RankedFailure>()));
      expect(calls, 2);
    },
  );
  test(
    'an account change during token lookup cannot open an old-user socket',
    () async {
      final client = DeferredRankedTokenClient();
      Get.replace<DioClient>(client);
      final service = PvpSocketService();
      service.disconnect();
      final connecting = service.connect();
      auth.currentUser.value = const UserModel(
        id: 'other',
        email: 'other@example.invalid',
        firstName: 'Other',
      );
      client.pending.complete('old-account-token');
      await connecting;
      expect(service.isConnected, isFalse);
      expect(service.isAuthenticated, isFalse);
      service.disconnect();
    },
  );
  testWidgets('all six assets are bundled, typed and accessible', (
    tester,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final league in RankedLeague.values) {
      expect(manifest.listAssets(), contains(league.asset));
    }
    await show(
      tester,
      Scaffold(
        body: Wrap(
          children: [
            for (final league in RankedLeague.values)
              RankedBadge(league: league),
          ],
        ),
      ),
    );
    for (final league in RankedLeague.values) {
      expect(find.bySemanticsLabel('${league.label} league'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    for (final qualified in [true, false]) {
      for (final large in [false, true]) {
        testWidgets(
          'lobby ${dark ? 'dark' : 'light'} ${qualified ? 'qualified' : 'placements'} ${large ? 'large' : 'phone'}',
          (tester) async {
            repo.summary = rankedSummary(qualified: qualified);
            final c = Get.put(
              PvpLobbyController(socketService: socket, repository: repo),
            );
            await c.refreshRanked();
            await show(
              tester,
              const Scaffold(body: PvpLobbyView()),
              dark: dark,
              size: large ? const Size(320, 568) : const Size(390, 844),
              scale: large ? 2 : 1,
            );
            expect(find.text('Find match'), findsOneWidget);
            if (!large) {
              expect(
                tester.getRect(find.text('Find match')).bottom,
                lessThan(844),
              );
            }
            expect(
              find.text(qualified ? 'Platinum' : 'Unranked'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              'lobby-${qualified ? 'qualified' : 'placements'}-${dark ? 'dark' : 'light'}-${large ? 'large' : 'phone'}',
            );
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
  for (final dark in [false, true]) {
    testWidgets(
      'leaderboard paging deduplicates live movement and resets expired cursors ${dark ? 'dark' : 'light'}',
      (tester) async {
        await show(tester, RankedBrowserScreen(repository: repo), dark: dark);
        expect(find.text('#1'), findsOneWidget);
        await capture(tester, 'leaderboard-${dark ? 'dark' : 'light'}');
        await tester.ensureVisible(find.text('Load more'));
        await tester.tap(find.text('Load more'));
        await tester.pump();
        await tester.pump();
        expect(find.text('#3'), findsOneWidget);
        expect(repo.cursors, [null, 'signed-page']);
        expect(
          find.text('Bea Narayanaswamy Ananthakrishnan'),
          findsNWidgets(2),
        );
        await tester.tap(find.byTooltip('Refresh Ranked'));
        await tester.pump();
        await tester.pump();
        repo.cursorReset = true;
        await tester.ensureVisible(find.text('Load more'));
        await tester.tap(find.text('Load more'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Leaderboard changed'), findsOneWidget);
        expect(find.text('#1'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'season history shows frozen results ${dark ? 'dark' : 'light'}',
      (tester) async {
        await show(
          tester,
          RankedBrowserScreen(repository: repo, seasons: true),
          dark: dark,
        );
        expect(find.text('Global #123456'), findsOneWidget);
        expect(find.text('View season leaderboard'), findsOneWidget);
        await capture(tester, 'seasons-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'reduced-motion result shows true final badge without blocking return ${dark ? 'dark' : 'light'}',
      (tester) async {
        final change = RankedChange.fromJson(changeJson());
        await show(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  RankedResultView(
                    consume: consumeForWidget,
                    change: change,
                    owner: 'me',
                    settledAt: DateTime.now().toUtc(),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Return to Ranked'),
                  ),
                ],
              ),
            ),
          ),
          dark: dark,
          size: const Size(320, 568),
          scale: 2,
        );
        expect(find.text('Promoted to Platinum'), findsOneWidget);
        expect(find.text('+16 Elo'), findsOneWidget);
        await tester.ensureVisible(find.text('Return to Ranked'));
        await tester.tap(find.text('Return to Ranked'));
        await capture(tester, 'result-${dark ? 'dark' : 'light'}-large');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      'recovered committed arena result retains its admission season ${dark ? 'dark' : 'light'}',
      (tester) async {
        Get.put(
          PvpArenaController(
            matchId: 'match',
            initialPlayersData: const [],
            totalQuestions: 10,
            socketService: socket,
          ),
        );
        await show(
          tester,
          const PvpArenaScreen(
            matchId: 'match',
            initialPlayersData: [],
            totalQuestions: 10,
          ),
          dark: dark,
        );
        socket.emit('MATCH_RECONNECTED', {
          'matchId': 'match',
          'status': 'COMPLETED',
          'stateVersion': 50,
          'ratingMode': 'RATED',
          'disposition': 'RATED',
          'winnerId': 'me',
          'isTie': false,
          'rating': changeJson(month: '2026-09'),
          'settledAt': '2026-09-30T18:29:00Z',
          'players': [
            {'userId': 'me', 'score': 8, 'xpAwarded': 100},
            {'userId': 'other', 'score': 7, 'xpAwarded': 0},
          ],
        });
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate().toList()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump();
        expect(find.text('Victory'), findsOneWidget);
        expect(find.text('1434 → 1450 Elo'), findsOneWidget);
        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('Return to Ranked'), findsOneWidget);
        await capture(tester, 'arena-recorded-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('browser ignores an account-switched pending page', (
    tester,
  ) async {
    repo.boardGate = Completer<Map<String, dynamic>>();
    await show(tester, RankedBrowserScreen(repository: repo));
    repo.account = 'other';
    auth.currentUser.value = const UserModel(
      id: 'other',
      email: 'other@example.invalid',
      firstName: 'Other',
    );
    repo.boardGate!.complete({
      'season': repo.summary['season'],
      'entries': [boardEntry('private', 1)],
      'nextCursor': null,
      'asOf': repo.summary['asOf'],
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('#1'), findsNothing);
    expect(find.text('Sign in again to view Ranked.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final dark in [false, true]) {
    testWidgets('large leaderboard remains usable ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await show(
        tester,
        RankedBrowserScreen(repository: repo),
        dark: dark,
        size: const Size(320, 568),
        scale: 2,
      );
      await tester.scrollUntilVisible(
        find.text('Load more'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Load more'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture(tester, 'leaderboard-${dark ? 'dark' : 'light'}-large');
      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();
      expect(repo.cursors.length, 2);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'Home uses the existing Ranked section ${dark ? 'dark' : 'light'}',
      (tester) async {
        final data = HomeDashboardModel(
          performance: const HomePerformance(),
          difficulty: const {},
          activity: const [],
          badges: const [],
          rankedLeague: RankedSection(
            'AVAILABLE',
            RankedSummary.fromJson(rankedSummary()),
          ),
        );
        var opened = 0;
        await show(
          tester,
          Scaffold(
            body: HomeDashboardContent(
              data: data,
              onRefresh: () async {},
              onResume: (_) {},
              onTopics: () {},
              onRanked: () => opened++,
              onPractice: () {},
              onDaily: () {},
            ),
          ),
          dark: dark,
        );
        await tester.ensureVisible(find.text('Open Ranked'));
        await tester.pump();
        await capture(tester, 'home-${dark ? 'dark' : 'light'}');
        await tester.tap(find.text('Open Ranked'));
        expect(opened, 1);
        expect(find.text('Platinum'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'Profile keeps Appearance above seasonal standing ${dark ? 'dark' : 'light'}',
      (tester) async {
        auth.currentUser.value = auth.currentUser.value!.copyWith(
          rankedLeague: RankedSection(
            'AVAILABLE',
            RankedSummary.fromJson(rankedSummary()),
          ),
        );
        await show(tester, const ProfileScreen(autoFetch: false), dark: dark);
        expect(
          tester.getTopLeft(find.text('Appearance')).dy,
          lessThan(tester.getTopLeft(find.text('Ranked this season')).dy),
        );
        await capture(tester, 'profile-${dark ? 'dark' : 'light'}-identity');
        await tester.ensureVisible(find.text('Leaderboard'));
        await tester.pump();
        await capture(tester, 'profile-${dark ? 'dark' : 'light'}');
        expect(find.text('Platinum'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('promotion is finite and backgrounding settles the final badge', (
    tester,
  ) async {
    final now = DateTime.now().toUtc(),
        ist = DateTime.now().toUtc().add(const Duration(minutes: 330));
    final month = '${ist.year}-${ist.month.toString().padLeft(2, '0')}';
    await show(
      tester,
      Scaffold(
        body: RankedResultView(
          consume: consumeForWidget,
          change: RankedChange.fromJson(changeJson(month: month)),
          owner: 'me',
          settledAt: now,
        ),
      ),
      reduce: false,
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (tester.widget(find.byType(Opacity).first) as Opacity).opacity,
      lessThan(1),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect((tester.widget(find.byType(Opacity).first) as Opacity).opacity, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(widgetReceipts, contains('me:$month:event'));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('platform reduceMotion shows a static final badge', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(
      tester,
      Scaffold(
        body: RankedResultView(
          consume: consumeForWidget,
          change: RankedChange.fromJson(changeJson()),
          owner: 'me',
          settledAt: DateTime.now().toUtc(),
        ),
      ),
      reduce: false,
    );
    expect((tester.widget(find.byType(Opacity).first) as Opacity).opacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'queue-region rebuild preserves the independently keyed rules state',
    (tester) async {
      final c = Get.put(
        PvpLobbyController(socketService: socket, repository: repo),
      );
      await c.refreshRanked();
      await show(tester, const Scaffold(body: PvpLobbyView()));
      await tester.tap(find.text('Match rules'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Find match'));
      await tester.pump();
      await tester.pump();
      socket.emit('QUEUE_STATUS', {'status': 'PAIRING'});
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Preparing match…'), findsOneWidget);
      Get.delete<PvpLobbyController>();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
