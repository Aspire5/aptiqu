import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/progression/models/xp_models.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/presentation/widgets/level_up_overlay.dart';
import 'package:aptiqu/features/home/presentation/widgets/top_bar_zone.dart';
import 'package:aptiqu/features/lesson/models/lesson_node_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put<DioClient>(DioClient());
  });

  group('XP Models & Calculations Tests', () {
    test('XpProgressModel parses JSON correctly', () {
      final json = {
        'earned': 20,
        'previousTotal': 100,
        'total': 120,
        'level': 4,
        'currentLevelStartXp': 120,
        'nextLevelStartXp': 200,
        'xpIntoCurrentLevel': 0,
        'xpRequiredForNextLevel': 80,
        'xpRemainingToNextLevel': 80,
        'progress': 0.0,
      };

      final model = XpProgressModel.fromJson(json);
      expect(model.earned, 20);
      expect(model.total, 120);
      expect(model.level, 4);
      expect(model.xpRequiredForNextLevel, 80);
      expect(model.progress, 0.0);
    });

    test('LevelUpModel parses JSON correctly', () {
      final json = {
        'occurred': true,
        'fromLevel': 2,
        'toLevel': 4,
        'levelsGained': 2,
      };

      final model = LevelUpModel.fromJson(json);
      expect(model.occurred, isTrue);
      expect(model.fromLevel, 2);
      expect(model.toLevel, 4);
      expect(model.levelsGained, 2);
    });

    test('QuestionInlineModel dynamically calculates question XP', () {
      expect(
        QuestionInlineModel.calculateQuestionXp('PRACTICE', 'EASY'),
        10,
      );
      expect(
        QuestionInlineModel.calculateQuestionXp('PRACTICE', 'HARD'),
        20,
      );
      expect(
        QuestionInlineModel.calculateQuestionXp('RANKED', 'HARD'),
        25,
      );
    });

    test('QuestionData in HomeController calculates dynamic XP', () {
      final qEasy = QuestionData(
        title: 'Easy Q',
        desc: 'Testing easy question',
        inputType: QuestionInputType.select,
        questionType: QuestionModeType.practice,
        difficultyLevel: QuestionDifficultyLevel.easy,
      );
      expect(qEasy.xp, 10);

      final qHardRanked = QuestionData(
        title: 'Hard Ranked Q',
        desc: 'Testing hard ranked question',
        inputType: QuestionInputType.select,
        questionType: QuestionModeType.ranked,
        difficultyLevel: QuestionDifficultyLevel.hard,
      );
      expect(qHardRanked.xp, 25);
    });

    test('UserModel parses totalXp and progress correctly', () {
      final json = {
        'id': 'u1',
        'email': 'user@aptiqu.io',
        'firstName': 'Shagun',
        'level': 3,
        'totalXp': 80,
        'xpIntoCurrentLevel': 20,
        'xpRequiredForNextLevel': 60,
        'progress': 0.3333,
        'streak': '5d',
        'coins': 15,
      };

      final user = UserModel.fromJson(json);
      expect(user.level, 3);
      expect(user.totalXp, 80);
      expect(user.progress, 0.3333);
      expect(user.streak, '5d');
    });
  });

  group('TopBarZone Level & Progress Ring Widget Tests', () {
    testWidgets('Renders Level text and circular progress avatar ring', (tester) async {
      final auth = Get.put(AuthController());
      auth.currentUser.value = const UserModel(
        id: 'user_1',
        email: 'shagun@aptiqu.io',
        firstName: 'Shagun',
        level: 4,
        totalXp: 150,
        progress: 0.375,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopBarZone(height: 80),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Shagun'), findsOneWidget);
      expect(find.text('LEVEL 4'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('LevelUpOverlay Widget & Interaction Tests', () {
    testWidgets('Renders LEVEL UP!, level number, and Continue button', (tester) async {
      bool continued = false;
      const levelUp = LevelUpModel(
        occurred: true,
        fromLevel: 3,
        toLevel: 4,
        levelsGained: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpOverlay(
              levelUp: levelUp,
              onContinue: () {
                continued = true;
              },
            ),
          ),
        ),
      );

      // Fast forward animation
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('LEVEL UP!'), findsOneWidget);
      expect(find.text('LEVEL 4'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap Continue
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(continued, isTrue);
    });

    testWidgets('Multi-level transition increments to final level', (tester) async {
      const multiLevelUp = LevelUpModel(
        occurred: true,
        fromLevel: 2,
        toLevel: 5,
        levelsGained: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpOverlay(
              levelUp: multiLevelUp,
              onContinue: () {},
            ),
          ),
        ),
      );

      // At start, displays initial level
      expect(find.text('LEVEL 2'), findsOneWidget);

      // Finish animation
      await tester.pump(const Duration(milliseconds: 1600));

      // Reaches final level 5
      expect(find.text('LEVEL 5'), findsOneWidget);
    });
  });

  group('XpController State & Level-Up Trigger Tests', () {
    testWidgets('XpController updates progress and triggers overlay when occurred is true', (tester) async {
      final auth = Get.put(AuthController());
      auth.currentUser.value = const UserModel(
        id: 'u1',
        email: 'test@aptiqu.io',
        firstName: 'Tester',
        level: 1,
      );

      final xpController = Get.put(XpController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    xpController.handleXpUpdate(
                      xp: const XpProgressModel(
                        earned: 20,
                        total: 20,
                        level: 2,
                      ),
                      levelUp: const LevelUpModel(
                        occurred: true,
                        fromLevel: 1,
                        toLevel: 2,
                        levelsGained: 1,
                      ),
                      context: context,
                    );
                  },
                  child: const Text('Award XP'),
                );
              },
            ),
          ),
        ),
      );

      // Progress updated in controller and AuthController
      expect(xpController.progress.value.level, 1);

      await tester.tap(find.text('Award XP'));
      await tester.pump(); // Open dialog
      await tester.pump(const Duration(milliseconds: 1600)); // Finish celebration animation

      expect(xpController.progress.value.level, 2);
      expect(auth.currentUser.value?.level, 2);
      expect(find.text('LEVEL UP!'), findsOneWidget);
      expect(find.text('LEVEL 2'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Dismiss dialog via Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('LEVEL UP!'), findsNothing);
      // Persisted level remains 2
      expect(xpController.progress.value.level, 2);
      expect(auth.currentUser.value?.level, 2);
    });

    testWidgets('XpController does NOT trigger overlay when levelUp.occurred is false', (tester) async {
      final auth = Get.put(AuthController());
      auth.currentUser.value = const UserModel(
        id: 'u1',
        email: 'test@aptiqu.io',
        firstName: 'Tester',
        level: 1,
      );

      final xpController = Get.put(XpController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    xpController.handleXpUpdate(
                      xp: const XpProgressModel(
                        earned: 10,
                        total: 10,
                        level: 1,
                      ),
                      levelUp: const LevelUpModel(
                        occurred: false,
                        fromLevel: 1,
                        toLevel: 1,
                        levelsGained: 0,
                      ),
                      context: context,
                    );
                  },
                  child: const Text('Small Award'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Small Award'));
      await tester.pump();

      // No celebration overlay displayed
      expect(find.text('LEVEL UP!'), findsNothing);
      expect(xpController.progress.value.total, 10);
    });
  });
}
