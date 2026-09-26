import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';

void main() {
  testWidgets('ConstellationRoadmapView renders minimal subjects bar, topics, and dock on tap',
      (WidgetTester tester) async {
    final mockLearningMap = SubjectLearningMapModel(
      roadmapId: 'general-aptitude',
      roadmapName: 'General Aptitude',
      roadmapCourse: 'general',
      subjectId: 'subj_quant_aptitude',
      subjectName: 'Quantitative Aptitude',
      subjectDescription: 'Numerical concepts, arithmetic, algebra, geometry',
      totalTopics: 3,
      completedTopics: 1,
      activeStepId: 'ga-qa-02',
      topics: [
        LearningMapTopicItemModel(
          roadmapStepId: 'ga-qa-01',
          sequence: 1,
          topicId: 'qa-ratios',
          topicName: 'Basic Ratios',
          topicSlug: 'math_ratios_101',
          description: 'Fully mastered foundational proportions.',
          importance: 'high',
          teachingMinutes: 30,
          teachingDepth: 3,
          state: 'COMPLETED',
          scriptAvailable: true,
          scriptSlug: 'math_ratios_101',
          scriptTitle: 'Introduction to Ratios',
          totalSubtopics: 1,
          completedSubtopics: 1,
          subtopics: [
            SubtopicItemModel(
              id: 'st_01',
              title: 'Introduction to Ratios',
              sequence: 1,
              isCompleted: true,
              isLocked: false,
              canReplay: true,
              scriptSlug: 'math_ratios_101',
            ),
          ],
        ),
        LearningMapTopicItemModel(
          roadmapStepId: 'ga-qa-02',
          sequence: 2,
          topicId: 'qa-percentages',
          topicName: 'Percentages & Discounts',
          topicSlug: 'percentages',
          description: 'Calculations with markups, margins and tax adjustments.',
          importance: 'high',
          teachingMinutes: 30,
          teachingDepth: 3,
          state: 'AVAILABLE',
          scriptAvailable: true,
          scriptSlug: 'math_percentages_101',
          scriptTitle: 'Percentages Drill',
          totalSubtopics: 1,
          completedSubtopics: 0,
          subtopics: [
            SubtopicItemModel(
              id: 'st_02',
              title: 'Percentages Drill',
              sequence: 1,
              isCompleted: false,
              isLocked: false,
              canReplay: false,
              scriptSlug: 'math_percentages_101',
            ),
          ],
        ),
        LearningMapTopicItemModel(
          roadmapStepId: 'ga-qa-03',
          sequence: 3,
          topicId: 'qa-profit-loss',
          topicName: 'Profit & Loss Formulas',
          topicSlug: 'profit-loss',
          description: 'Calculations with markups, margins and tax adjustments.',
          importance: 'medium',
          teachingMinutes: 30,
          teachingDepth: 3,
          state: 'COMING_SOON',
          scriptAvailable: false,
        ),
      ],
    );

    LearningMapTopicItemModel? tappedTopic;
    bool fullscreenToggled = false;

    Get.put(DioClient());
    Get.put(HomeController());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConstellationRoadmapView(
            learningMap: mockLearningMap,
            subjects: [
              RoadmapSubjectSummary(
                id: 'subj_quant_aptitude',
                slug: 'quantitative-aptitude',
                name: 'Quantitative Aptitude',
                sequence: 1,
              ),
            ],
            selectedSubjectId: 'subj_quant_aptitude',
            isFullScreen: false,
            onToggleFullScreen: () => fullscreenToggled = true,
            onSelectSubject: (_) {},
            onTopicTap: (topic) => tappedTopic = topic,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // 1. Verify Fixed Minimal Subjects Bar
    expect(find.text('SUBJECTS'), findsOneWidget);
    expect(find.text('Quantitative Aptitude'), findsOneWidget);

    // 2. Verify Topics are rendered
    expect(find.text('Basic Ratios'), findsOneWidget);
    expect(find.text('Percentages & Discounts'), findsOneWidget);
    expect(find.text('CURRENT TOPIC'), findsOneWidget);

    // 3. Verify Docked Card is NOT visible on initial entry
    expect(find.text('TOPIC 02'), findsNothing);

    // 4. Tap the topic to inspect it
    await tester.tap(find.text('Percentages & Discounts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 5. Verify Docked Card is NOW visible with subtopic and Start action
    expect(find.text('TOPIC 02'), findsOneWidget);
    expect(find.text('Percentages Drill'), findsAtLeastNWidgets(1));
    expect(find.text('Start'), findsOneWidget);

    // 6. Tap completed topic to inspect Replay Topic button
    await tester.tap(find.text('Basic Ratios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TOPIC 01'), findsOneWidget);
    expect(find.text('Replay Topic'), findsOneWidget);
    await tester.tap(find.text('Replay Topic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tappedTopic?.roadmapStepId, 'ga-qa-01');

    // 7. Verify Fullscreen Toggle button
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    expect(fullscreenToggled, isTrue);
  });
}
