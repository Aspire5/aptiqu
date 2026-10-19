import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'support/presentation_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/friends_screen.dart';
import 'package:aptiqu/features/social/social_overlay.dart';
import 'package:aptiqu/features/social/friend_requests_screen.dart';
import 'package:aptiqu/features/social/widgets/social_widgets.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/social/widgets/learner_activity_window.dart';
import 'package:aptiqu/features/social/widgets/friend_request_card.dart';
import 'package:aptiqu/features/home/presentation/widgets/bottom_nav_zone.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'home_navigation_test.dart' show LocalHome, LocalAuth;

class FakeSocial extends SocialController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> syncInbox() async {}
}

class SocialAdapter implements HttpClientAdapter {
  String relation = 'NONE';
  int invites = 0;
  List<Map<String, dynamic>> requests = [];
  bool failResponse = false;
  bool populatedProfile = false;
  Map<String, dynamic>? lastBody;
  final calls = <RequestOptions>[];
  Completer<void>? slowSearch;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final id = '00000000-0000-4000-8000-000000000002';
    Object? data = {};
    if (options.path.endsWith('/friends')) {
      data = {
        'items': [
          {
            'id': id,
            'name': 'My Friend',
            'level': 2,
            'relation': 'FRIEND',
            'online': false,
            'friendsSince': '2026-10-01T00:00:00Z',
          },
        ],
        'nextCursor': options.queryParameters['cursor'] == null ? id : null,
      };
    }
    if (options.path.endsWith('/search')) {
      data = {
        'items': [
          {
            'id': id,
            'name': 'Bea Learner',
            'level': 2,
            'avatarUrl': null,
            'relation': relation,
          },
        ],
        'nextCursor': null,
      };
    }
    if (options.path.endsWith('/inbox')) {
      data = {'friends': requests, 'duels': [], 'activeDuelId': null};
    }
    if (options.path.contains('/profiles/')) {
      data = {
        'id': id,
        'name': 'Bea Learner',
        'level': 2,
        'avatarUrl': null,
        'today': '2026-10-17',
        'friendshipId': 'friend',
        'friendshipVersion': '2026-10-14T00:00:00.000Z',
        'totalXp': 20,
        'highestStreak': 3,
        'currentStreak': 0,
        'coins': 0,
        'online': false,
        'relation': relation,
        'performance': {
          'attempted': populatedProfile ? 9 : 0,
          'correct': populatedProfile ? 8 : 0,
          'accuracy': populatedProfile ? 8 / 9 : null,
          'averageSolveTimeMs': populatedProfile ? 1400 : null,
        },
        'badges': [
          if (populatedProfile)
            {
              'title': 'A steady start',
              'description': 'Build a learning habit, one day at a time.',
              'unlocked': true,
              'progress': 3,
              'target': 3,
            },
        ],
        'activity': [],
        'difficulty': [
          if (populatedProfile)
            for (final difficulty in ['EASY', 'MEDIUM', 'HARD'])
              {
                'difficulty': difficulty,
                'attempted': 3,
                'correct': difficulty == 'HARD' ? 2 : 3,
              },
        ],
        'ranked': populatedProfile ? {'result': 'Win', 'correct': 4} : null,
      };
    }
    if (options.path.endsWith('/activity')) {
      final month = options.queryParameters['month'] as String;
      final date = DateTime.parse('$month-01');
      data = {
        'activity': [
          for (var d = 1; d <= DateTime(date.year, date.month + 1, 0).day; d++)
            {
              'date': '$month-${d.toString().padLeft(2, '0')}',
              'attempted': 0,
              'correct': 0,
            },
        ],
      };
    }
    if (options.method == 'POST') {
      lastBody = Map<String, dynamic>.from(options.data);
      if (options.path.endsWith('/respond')) {
        if (failResponse) throw DioException(requestOptions: options);
        requests.clear();
        relation = lastBody!['accept'] == true ? 'FRIEND' : 'NONE';
      }
      if (options.path.endsWith('/invite')) {
        invites++;
        relation = 'INVITED';
      }
    }
    if (options.queryParameters['q'] == 'slow') {
      await slowSearch?.future;
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class ManualStopwatch extends Stopwatch {
  int milliseconds = 0;
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  void start() {}
  @override
  void stop() {}
}

void main() {
  late SocialAdapter adapter;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(AppearanceController()).mode.value = ThemeMode.dark;
    final client = DioClient(baseUrl: 'http://fixture.invalid/api/v1');
    adapter = SocialAdapter();
    client.dio.httpClientAdapter = adapter;
    Get.put(client);
    Get.put<SocialController>(FakeSocial());
  });
  tearDown(() => Get.reset());

