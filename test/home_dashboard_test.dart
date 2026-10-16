import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/home/models/home_dashboard_model.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/home/presentation/widgets/achievement_browser.dart';
import 'practice_catalog_test.dart' show TestFontManifest;

HomeDashboardModel fixture({bool populated = false}) => HomeDashboardModel(
  today: '2026-10-13',
  performance: populated
      ? const HomePerformance(
          attempted: 40,
          correct: 30,
          accuracy: .75,
          averageSolveTimeMs: 12500,
        )
      : const HomePerformance(),
  difficulty: populated
      ? {
          'EASY': const HomePerformance(
            attempted: 40,
            correct: 30,
            accuracy: .75,
            averageSolveTimeMs: 12500,
          ),
        }
      : {},
  activity: List.generate(
    56,
    (i) => HomeActivityDay(
      DateTime(2026, 8, 19 + i).toIso8601String().substring(0, 10),
      populated && i % 3 == 0 ? 8 : 0,
      populated && i % 3 == 0 ? 6 : 0,
      dailyChallengeCompleted: populated && i == 55,
    ),
  ),
  badges: [
    HomeBadge(
      'Sample achievement',
      'Submit your first answer',
      populated ? 1 : 0,
      1,
      populated,
    ),
    HomeBadge(
      'Sample challenge milestone',
      'Get 25 answers correct',
      populated ? 25 : 0,
      25,
      populated,
    ),
  ],
  resume: populated
      ? const HomeResume(
          'step',
          'Place Value, Face Value and Number Formation',
          'Number System',
        )
      : null,
  ranked: populated ? const HomeRanked('Win', 8, 10) : null,
);
void main() {
  setUp(() {
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
  });
  Future<void> show(
    WidgetTester tester, {
    HomeDashboardModel? data,
    double width = 390,
    double scale = 1,
    bool loading = false,
    String? error,
    VoidCallback? topics,
    void Function(HomeResume)? resume,
    VoidCallback? daily,
    Future<void> Function()? refresh,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AptiquTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: HomeDashboardContent(
              data: data,
              user: const UserModel(
                id: 'test',
                email: 'test@example.com',
                firstName: 'A very long learner name',
                totalXp: 125,
                progress: .5,
                xpIntoCurrentLevel: 10,
              ),
              loading: loading,
              error: error,
              onRefresh: refresh ?? () async {},
              onResume: resume ?? (_) {},
              onTopics: topics ?? () {},
              onRanked: () {},
              onPractice: () {},
              onDaily: daily ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts();
      final bytes = ByteData.sublistView(
        File('test/fonts/Outfit.ttf').readAsBytesSync(),
      );
      await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
      var directory = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8; i++) {
        final icons = File(
          '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync()) {
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync())),
              ))
              .load();
          break;
        }
        directory = directory.parent;
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('new learner has a start action and no invented accuracy', (
    tester,
  ) async {
    var opened = false;
    await show(tester, data: fixture(), topics: () => opened = true);
    expect(find.text('Explore topics'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Your progress'), findsNothing);
    expect(find.text('125 XP'), findsNothing);
    expect(find.text('Current Streak : 0 Days'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Daily Challenge')).dy,
      lessThan(tester.getTopLeft(find.text('Your next discovery')).dy),
    );
    expect(find.text('Continue learning'), findsNothing);
    await tester.tap(find.text('Explore topics'));
    expect(opened, true);
    await tester.scrollUntilVisible(
      find.text('Build your first results'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resume and muted Daily Challenge use the existing actions', (
    tester,
  ) async {
    String? step;
    var openedDaily = false;
    await show(
      tester,
      data: fixture(populated: true),
      resume: (r) => step = r.stepId,
      daily: () => openedDaily = true,
    );
    await tester.tap(find.text('Continue learning'));
    expect(step, 'step');
    await tester.ensureVisible(find.text('Daily Challenge'));
    await tester.tap(find.text('Daily Challenge'));
    await tester.pumpAndSettle();
    expect(openedDaily, true);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home-populated.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('small phone and large text support all sections and day detail', (
    tester,
  ) async {
    await show(tester, data: fixture(populated: true), width: 320, scale: 1.5);
    await tester.scrollUntilVisible(
      find.byType(ActivityCalendar),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final day = fixture(populated: true).activity[50];
    await tester.scrollUntilVisible(
      find
          .byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label ==
                    '${day.date}: ${day.attempted} submissions, ${day.correct} correct',
          )
          .hitTestable(),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                '${day.date}: ${day.attempted} submissions, ${day.correct} correct',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Oct 2026'), findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).width, 320);
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/home-day-details.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View difficulty details').hitTestable(),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View difficulty details'));
    await tester.pumpAndSettle();
    expect(find.text('By difficulty'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading keeps profile visible and errors have retry', (
    tester,
  ) async {
    await show(tester, loading: true);
    expect(find.text('125 XP'), findsNothing);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.byType(AppLoader), findsOneWidget);
    var retried = false;
    await show(
      tester,
      error: 'Could not refresh',
      refresh: () async => retried = true,
    );
    await tester.scrollUntilVisible(find.text('Retry'), 200);
    await tester.tap(find.text('Retry'));
    expect(retried, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'year window starts at current month and scrolls to both year boundaries',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: Scaffold(
            body: YearActivityCalendar(
              days: fixture().activity,
              today: '2026-10-13',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      final windowHeight = tester
          .getSize(find.byType(YearActivityCalendar))
          .height;
      expect(windowHeight, lessThan(360));
      expect(
        tester.getBottomLeft(find.text('Today')).dy,
        lessThanOrEqualTo(
          tester.getBottomLeft(find.byType(YearActivityCalendar)).dy,
        ),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('January 2026'), findsOneWidget);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('December 2026'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('calendar labels months and marks only successful Daily Challenges', (
    tester,
  ) async {
    await show(tester, data: fixture(populated: true));
    await tester.scrollUntilVisible(
      find.byType(ActivityCalendar),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('September 2026').hitTestable(), findsNothing);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Mo').hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ActivityCalendar),
        matching: find.byIcon(Icons.local_fire_department_rounded),
      ),
      findsNWidgets(2),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                '2026-10-13: 8 submissions, 6 correct, Daily Challenge completed',
      ),
      findsNothing,
    );
    // This fixture has a successful challenge on a zero-answer day: the marker
    // comes from challenge completion rather than heatmap colour.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                '2026-10-13: 0 submissions, 0 correct, Daily Challenge completed',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'six-week month fits at large text and keeps inter-month spacing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Padding(
                padding: const EdgeInsets.all(38),
                child: YearActivityCalendar(
                  days: const [],
                  today: '2026-05-13',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('31').hitTestable(), findsOneWidget);
      expect(find.text('Today').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(YearActivityCalendar)).dy -
            tester.getBottomLeft(find.text('Today')).dy,
        lessThan(16),
      );
      expect(find.text('June 2026').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date sheet spans a wide screen instead of the Material width cap',
    (tester) async {
      tester.view.physicalSize = const Size(900, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: const Scaffold(
            body: ActivityCalendar(days: [HomeActivityDay('2026-10-14', 9, 8)]),
          ),
        ),
      );
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomSheet)).width, 900);
      expect(tester.getTopLeft(find.text('Wed, 14 Oct 2026')).dx, 24);
      expect(find.text('9 answers submitted\n8 correct'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'achievement browser loads server pages and retries without duplicate entries',
    (tester) async {
      var calls = 0;
      var fail = true;
      Map<String, dynamic> item(String id) => {
        'id': id,
        'title': 'Server milestone $id',
        'description': 'Server description',
        'progress': 2,
        'target': 5,
        'unlocked': false,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: Scaffold(
            body: AchievementBrowser(
              badgeBuilder: (b) => Text(b.title),
              fetchPage: (page) async {
                calls++;
                if (page == 2 && fail) {
                  fail = false;
                  throw StateError('Offline');
                }
                return {
                  'items': page == 1 ? [item('A')] : [item('A'), item('B')],
                  'total': 2,
                  'hasMore': page == 1,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Server milestone A'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Server milestone A'), findsOneWidget);
      expect(find.text('Server milestone B'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
