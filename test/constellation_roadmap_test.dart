import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';

void main() {
  testWidgets('ConstellationRoadmapView renders minimal subjects bar, nodes, and dock on tap',
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
    expect(find.text('1/9'), findsOneWidget); // 1 completed of 3 topics * 3 stars = 9 stars

    // 2. Verify Nodes are rendered
    expect(find.text('Basic Ratios'), findsOneWidget);
    expect(find.text('Percentages & Discounts'), findsOneWidget);
    expect(find.text('ACTIVE OBJECTIVE • +120 XP'), findsOneWidget);

    // 3. Verify Docked Card is NOT visible on initial entry
    expect(find.text('Begin Node'), findsNothing);

    // 4. Tap the node to inspect it
    await tester.tap(find.text('Percentages & Discounts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 5. Verify Docked Card is NOW visible
    expect(find.text('NODE 02'), findsOneWidget);
    expect(find.text('Begin Node'), findsOneWidget);

    // 6. Tap Begin Node button in dock
    await tester.tap(find.text('Begin Node'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tappedTopic?.roadmapStepId, 'ga-qa-02');

    // 7. Verify Fullscreen Toggle button
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    expect(fullscreenToggled, isTrue);
  });
}
