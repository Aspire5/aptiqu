import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/practice_models.dart';
import '../repositories/practice_repository.dart';
import '../views/practice_session_screen.dart';

class PracticeCatalogController extends GetxController {
  final PracticeRepository _repository = PracticeRepository();

  final RxBool isLoading = true.obs;
  final RxBool isStartingSession = false.obs;
  final RxList<LiveTopicModel> liveTopics = <LiveTopicModel>[].obs;
  final RxSet<String> selectedSubtopicIds = <String>{}.obs;
  final RxString selectedTopicId = ''.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLiveTopics();
  }

  Future<void> fetchLiveTopics() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final topics = await _repository.getLiveTopics();
      liveTopics.assignAll(topics);

      if (topics.isNotEmpty) {
        selectedTopicId.value = topics.first.topicId;
        // Select all live subtopics by default for ease of quick-starting
        selectedSubtopicIds.assignAll(topics.first.subtopics.map((s) => s.id));
      }
    } catch (err) {
      errorMessage.value = err.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void selectTopic(String topicId) {
    selectedTopicId.value = topicId;
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic != null) {
      selectedSubtopicIds.assignAll(topic.subtopics.map((s) => s.id));
    } else {
      selectedSubtopicIds.clear();
    }
  }

  void toggleSubtopic(String subtopicId) {
    if (selectedSubtopicIds.contains(subtopicId)) {
      if (selectedSubtopicIds.length > 1) {
        selectedSubtopicIds.remove(subtopicId);
      } else {
        Get.snackbar(
          'At least one required',
          'Please keep at least one subtopic selected for Practice.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
        );
      }
    } else {
      selectedSubtopicIds.add(subtopicId);
    }
  }

  Future<void> startPracticeSession() async {
    if (selectedTopicId.isEmpty || selectedSubtopicIds.isEmpty) return;

    isStartingSession.value = true;
    try {
      final session = await _repository.createSession(
        topicId: selectedTopicId.value,
        subtopicIds: selectedSubtopicIds.toList(),
      );

      // Navigate to the session screen
      Get.to(() => PracticeSessionScreen(initialSession: session));
    } catch (err) {
      Get.snackbar(
        'Session Failed',
        err.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isStartingSession.value = false;
    }
  }
}
