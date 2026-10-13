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
import 'practice_catalog_test.dart' show TestFontManifest;

HomeDashboardModel fixture({bool populated = false}) => HomeDashboardModel(
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
    ),
  ),
  badges: [
    HomeBadge(
      'First step',
      'Submit your first answer',
      populated ? 1 : 0,
      1,
      populated,
    ),
    HomeBadge(
      'Finding your stride',
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
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
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
    final day = fixture(populated: true).activity[28];
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label ==
                '${day.date}: ${day.attempted} submissions, ${day.correct} correct',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(day.date), findsOneWidget);
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
    expect(find.text('125 XP'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
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
}
