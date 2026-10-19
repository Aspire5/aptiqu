import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'ranked_models.dart';

class RankedFailure implements Exception {
  final String code;
  final int? retryAfter;
  const RankedFailure(this.code, [this.retryAfter]);
}

class RankedRepository {
  final Dio? _dio;
  DateTime? _retryAt;
  String? _cooldownOwner;
  RankedRepository({Dio? dio}) : _dio = dio;
  String? get owner => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currentUser.value?.id
      : null;
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final account = owner;
    if (_cooldownOwner != account) {
      _cooldownOwner = account;
      _retryAt = null;
    }
    final wait = _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    if (wait > 0) throw RankedFailure('RETRY_LATER', (wait / 1000).ceil());
    try {
      final res = await (_dio ?? Get.find<DioClient>().dio).get(
        path,
        queryParameters: query,
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (owner != account) throw const RankedFailure('ACCOUNT_CHANGED');
      if (res.data is! Map || res.data['success'] != true) {
        throw const RankedFailure('UNAVAILABLE');
      }
      return rankedMap(res.data['data']);
    } on DioException catch (e) {
      final data = e.response?.data;
      final seconds = int.tryParse(
        e.response?.headers.value('retry-after') ?? '',
      );
      if (owner == account &&
          seconds != null &&
          seconds > 0 &&
          [429, 503].contains(e.response?.statusCode)) {
        _retryAt = DateTime.now().add(Duration(seconds: seconds));
      }
      throw RankedFailure(
        data is Map ? data['code']?.toString() ?? 'UNAVAILABLE' : 'UNAVAILABLE',
        int.tryParse(e.response?.headers.value('retry-after') ?? ''),
      );
    }
  }

  Future<RankedSummary> me({String? seasonId}) async => RankedSummary.fromJson(
    await get('/pvp/ranked/me', {
      'fresh': '1',
      if (seasonId != null) 'seasonId': seasonId,
    }),
  );
  Future<Map<String, dynamic>> board({String? seasonId, String? cursor}) =>
      get('/pvp/ranked/leaderboard', {
        if (seasonId != null) 'seasonId': seasonId,
        if (cursor != null) 'cursor': cursor,
      });
  Future<Map<String, dynamic>> seasons({String? before}) =>
      get('/pvp/ranked/seasons', {if (before != null) 'before': before});
  Future<Map<String, dynamic>> history({int page = 1}) =>
      get('/pvp/history', {'page': page, 'includeVoids': '1'});
}
