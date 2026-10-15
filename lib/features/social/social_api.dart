import 'package:get/get.dart';
import '../../core/network/dio_client.dart';

class SocialApi {
  final DioClient client;
  SocialApi({DioClient? client}) : client = client ?? Get.find<DioClient>();
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final r = await client.dio.get('/social/$path', queryParameters: query);
    return Map<String, dynamic>.from(r.data['data'] ?? {});
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final r = await client.dio.post('/social/$path', data: body ?? {});
    return Map<String, dynamic>.from(r.data['data'] ?? {});
  }

  Future<void> removeFriend(String id) async {
    await client.dio.delete('/social/friends/$id');
  }
}
