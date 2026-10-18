import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'practice_catalog_test.dart' show TestFontManifest;
import 'learning_progress_test.dart' show QuietHome, learningMap, topic;

void main() {
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
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
    Get.put<HomeController>(QuietHome());
  });
  tearDown(() => Get.reset());
  testWidgets(
    'last played final topic has the single play marker and visible completion at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      LearningMapTopicItemModel finalTopic(bool complete) =>
          LearningMapTopicItemModel(
            roadmapStepId: 'last',
            sequence: 2,
            topicId: 'ages',
            topicName: 'Problems on Ages',
            topicSlug: 'ages',
            importance: 'medium',
            teachingMinutes: 15,
            teachingDepth: 2,
            state: complete ? 'COMPLETED' : 'IN_PROGRESS',
            scriptAvailable: true,
            totalSubtopics: 2,
            completedSubtopics: complete ? 2 : 1,
            subtopics: [
              SubtopicItemModel(
                id: 'past',
                scriptSlug: 'past',
                title: 'Past and Future Ages',
                sequence: 1,
                isCompleted: true,
                isLocked: false,
              ),
              SubtopicItemModel(
                id: 'ratios',
                scriptSlug: 'ratios',
                title: 'Comparing Ages with Ratios',
                sequence: 2,
                isCompleted: complete,
                isLocked: false,
              ),
            ],
          );
      Widget screen(bool completed) => MaterialApp(
        theme: AptiquTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: ConstellationRoadmapView(
              learningMap: learningMap(
                'math',
                topics: [topic('Number System'), finalTopic(completed)],
                active: 'last',
              ),
              subjects: [
                RoadmapSubjectSummary(
                  id: 'math',
                  slug: 'math',
                  name: 'Quantitative Aptitude',
                  sequence: 1,
                ),
              ],
              selectedSubjectId: 'math',
              onSelectSubject: (_) {},
              onTopicTap: (_) {},
              onRefresh: () async {},
              onToggleFullScreen: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(false));
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('0/2 topics'), findsOneWidget);
      expect(find.text('1/2 completed'), findsOneWidget);
      await tester.tap(find.byTooltip('Focus Active Level'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // A refreshed map updates the open dock, including every subtopic status.
      await tester.pumpWidget(screen(true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1/2 topics'), findsOneWidget);
      expect(find.text('COMPLETED · REPLAY'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
      expect(find.text('Replay'), findsNWidgets(2));
      expect(find.text('Replay Topic'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/topics-completed-phone.png'),
      );
    },
  );
}
