import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../models/practice_models.dart';

class PracticeRepository {
  final DioClient _client = Get.find<DioClient>();

  Future<List<LiveTopicModel>> getLiveTopics() async {
    final response = await _client.dio.get('/practice/topics/live');
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = (response.data['data'] as List<dynamic>)
          .map((item) => LiveTopicModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch live topics');
  }

  Future<PracticeSessionModel> createSession({
    String? topicId,
    List<String>? subtopicIds,
    bool smartPicks = false,
    bool timerEnabled = false,
  }) async {
    final Map<String, dynamic> data = {'smartPicks': smartPicks};
    if (topicId != null && topicId.isNotEmpty) {
      data['topicId'] = topicId;
    }
    if (subtopicIds != null && subtopicIds.isNotEmpty) {
      data['subtopicIds'] = subtopicIds;
    }

    final response = await _client.dio.post(
      '/practice/sessions',
      data: data,
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      final json = response.data['data'] as Map<String, dynamic>;
      await _client.secureStorage.write(
        key: 'practice_timer_${json['id']}',
        value: timerEnabled.toString(),
      );
      return PracticeSessionModel.fromJson({
        ...json,
        'timerEnabled': timerEnabled,
      });
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create practice session',
    );
  }

  Future<PracticeSessionModel> getSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) async {
    final timerEnabled =
        await _client.secureStorage.read(key: 'practice_timer_$sessionId') ==
        'true';
    final response = await _client.dio.get(
      '/practice/sessions/$sessionId',
      cancelToken: cancelToken,
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return PracticeSessionModel.fromJson({
        ...response.data['data'] as Map<String, dynamic>,
        'timerEnabled': response.data['data']['isFriendlyDuel'] == true
            ? response.data['data']['timerEnabled'] == true
            : timerEnabled,
      });
    }
    throw Exception(response.data['message'] ?? 'Failed to retrieve session');
  }

  Future<int> startFriendlyQuestion(String sessionId) async {
    final response = await _client.dio.post(
      '/practice/sessions/$sessionId/start-question',
    );
    return (response.data['data']['remainingMs'] as num).toInt();
  }

  Future<PracticeAnswerResultModel> submitAnswer({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
    CancelToken? cancelToken,
  }) async {
    final response = await _client.dio.post(
      '/practice/sessions/$sessionId/answer',
      cancelToken: cancelToken,
      data: {
        'questionId': questionId,
        'selectedOptionId': selectedOptionId,
        'responseTimeMs': responseTimeMs,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return PracticeAnswerResultModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(response.data['message'] ?? 'Failed to submit answer');
  }

  Future<void> abandonSession(String sessionId) async {
    await _client.dio.post('/practice/sessions/$sessionId/abandon');
  }

  Future<PracticeHistoryResponseModel> getHistory({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _client.dio.get(
      '/practice/history',
      queryParameters: {'page': page, 'limit': limit},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return PracticeHistoryResponseModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['message'] ?? 'Failed to retrieve practice history',
    );
  }

  Future<PracticeSessionModel> replaySession(
    String sessionId, {
    bool timerEnabled = false,
  }) async {
    final response = await _client.dio.post(
      '/practice/replay/$sessionId',
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return PracticeSessionModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['message'] ?? 'Failed to replay practice session',
    );
  }
}
