import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/practice_models.dart';
import '../repositories/practice_repository.dart';
import '../views/practice_session_screen.dart';
import '../../../core/routing/app_router.dart';
import 'practice_session_controller.dart';

enum PracticeSelectionMode {
  random,
  specific,
  history,
}

class PracticeCatalogController extends GetxController {
  final PracticeRepository _repository = PracticeRepository();

  final Rx<PracticeSelectionMode> selectionMode = PracticeSelectionMode.random.obs;
  final RxBool isLoading = true.obs;
  final RxBool isStartingSession = false.obs;
  final RxList<LiveTopicModel> liveTopics = <LiveTopicModel>[].obs;
  final RxSet<String> selectedSubtopicIds = <String>{}.obs;
  final RxString selectedSubjectId = ''.obs;
  final RxString selectedTopicId = ''.obs;
  final RxString errorMessage = ''.obs;

  // History observables
  final RxList<PracticeHistoryItemModel> historyList = <PracticeHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs;
  final RxInt historyCompletedDrills = 0.obs;
  final RxInt historyOverallAccuracy = 0.obs;
  final RxInt historyAvgResponseTimeMs = 0.obs;
  final RxBool isReplaying = false.obs;

  String? _pendingSubjectId;
  String? _pendingTopicId;

  @override
  void onInit() {
    super.onInit();
    fetchLiveTopics();
  }

  /// Unique live subjects derived from liveTopics
  List<({String id, String name})> get liveSubjects {
    final Map<String, String> map = {};
    for (final topic in liveTopics) {
      map[topic.subjectId] = topic.subjectName;
    }
    return map.entries.map((e) => (id: e.key, name: e.value)).toList();
  }

  /// Live topics belonging to the currently selected subject
  List<LiveTopicModel> get currentSubjectTopics {
    if (selectedSubjectId.isEmpty) return liveTopics;
    return liveTopics.where((t) => t.subjectId == selectedSubjectId.value).toList();
  }

  /// Total count of all subtopics across all live topics
  int get totalLiveSubtopicsCount {
    return liveTopics.fold<int>(0, (sum, topic) => sum + topic.subtopics.length);
  }

  Future<void> fetchLiveTopics() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final topics = await _repository.getLiveTopics();
      liveTopics.assignAll(topics);

