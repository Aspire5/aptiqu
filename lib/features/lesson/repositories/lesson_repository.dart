import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../models/lesson_session_model.dart';

class LessonRepository {
  final DioClient _dioClient = Get.find<DioClient>();

  Future<ActiveLessonStateModel> getActiveLessonState([String? roadmapStepId]) async {
    final response = await _dioClient.dio.get(
      '/lessons/active',
      queryParameters: {
        if (roadmapStepId != null) 'roadmapStepId': roadmapStepId,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return ActiveLessonStateModel.fromJson(data);
  }

  Future<LessonSessionModel> startOrResumeSession({
    String? scriptSlug,
    String? roadmapStepId,
    required String clientActionId,
  }) async {
    final response = await _dioClient.dio.post(
      '/lessons/sessions',
      data: {
        if (scriptSlug != null) 'scriptSlug': scriptSlug,
        if (roadmapStepId != null) 'roadmapStepId': roadmapStepId,
        'clientActionId': clientActionId,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return LessonSessionModel.fromJson(data);
  }

  Future<LessonSessionModel> startOrResumeSessionByStep({
    required String roadmapStepId,
    required String clientActionId,
  }) async {
    final response = await _dioClient.dio.post(
      '/roadmaps/steps/$roadmapStepId/start',
      data: {
        'clientActionId': clientActionId,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return LessonSessionModel.fromJson(data);
  }

  Future<LessonSessionModel> getSession(String sessionId) async {
    final response = await _dioClient.dio.get('/lessons/sessions/$sessionId');
    final data = response.data['data'] as Map<String, dynamic>;
    return LessonSessionModel.fromJson(data);
  }

  Future<LessonSessionModel> submitAction({
    required String sessionId,
    required String clientActionId,
    required int stateVersion,
    required String currentNodeId,
    required String actionType,
    String? actionId,
    String? answer,
    int? responseTimeMs,
  }) async {
    final response = await _dioClient.dio.post(
      '/lessons/sessions/$sessionId/actions',
      data: {
        'clientActionId': clientActionId,
        'stateVersion': stateVersion,
        'currentNodeId': currentNodeId,
        'action': {
          'type': actionType,
          if (actionId != null) 'actionId': actionId,
          if (answer != null) 'answer': answer,
          if (responseTimeMs != null) 'responseTimeMs': responseTimeMs,
        },
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return LessonSessionModel.fromJson(data);
  }

  Future<String> submitInterrupt({
    required String sessionId,
    required String clientActionId,
    required String currentNodeId,
    required String questionText,
  }) async {
    final response = await _dioClient.dio.post(
      '/lessons/sessions/$sessionId/interrupts',
      data: {
        'clientActionId': clientActionId,
        'currentNodeId': currentNodeId,
        'questionText': questionText,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return data['message'] as String? ?? 'Doubt received.';
  }

  Future<void> pauseSession(String sessionId) async {
    await _dioClient.dio.post('/lessons/sessions/$sessionId/pause');
  }

  Future<void> resumeSession(String sessionId) async {
    await _dioClient.dio.post('/lessons/sessions/$sessionId/resume');
  }
}