  Map<String, dynamic> invitation() => {
    'id': 'friend',
    'version': '2026-10-14T00:00:00.000Z',
    'sender': {
      'id': '00000000-0000-4000-8000-000000000002',
      'name': 'Bea Learner',
      'level': 2,
      'avatarUrl': null,
    },
  };

  Future<void> phone(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AptiquTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await loadProductionFontFixtures(tester);
    await tester.pumpAndSettle();
    await loadProductionFontFixtures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('compact search and focused field render at phone width', (
    tester,
  ) async {
    await phone(tester, const FriendsScreen());
    await tester.enterText(find.byType(TextField), 'bea');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
      'Search learners',
    );
    expect(tester.getSize(find.byType(LearnerTile)).height, lessThan(110));
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/friends-search.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inbox lists learners; profile rejection updates the list and badge',
    (tester) async {
      adapter.requests = [invitation()];
      adapter.relation = 'INCOMING';
      final social = Get.find<SocialController>();
      social.friendInvites.assignAll(adapter.requests);
      await phone(tester, const FriendsScreen());
      expect(find.byType(Badge), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('friend-requests-inbox')));
      await tester.pumpAndSettle();
      expect(find.byType(FriendRequestsScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('1 pending'), findsOneWidget);
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('accept-request'))).width,
        tester.getSize(find.byKey(const ValueKey('reject-request'))).width,
      );
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/friend-requests.png'),
      );
      adapter.populatedProfile = true;
      await tester.tap(find.text('Bea Learner'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('accept-request')), findsOneWidget);
      expect(find.byKey(const ValueKey('reject-request')), findsOneWidget);
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/learner-profile.png'),
      );
      await tester.tap(find.byKey(const ValueKey('reject-request')));
      await tester.pumpAndSettle();
      expect(adapter.lastBody, {
        'accept': false,
        'version': '2026-10-14T00:00:00.000Z',
      });
      expect(social.friendInvites, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('You’re all caught up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'request failure stays actionable, then accept removes the tile',
    (tester) async {
      adapter.requests = [invitation()];
      adapter.failResponse = true;
      await phone(tester, const FriendRequestsScreen(), width: 320, scale: 1.5);
      await tester.tap(find.byKey(const ValueKey('accept-request')));
      await tester.pumpAndSettle();
      expect(find.byType(FriendRequestCard), findsOneWidget);
      expect(Get.find<SocialController>().friendInvites, hasLength(1));
      adapter.failResponse = false;
      await tester.tap(find.byKey(const ValueKey('accept-request')));
      await tester.pumpAndSettle();
      expect(adapter.lastBody!['accept'], true);
      expect(find.byType(FriendRequestCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile fits large text and activity fetches visited months once',
    (tester) async {
      adapter.populatedProfile = true;
      await phone(
        tester,
        const FriendProfileScreen(id: 'learner'),
        width: 320,
        scale: 1.5,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/learner-profile-large.png'),
      );
      await tester.scrollUntilVisible(
        find.byType(LearnerActivityWindow),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      final calendar = find.descendant(
        of: find.byType(YearActivityCalendar),
        matching: find.byType(ListView),
      );
      await tester.drag(calendar, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(
        adapter.calls.where(
          (r) =>
              r.path.endsWith('/activity') &&
              r.queryParameters['month'] == '2026-09',
        ),
        hasLength(1),
      );
      await tester.drag(calendar, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.drag(calendar, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(
        adapter.calls.where(
          (r) =>
              r.path.endsWith('/activity') &&
              r.queryParameters['month'] == '2026-09',
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new learner profile has honest empty states and balanced request controls',
    (tester) async {
      adapter.relation = 'INCOMING';
      await phone(tester, const FriendProfileScreen(id: 'learner'));
      expect(find.text('N/A'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.text('No accuracy results yet'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('accept-request'))).width,
        tester.getSize(find.byKey(const ValueKey('reject-request'))).width,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/learner-profile-empty.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('friends navigation dot reacts to pending requests', (
    tester,
  ) async {
    Get.put<AuthController>(LocalAuth());
    Get.put<HomeController>(LocalHome());
    await phone(tester, const Scaffold(body: BottomNavZone(height: 84)));
    final social = Get.find<SocialController>();
    expect(
      find.bySemanticsLabel('Friends, pending friend requests'),
      findsNothing,
    );
    social.friendInvites.assignAll([invitation()]);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Friends, pending friend requests'),
      findsOneWidget,
    );
    social.friendInvites.clear();
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Friends, pending friend requests'),
      findsNothing,
    );
  });
  testWidgets(
    'inline request, pagination reset, presence and stale search protection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AptiquTheme.darkTheme, home: const FriendsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Friends since 1 Oct 2026'), findsOneWidget);
      Get.find<SocialController>().events.add({
        'event': 'PRESENCE',
        'items': [
          {'id': '00000000-0000-4000-8000-000000000002', 'online': true},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Level 2 · Online'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('next-friends-page')));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bea@gmail.com');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(adapter.calls.last.queryParameters['q'], 'bea@gmail.com');
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();
      expect(adapter.invites, 1);
      expect(find.text('Request sent'), findsOneWidget);
      adapter.slowSearch = Completer<void>();
      await tester.enterText(find.byType(TextField), 'slow');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(adapter.calls.last.path.endsWith('/friends'), true);
      expect(adapter.calls.last.queryParameters.containsKey('cursor'), false);
      expect(find.text('1'), findsOneWidget);
      adapter.slowSearch!.complete();
      await tester.pumpAndSettle();
      expect(find.text('My Friend'), findsOneWidget);
      expect(find.text('Bea Learner'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search, inspect profile and invite changes the button to Invited',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AptiquTheme.darkTheme, home: const FriendsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bea');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text('Add Friend'), findsOneWidget);
      await tester.tap(find.text('Bea Learner'));
      await tester.pumpAndSettle();
      expect(find.text('Add Friend'), findsOneWidget);
      expect(find.text('No accuracy results yet'), findsOneWidget);
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();
      expect(adapter.invites, 1);
      expect(find.text('Request sent'), findsOneWidget);
      expect(
        tester
            .widget<SocialButton>(
              find.widgetWithText(SocialButton, 'Request sent'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('friend invitation response sends the server version', (
    tester,
  ) async {
    const version = '2026-10-14T00:00:00.000Z';
    await tester.pumpWidget(
      MaterialApp(
        theme: AptiquTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const SocialInvitationDialog(
                  invitation: {
                    'id': 'friend',
                    'version': version,
                    'sender': {'name': 'Bea'},
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(adapter.lastBody, {'accept': true, 'version': version});
    expect(find.text('Friend invitation'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'duel invitation has both options and closes when its 60-second budget expires',
    (tester) async {
      final clock = ManualStopwatch();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => SocialInvitationDialog(
                      duel: true,
                      stopwatch: clock,
                      invitation: {
                        'id': 'duel',
                        'requester': {'name': 'Bea'},
                        'remainingMs': 60000,
                        'smartPicks': true,
                        'timerEnabled': false,
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text('60 seconds to respond'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      clock.milliseconds = 61000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(result, false);
      expect(find.text('Duel invitation'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
