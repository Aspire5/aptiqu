import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/repositories/roadmap_repository.dart';
import 'package:aptiqu/features/lesson/models/lesson_session_model.dart';
import 'package:aptiqu/features/lesson/repositories/lesson_repository.dart';

LearningMapTopicItemModel topic(
  String id, {
  String state = 'AVAILABLE',
  bool playable = true,
}) => LearningMapTopicItemModel(
  roadmapStepId: id,
  sequence: 1,
  topicId: id,
  topicName: id,
  topicSlug: id,
  importance: 'medium',
  teachingMinutes: 10,
  teachingDepth: 1,
  state: state,
  scriptAvailable: playable,
);
SubjectLearningMapModel learningMap(
  String subject, {
  List<LearningMapTopicItemModel> topics = const [],
  String? active,
}) => SubjectLearningMapModel(
  roadmapId: 'roadmap',
  roadmapName: 'Roadmap',
  roadmapCourse: 'general',
  subjectId: subject,
  subjectName: subject,
  topics: topics,
  totalTopics: topics.length,
  completedTopics: topics.where((t) => t.isCompleted).length,
  activeStepId: active,
);
ActiveRoadmapModel roadmap() => ActiveRoadmapModel(
  id: 'roadmap',
  slug: 'roadmap',
  name: 'Roadmap',
  course: 'general',
  subjects: [
    for (final id in ['a', 'b'])
      RoadmapSubjectSummary(id: id, slug: id, name: id, sequence: 1),
  ],
);
LessonSessionModel session({bool completed = false}) =>
    LessonSessionModel.fromJson({
      'sessionId': 'session',
      'scriptId': 'script',
      'status': completed ? 'COMPLETED' : 'ACTIVE',
      'roadmapStepId': 'step',
      'currentNode': {
        'id': completed ? 'done' : 'intro',
        'type': completed ? 'COMPLETION' : 'EXPLANATION',
        'content': {'text': completed ? 'Done' : 'Learn'},
      },
    });

class QuietHome extends HomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> fetchDashboard() async {}
}

class DeferredRoadmaps extends RoadmapRepository {
  final pending = <String, Completer<SubjectLearningMapModel>>{};
  @override
  Future<ActiveRoadmapModel> getActiveRoadmap() async => roadmap();
  @override
  Future<SubjectLearningMapModel> getSubjectLearningMap({
    required String roadmapId,
    required String subjectId,
  }) => (pending[subjectId] = Completer<SubjectLearningMapModel>()).future;
}

class RecordingLessons extends LessonRepository {
  bool? restartRequested;
  String? requestedSlug;
  @override
  Future<LessonSessionModel> startOrResumeSessionByStep({
    required String roadmapStepId,
    required String clientActionId,
    String? scriptSlug,
    bool restart = false,
  }) async {
    restartRequested = restart;
    requestedSlug = scriptSlug;
    return session();
  }
}

class CompletedRoadmaps extends RoadmapRepository {
  int mapRequests = 0;
  @override
  Future<ActiveRoadmapModel> getActiveRoadmap() async => roadmap();
  @override
  Future<SubjectLearningMapModel> getSubjectLearningMap({
    required String roadmapId,
    required String subjectId,
  }) async {
    mapRequests++;
    return learningMap(
      subjectId,
      topics: [topic('step', state: 'COMPLETED')],
      active: 'step',
    );
  }
}

