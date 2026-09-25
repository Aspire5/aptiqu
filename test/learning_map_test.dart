import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/widgets/learning_map_topic_card.dart';
import 'package:aptiqu/features/lesson/models/lesson_session_model.dart';

void main() {
  group('Roadmap Model & Learning Map Tests', () {
    test('SubjectLearningMapModel parses JSON correctly', () {
      final json = {
        'roadmap': {
          'id': 'general-aptitude',
          'slug': 'general-aptitude',
          'name': 'General Aptitude',
          'course': 'general',
        },
        'subject': {
          'id': 'quantitative-aptitude',
          'slug': 'quantitative-aptitude',
          'name': 'Quantitative Aptitude',
          'description': 'Numerical and problem solving',
        },
        'topics': [
          {
            'roadmapStepId': 'ga-qa-01',
            'sequence': 1,
            'topicId': 'qa-foundations',
            'topicName': 'Mathematical Foundations',
            'topicSlug': 'mathematical-foundations',
            'description': 'Build basic calculation fluency',
            'importance': 'very_important',
            'teachingMinutes': 180,
            'teachingDepth': 4,
            'subtopicId': null,
            'subtopicName': null,
            'state': 'COMING_SOON',
            'scriptAvailable': false,
          },
          {
            'roadmapStepId': 'ga-qa-04',
            'sequence': 4,
            'topicId': 'qa-ratio-proportion',
            'topicName': 'Ratio, Proportion & Variation',
            'topicSlug': 'ratio-proportion',
            'description': 'Understand comparative quantities',
            'importance': 'very_important',
            'teachingMinutes': 210,
            'teachingDepth': 4,
            'subtopicId': null,
            'subtopicName': null,
            'state': 'AVAILABLE',
            'scriptAvailable': true,
            'scriptSlug': 'math_ratios_101',
            'scriptTitle': 'Introduction to Ratios',
          }
        ],
        'progress': {
          'totalTopics': 2,
          'completedTopics': 0,
          'activeStepId': 'ga-qa-04',
        }
      };

      final map = SubjectLearningMapModel.fromJson(json);
      expect(map.roadmapId, 'general-aptitude');
      expect(map.subjectId, 'quantitative-aptitude');
      expect(map.topics.length, 2);
      expect(map.topics[0].isComingSoon, isTrue);
      expect(map.topics[1].isAvailable, isTrue);
      expect(map.topics[1].scriptSlug, 'math_ratios_101');
    });

    test('NextLearningStepModel parses both available and coming soon states', () {
      final availableJson = {
        'type': 'lesson',
        'available': true,
        'roadmapStepId': 'ga-qa-04',
        'topicId': 'qa-ratio-proportion',
        'scriptId': 'uuid-1',
        'scriptSlug': 'math_ratios_101',
        'scriptTitle': 'Introduction to Ratios',
      };
      final availableNext = NextLearningStepModel.fromJson(availableJson);
      expect(availableNext.available, isTrue);
      expect(availableNext.scriptSlug, 'math_ratios_101');

      final comingSoonJson = {
        'type': 'lesson',
        'available': false,
        'reason': 'SCRIPT_NOT_PUBLISHED',
        'roadmapStepId': 'ga-qa-05',
        'topicId': 'qa-percentages',
        'topicName': 'Percentages',
      };
      final comingSoonNext = NextLearningStepModel.fromJson(comingSoonJson);
      expect(comingSoonNext.available, isFalse);
      expect(comingSoonNext.reason, 'SCRIPT_NOT_PUBLISHED');
      expect(comingSoonNext.topicName, 'Percentages');
    });

    testWidgets('LearningMapTopicCard renders AVAILABLE topic with tap action', (tester) async {
      bool tapped = false;
      final topic = LearningMapTopicItemModel(
        roadmapStepId: 'ga-qa-04',
        sequence: 4,
        topicId: 'qa-ratio-proportion',
        topicName: 'Ratio, Proportion & Variation',
        topicSlug: 'ratio-proportion',
        description: 'Understand comparative quantities and proportional relationships.',
        importance: 'very_important',
        teachingMinutes: 210,
        teachingDepth: 4,
        state: 'AVAILABLE',
        scriptAvailable: true,
        scriptSlug: 'math_ratios_101',
        scriptTitle: 'Introduction to Ratios',
        subtopicId: null,
        subtopicName: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningMapTopicCard(
              topic: topic,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Ratio, Proportion & Variation'), findsOneWidget);
      expect(find.text('STEP 04'), findsOneWidget);
      expect(find.text('VERY IMPORTANT'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('Start Lesson'), findsOneWidget);

      await tester.tap(find.text('Ratio, Proportion & Variation'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('LearningMapTopicCard renders COMING_SOON topic appropriately', (tester) async {
      final topic = LearningMapTopicItemModel(
        roadmapStepId: 'ga-qa-05',
        sequence: 5,
        topicId: 'qa-percentages',
        topicName: 'Percentages',
        topicSlug: 'percentages',
        description: 'Master percentage calculations',
        importance: 'very_important',
        teachingMinutes: 240,
        teachingDepth: 4,
        state: 'COMING_SOON',
        scriptAvailable: false,
        subtopicId: null,
        subtopicName: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningMapTopicCard(
              topic: topic,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Percentages'), findsOneWidget);
      expect(find.text('STEP 05'), findsOneWidget);
      expect(find.text('COMING SOON'), findsOneWidget);
      expect(find.text('Script In Production'), findsOneWidget);
    });
  });
}
