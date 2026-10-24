import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
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

  String? _activePreparationId;
  bool _cancelled = false;
  String get _owner => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currentUser.value?.id ?? ''
      : '';
  String _pendingKey(String owner) => 'luna_practice_pending_$owner';

  Future<PracticeSessionModel?> resumePendingPreparation() async {
    final owner = _owner;
    final raw = await _client.secureStorage.read(key: _pendingKey(owner));
    if (raw == null) return null;
    _cancelled = false;
    return _prepare(Map<String, dynamic>.from(jsonDecode(raw) as Map), owner);
  }

  Future<void> cancelPreparation() async {
    final owner = _owner;
    var id = _activePreparationId;
    if (id == null) {
      final raw = await _client.secureStorage.read(key: _pendingKey(owner));
      if (raw == null) return;
      final record = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      id = record['id'] as String?;
      if (id == null) {
        final response = await _client.dio.post(
          '/practice/sessions',
          data: record['body'],
          options: Options(headers: {'Idempotency-Key': record['requestKey']}),
        );
        id = response.data['data']['id'] as String;
      }
    }
    if (_owner != owner) return;
    final result = await _client.dio.delete('/practice/preparations/$id');
    if (result.data['data']?['state'] == 'READY') return;
    _cancelled = true;
    await _client.secureStorage.delete(key: _pendingKey(owner));
  }

  Future<PracticeSessionModel> createSession({
    String? topicId,
    List<String>? subtopicIds,
    bool smartPicks = false,
    bool timerEnabled = false,
  }) async {
    final owner = _owner;
    final previous = await _client.secureStorage.read(key: _pendingKey(owner));
    final record = previous == null
        ? <String, dynamic>{
            'requestKey': const Uuid().v4(),
            'timerEnabled': timerEnabled,
            'body': {
              'smartPicks': smartPicks,
              if (topicId != null && topicId.isNotEmpty) 'topicId': topicId,
              if (subtopicIds != null && subtopicIds.isNotEmpty)
                'subtopicIds': subtopicIds,
            },
          }
        : Map<String, dynamic>.from(jsonDecode(previous) as Map);
    _cancelled = false;
    await _client.secureStorage.write(
      key: _pendingKey(owner),
      value: jsonEncode(record),
    );
    return _prepare(record, owner);
  }

  Future<PracticeSessionModel> _prepare(
    Map<String, dynamic> record,
    String owner,
  ) async {
    void checkOwner() {
      if (_owner != owner) throw Exception('Your sign-in session changed.');
      if (_cancelled) throw const PreparationCancelled();
    }

    Future<void> save() => _client.secureStorage.write(
      key: _pendingKey(owner),
      value: jsonEncode(record),
    );
    checkOwner();
    while (record['id'] == null) {
      checkOwner();
      try {
        final response = await _client.dio.post(
          '/practice/sessions',
          data: record['body'],
          options: Options(
            headers: {'Idempotency-Key': record['requestKey']},
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        checkOwner();
        if (response.statusCode != 202 || response.data['success'] != true) {
          throw Exception('Could not start question preparation.');
        }
        record['id'] = response.data['data']['id'];
        await save();
      } on DioException catch (error) {
        checkOwner();
        final code = error.response?.statusCode;
        if ([400, 401, 403, 404, 409].contains(code)) {
          await _client.secureStorage.delete(key: _pendingKey(owner));
          rethrow;
        }
        // An acknowledgement may have been lost after the durable insert.
        // Retry the saved key; never create a second logical preparation.
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    _activePreparationId = record['id'] as String;
    while (true) {
      checkOwner();
      try {
        final response = await _client.dio.get(
          '/practice/preparations/${record['id']}',
          options: Options(receiveTimeout: const Duration(seconds: 20)),
        );
        checkOwner();
        final status = response.data['data'] as Map<String, dynamic>?;
        if (status == null) {
          await _client.secureStorage.delete(key: _pendingKey(owner));
          throw Exception('Question preparation was not found.');
        }
        final state = status['state'];
        if (state == 'READY') {
          final id = status['sessionId'] as String;
          final timed = record['timerEnabled'] == true;
          await _client.secureStorage.write(
            key: 'practice_timer_$id',
            value: timed.toString(),
          );
          final session = await getSession(id);
          checkOwner();
          await _client.secureStorage.delete(key: _pendingKey(owner));
          _activePreparationId = null;
          return session;
        }
        if (['FAILED', 'EXPIRED', 'CANCELLED'].contains(state)) {
          await _client.secureStorage.delete(key: _pendingKey(owner));
          _activePreparationId = null;
          if (state == 'CANCELLED') throw const PreparationCancelled();
          throw Exception(
            'We couldn’t prepare your questions. Please try again.',
          );
        }
      } on DioException catch (error) {
        checkOwner();
        if ([400, 401, 403, 404].contains(error.response?.statusCode)) {
          await _client.secureStorage.delete(key: _pendingKey(owner));
          rethrow;
        }
        // A short network/request timeout does not cancel a durable backend job.
        // Reconnect and keep polling until the backend reports its real outcome.
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
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

  Future<({int remainingMs, PracticeSessionModel session})>
  startFriendlyQuestion(String sessionId) async {
    final response = await _client.dio.post(
      '/practice/sessions/$sessionId/start-question',
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (
      remainingMs: (data['remainingMs'] as num).toInt(),
      session: PracticeSessionModel.fromJson(
        Map<String, dynamic>.from(data['session']),
      ),
    );
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

class PreparationCancelled implements Exception {
  const PreparationCancelled();
  @override
  String toString() => 'Question preparation cancelled.';
}
