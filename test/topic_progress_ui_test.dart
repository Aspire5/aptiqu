import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'support/presentation_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'package:aptiqu/features/home/presentation/widgets/topic_icon.dart';
import 'learning_progress_test.dart' show QuietHome, learningMap, topic;

void main() {
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    Get.put(AppearanceController()).mode.value = ThemeMode.dark;
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
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
      );
      await tester.pumpWidget(screen(false));
      await loadProductionFontFixtures(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is TopicIcon && w.type == TopicIconType.currentTopic,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('0/2 topics'), findsOneWidget);
      expect(find.textContaining('1 of 2 subtopics completed'), findsOneWidget);
      await tester.tap(find.text('Problems on Ages'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // A refreshed map updates the open dock, including every subtopic status.
      await tester.pumpWidget(screen(true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('1/2 topics'), findsOneWidget);
      expect(find.textContaining('Completed · Replay'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
      expect(find.text('Replay'), findsNWidgets(3));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('Whole topic'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/topics-completed-phone.png'),
      );
    },
  );
}
