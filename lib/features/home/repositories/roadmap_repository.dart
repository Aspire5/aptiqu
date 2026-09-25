import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../models/roadmap_model.dart';

class RoadmapRepository {
  final DioClient _dioClient = Get.find<DioClient>();

  Future<ActiveRoadmapModel> getActiveRoadmap() async {
    final response = await _dioClient.dio.get('/roadmaps/active');
    final data = response.data['data'] as Map<String, dynamic>;
    return ActiveRoadmapModel.fromJson(data);
  }

  Future<SubjectLearningMapModel> getSubjectLearningMap({
    required String roadmapId,
    required String subjectId,
  }) async {
    final response = await _dioClient.dio.get('/roadmaps/$roadmapId/subjects/$subjectId/map');
    final data = response.data['data'] as Map<String, dynamic>;
    return SubjectLearningMapModel.fromJson(data);
  }

  Future<void> selectRoadmap(String roadmapId) async {
    await _dioClient.dio.post('/roadmaps/$roadmapId/select');
  }
}
