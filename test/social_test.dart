import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/friends_screen.dart';
import 'package:aptiqu/features/social/social_overlay.dart';
import 'practice_catalog_test.dart' show TestFontManifest;

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
    if (options.path.contains('/profiles/')) {
      data = {
        'id': id,
        'name': 'Bea Learner',
        'level': 2,
        'avatarUrl': null,
        'totalXp': 20,
        'highestStreak': 3,
        'currentStreak': 0,
        'coins': 0,
        'online': false,
        'relation': relation,
        'performance': {
          'attempted': 0,
          'correct': 0,
          'accuracy': null,
          'averageSolveTimeMs': null,
        },
        'badges': [],
        'activity': [],
        'difficulty': [],
        'ranked': null,
      };
    }
    if (options.method == 'POST') {
      lastBody = Map<String, dynamic>.from(options.data);
      if (options.path.endsWith('/invite')) {
        invites++;
        relation = 'INVITED';
      }
    }
    if (options.queryParameters['q'] == 'slow') await slowSearch?.future;
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
    GoogleFonts.config.allowRuntimeFetching = false;
    font_test.assetManifest = TestFontManifest();
    final bytes = File('test/fonts/Outfit.ttf').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          return key.startsWith('test/fonts/')
              ? ByteData.sublistView(bytes)
              : null;
        });
    final client = DioClient(baseUrl: 'http://fixture.invalid/api/v1');
    adapter = SocialAdapter();
    client.dio.httpClientAdapter = adapter;
    Get.put(client);
    Get.put<SocialController>(FakeSocial());
  });
  tearDown(() => Get.reset());
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
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bea@gmail.com');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(adapter.calls.last.queryParameters['q'], 'bea@gmail.com');
      await tester.tap(find.text('Send friend request'));
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
      expect(find.text('Page 1'), findsOneWidget);
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
      expect(find.text('Send friend request'), findsOneWidget);
      await tester.tap(find.text('Bea Learner'));
      await tester.pumpAndSettle();
      expect(find.text('Add friend'), findsOneWidget);
      expect(find.text('No accuracy results yet'), findsOneWidget);
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();
      expect(adapter.invites, 1);
      expect(find.text('Invited'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Invited'))
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
      expect(find.text('Aptitude duel'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