      if (topics.isNotEmpty) {
        // If there was a pending preselection from Topics screen
        if (_pendingTopicId != null) {
          applyPendingPreselection();
        } else {
          // Default selection for Specific Mode
          if (selectedSubjectId.isEmpty || !topics.any((t) => t.subjectId == selectedSubjectId.value)) {
            selectedSubjectId.value = topics.first.subjectId;
          }
          selectedTopicId.value = topics.first.topicId;
          selectedSubtopicIds.assignAll(topics.first.subtopics.map((s) => s.id));
        }
      }
    } catch (err) {
      errorMessage.value = err.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void selectSubject(String subjectId) {
    selectedSubjectId.value = subjectId;
    final topics = liveTopics.where((t) => t.subjectId == subjectId).toList();
    if (topics.isNotEmpty) {
      selectedTopicId.value = topics.first.topicId;
      // Select all subtopics of this subject by default
      final allSubIds = topics.expand((t) => t.subtopics.map((s) => s.id)).toSet();
      selectedSubtopicIds.assignAll(allSubIds);
    }
  }

  void selectTopic(String topicId) {
    selectedTopicId.value = topicId;
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic != null) {
      selectedSubtopicIds.assignAll(topic.subtopics.map((s) => s.id));
    }
  }

  bool isTopicFullySelected(String topicId) {
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic == null || topic.subtopics.isEmpty) return false;
    return topic.subtopics.every((s) => selectedSubtopicIds.contains(s.id));
  }

  bool isTopicPartiallySelected(String topicId) {
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic == null || topic.subtopics.isEmpty) return false;
    final selectedCount = topic.subtopics.where((s) => selectedSubtopicIds.contains(s.id)).length;
    return selectedCount > 0 && selectedCount < topic.subtopics.length;
  }

  void toggleTopic(String topicId) {
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic == null) return;

    if (isTopicFullySelected(topicId)) {
      // Deselect all subtopics of this topic
      for (final s in topic.subtopics) {
        selectedSubtopicIds.remove(s.id);
      }
    } else {
      // Select all subtopics of this topic
      for (final s in topic.subtopics) {
        selectedSubtopicIds.add(s.id);
      }
      selectedTopicId.value = topicId;
    }
  }

  void toggleSubtopic(String subtopicId) {
    if (selectedSubtopicIds.contains(subtopicId)) {
      selectedSubtopicIds.remove(subtopicId);
    } else {
      selectedSubtopicIds.add(subtopicId);
    }
  }

  void selectAllCurrentSubject() {
    final allSubIds = currentSubjectTopics.expand((t) => t.subtopics.map((s) => s.id)).toSet();
    selectedSubtopicIds.addAll(allSubIds);
  }

  void clearSelection() {
    selectedSubtopicIds.clear();
  }

  /// Called from Topics screen to directly preselect a topic with all its subtopics
  void preselectTopic({required String subjectId, required String topicId}) {
    selectionMode.value = PracticeSelectionMode.specific;
    _pendingSubjectId = subjectId;
    _pendingTopicId = topicId;

    if (!isLoading.value && liveTopics.isNotEmpty) {
      applyPendingPreselection();
    }
  }

  void applyPendingPreselection() {
    if (_pendingTopicId == null) return;

    final targetTopic = liveTopics.firstWhereOrNull((t) => t.topicId == _pendingTopicId);
    if (targetTopic != null) {
      selectedSubjectId.value = targetTopic.subjectId;
      selectedTopicId.value = targetTopic.topicId;
      selectedSubtopicIds.assignAll(targetTopic.subtopics.map((s) => s.id));
    } else if (liveTopics.isNotEmpty) {
      // Fallback: match by subject or default to first
      selectedSubjectId.value = _pendingSubjectId ?? liveTopics.first.subjectId;
      selectedTopicId.value = liveTopics.first.topicId;
      selectedSubtopicIds.assignAll(liveTopics.first.subtopics.map((s) => s.id));
    }

    _pendingSubjectId = null;
    _pendingTopicId = null;
  }

  void _showNotice(String title, String message, {bool isError = false}) {
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: isError ? Colors.redAccent : Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isError ? Colors.redAccent.withValues(alpha: 0.9) : Colors.black87,
        colorText: Colors.white,
      );
    }
  }

  Future<void> startPracticeSession() async {
    isStartingSession.value = true;
    try {
      PracticeSessionModel session;

      if (selectionMode.value == PracticeSelectionMode.random) {
        // Mode 1: Random drill across all live content
        session = await _repository.createSession();
      } else {
        // Mode 2: Specific drill with user's tailored selection
        if (selectedSubtopicIds.isEmpty) {
          _showNotice('Selection Required', 'Please select at least one subtopic or topic to practice.');
          isStartingSession.value = false;
          return;
        }

        session = await _repository.createSession(
          topicId: selectedTopicId.value.isNotEmpty ? selectedTopicId.value : null,
          subtopicIds: selectedSubtopicIds.toList(),
        );
      }

      debugPrint('[Practice] Session created: ${session.id}, totalQuestions: ${session.totalQuestions}');

      // Clean up previous session controller if still in memory
      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }

      // Navigate to the practice session screen using the AppRouter Navigator
      debugPrint('[Practice] Navigating to PracticeSessionScreen...');
      final nav = AppRouter.navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => PracticeSessionScreen(initialSession: session),
          ),
        );
      } else {
        Get.to(() => PracticeSessionScreen(initialSession: session));
      }
    } catch (err, stack) {
      debugPrint('[Practice] startPracticeSession failed: $err\n$stack');
      _showNotice('Session Failed', err.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      isStartingSession.value = false;
    }
  }

  /// Fetches practice history including replays and PvP replays
  Future<void> fetchHistory({bool refresh = false}) async {
    isLoadingHistory.value = true;
    try {
      final res = await _repository.getHistory(page: 1, limit: 20);
      historyList.assignAll(res.history);
      historyCompletedDrills.value = res.completedDrillsCount;
      historyOverallAccuracy.value = res.overallAccuracy;
      historyAvgResponseTimeMs.value = res.avgResponseTimeMs;
    } catch (e) {
      debugPrint('[Practice] fetchHistory error: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Replays a past practice drill with 0 rewards
  Future<void> replayPracticeSession(String sessionId) async {
    isReplaying.value = true;
    try {
      final session = await _repository.replaySession(sessionId);

      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }

      final nav = AppRouter.navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => PracticeSessionScreen(initialSession: session),
          ),
        );
      } else {
        Get.to(() => PracticeSessionScreen(initialSession: session));
      }
    } catch (e) {
      _showNotice('Replay Failed', e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      isReplaying.value = false;
    }
  }
}
