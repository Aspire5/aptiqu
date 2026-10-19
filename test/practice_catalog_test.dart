import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'dart:convert';
import 'support/presentation_fonts.dart';
export 'support/font_manifest.dart' show TestFontManifest;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/practice/controllers/practice_catalog_controller.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/repositories/practice_repository.dart';
import 'package:aptiqu/features/practice/views/practice_catalog_view.dart';

class CatalogRepository extends PracticeRepository {
  @override
  Future<List<LiveTopicModel>> getLiveTopics() async => [
    const LiveTopicModel(
      subjectId: 'math',
      subjectName: 'Quantitative Aptitude',
      topicId: 'numbers',
      topicName: 'Number System',
      subtopics: [
        LiveSubtopicModel(
          id: 'n1',
          name: 'Place Value, Face Value & Number Formation',
        ),
        LiveSubtopicModel(id: 'n2', name: 'Prime Numbers and Factors'),
      ],
    ),
    const LiveTopicModel(
      subjectId: 'math',
      subjectName: 'Quantitative Aptitude',
      topicId: 'ages',
      topicName: 'Problems on Ages',
      subtopics: [LiveSubtopicModel(id: 'a1', name: 'Past and Future Ages')],
    ),
  ];
}

void main() {
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    Get.put(AppearanceController()).mode.value = ThemeMode.dark;
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
  });
  tearDown(() => Get.reset());
  testWidgets(
    'phone layout has two tabs, options and multi-topic custom selection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(
        PracticeCatalogController(repository: CatalogRepository()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: const Scaffold(body: PracticeCatalogView()),
        ),
      );
      await tester.pumpAndSettle();
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.byType(ButtonSegment<PracticeSelectionMode>), findsNothing);
      expect(find.text('Smart AI Picks'), findsOneWidget);
      expect(find.text('60-second timer'), findsOneWidget);
      expect(find.text('Quick Drill'), findsNothing);
      expect(find.text('Active Syllabus Pool'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/practice-random.png'),
      );
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      c.toggleTopic('numbers');
      c.toggleTopic('ages');
      await tester.pumpAndSettle();
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      expect(c.selectedSubtopicIds.toSet(), {'n1', 'n2', 'a1'});
      expect(tester.takeException(), isNull);
      // Optional visual snapshots: update with --update-goldens.
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/practice-custom.png'),
      );
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(body: PracticeCatalogView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      c.historyList.assignAll([
        PracticeHistoryItemModel.fromJson({
          'id': 'replay',
          'isReplay': true,
          'replaySourceType': 'PVP',
          'totalQuestions': 10,
          'correctCount': 8,
          'totalTimeMs': 100000,
        }),
      ]);
      c.showHistory.value = true;
      await tester.pumpAndSettle();
      await loadProductionFontFixtures(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'preferences restore custom selection and remove unavailable IDs',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'practice_preferences_v2': jsonEncode({
          'custom': true,
          'smartPicks': true,
          'timerEnabled': true,
          'subject': 'math',
          'subtopics': ['a1', 'removed'],
        }),
      });
      final c = Get.put(
        PracticeCatalogController(repository: CatalogRepository()),
      );
      await tester.pumpAndSettle();
      expect(c.selectionMode.value, PracticeSelectionMode.specific);
      expect(c.smartPicks.value, true);
      expect(c.timerEnabled.value, true);
      expect(c.selectedSubtopicIds.toSet(), {'a1'});
      c.toggleSubtopic('n1');
      await tester.pumpAndSettle();
      final raw = await Get.find<DioClient>().secureStorage.read(
        key: 'practice_preferences_v2',
      );
      expect((jsonDecode(raw!)['subtopics'] as List).toSet(), {'a1', 'n1'});
    },
  );
}
