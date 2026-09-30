import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../models/daily_challenge_models.dart';

class DailyChallengeRepository {
  final DioClient _client = Get.find<DioClient>();

  Future<DailyChallengeStatusModel> getStatus() async {
    final response = await _client.dio.get('/daily-challenge/status');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return DailyChallengeStatusModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(
        response.data['message'] ?? 'Failed to retrieve daily challenge status');
  }

  Future<DailyChallengeSessionModel> startChallenge() async {
    final response = await _client.dio.post(
      '/daily-challenge/start',
      options: Options(
        receiveTimeout: const Duration(seconds: 90),
      ),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return DailyChallengeSessionModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(
        response.data['message'] ?? 'Failed to start daily challenge');
  }

  Future<DailyChallengeAnswerResultModel> submitAnswer({
    required String participationId,
    required String questionId,
    required String selectedOptionId,
    required int responseTimeMs,
  }) async {
    final response = await _client.dio.post(
      '/daily-challenge/answer',
      data: {
        'participationId': participationId,
        'questionId': questionId,
        'selectedOptionId': selectedOptionId,
        'responseTimeMs': responseTimeMs,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return DailyChallengeAnswerResultModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit answer');
  }

  Future<DailyHistoryResponseModel> getHistory({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _client.dio.get(
      '/daily-challenge/history',
      queryParameters: {'page': page, 'limit': limit},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return DailyHistoryResponseModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(
        response.data['message'] ?? 'Failed to retrieve daily challenge history');
  }
}