class CompletingLessons extends RecordingLessons {
  @override
  Future<LessonSessionModel> submitAction({
    required String sessionId,
    required String clientActionId,
    required int stateVersion,
    required String currentNodeId,
    required String actionType,
    String? actionId,
    String? answer,
    int? responseTimeMs,
  }) async => session(completed: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
  });
  tearDown(() => Get.reset());
  test(
    'focus follows latest played completed or unfinished topic, including final topic',
    () {
      final topics = [
        topic('first'),
        topic('middle', state: 'IN_PROGRESS'),
        topic('last', state: 'COMPLETED'),
      ];
      expect(
        learningMap(
          'a',
          topics: topics,
          active: 'last',
        ).focusTopic?.roadmapStepId,
        'last',
      );
      expect(
        learningMap(
          'a',
          topics: topics,
          active: 'middle',
        ).focusTopic?.roadmapStepId,
        'middle',
      );
      expect(
        learningMap(
          'a',
          topics: topics,
          active: 'removed',
        ).focusTopic?.roadmapStepId,
        'middle',
      );
    },
  );
  test(
    'new learner starts at first playable topic and empty/unpublished maps have no play marker',
    () {
      final soon = topic('soon', state: 'COMING_SOON', playable: false);
      expect(
        learningMap(
          'a',
          topics: [soon, topic('first')],
        ).focusTopic?.roadmapStepId,
        'first',
      );
      expect(
        learningMap('a', topics: [soon], active: 'soon').focusTopic,
        isNull,
      );
      expect(learningMap('a').focusTopic, isNull);
    },
  );
  test(
    'completed status is sufficient when API omits isCompleted',
    () => expect(session(completed: true).isCompleted, true),
  );
  test('rapid switching ignores stale responses and stale errors', () async {
    final repo =
        Get.put<RoadmapRepository>(DeferredRoadmaps()) as DeferredRoadmaps;
    final home = Get.put<HomeController>(QuietHome());
    home.activeRoadmap.value = roadmap();
    final first = home.selectSubject('a');
    final second = home.selectSubject('b');
    repo.pending['b']!.complete(learningMap('b'));
    await second;
    repo.pending['a']!.completeError(StateError('Old request failed'));
    await first;
    expect(home.subjectLearningMap.value?.subjectId, 'b');
    expect(home.selectedSubjectId.value, 'b');
    expect(home.roadmapError.value, isNull);
    expect(home.isLoadingMap.value, false);
    final third = home.selectSubject('a');
    final fourth = home.selectSubject('b');
    repo.pending['a']!.complete(learningMap('a'));
    await third;
    expect(home.subjectLearningMap.value?.subjectId, 'b');
    expect(home.isLoadingMap.value, true);
    repo.pending['b']!.complete(learningMap('b'));
    await fourth;
  });
  testWidgets(
    'starting unfinished lessons resumes instead of requesting restart',
    (tester) async {
      final lessons =
          Get.put<LessonRepository>(RecordingLessons()) as RecordingLessons;
      final home = Get.put<HomeController>(QuietHome());
      final start = home.startSubtopicLesson(
        roadmapStepId: 'step',
        scriptSlug: 'script',
      );
      await tester.pump(const Duration(seconds: 1));
      await start;
      expect(lessons.restartRequested, false);
      expect(lessons.requestedSlug, 'script');
      expect(home.currentSession.value?.id, 'session');
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'confirmed completion refreshes the topic map without leaving the player',
    (tester) async {
      final repo =
          Get.put<RoadmapRepository>(CompletedRoadmaps()) as CompletedRoadmaps;
      Get.put<LessonRepository>(CompletingLessons());
      final home = Get.put<HomeController>(QuietHome());
      home.activeRoadmap.value = roadmap();
      home.selectedSubjectId.value = 'a';
      home.subjectLearningMap.value = learningMap(
        'a',
        topics: [topic('step')],
        active: 'step',
      );
      home.currentSession.value = session();
      home.messages.add(
        ChatMessageModel(
          id: 'intro',
          sender: MessageSender.ai,
          text: 'Learn',
          time: '',
          node: session().currentNode,
        ),
      );
      final action = home.handleContinueAction('intro');
      await tester.pump(const Duration(seconds: 1));
      await action;
      await tester.pump(const Duration(seconds: 1));
      expect(repo.mapRequests, 1);
      expect(home.subjectLearningMap.value?.completedTopics, 1);
      expect(home.subjectLearningMap.value?.focusTopic?.roadmapStepId, 'step');
      expect(home.currentSession.value?.isCompleted, true);
    },
  );
}
