import 'package:uuid/uuid.dart';
import '../../social/friends_screen.dart';
import '../../social/social_controller.dart';
import 'dart:convert';
import 'dart:async';
import '../../../core/network/dio_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/practice_models.dart';
import '../repositories/practice_repository.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import 'practice_session_controller.dart';

enum PracticeSelectionMode { random, specific }

class PracticeCatalogController extends GetxController {
  final PracticeRepository _repository;

  PracticeCatalogController({PracticeRepository? repository})
    : _repository = repository ?? PracticeRepository();

  final Rx<PracticeSelectionMode> selectionMode =
      PracticeSelectionMode.random.obs;
  final RxBool isLoading = true.obs;
  final RxBool isStartingSession = false.obs;
  final RxList<LiveTopicModel> liveTopics = <LiveTopicModel>[].obs;
  final RxSet<String> selectedSubtopicIds = <String>{}.obs;
  final RxString selectedSubjectId = ''.obs;
  final RxString selectedTopicId = ''.obs;
  final RxString errorMessage = ''.obs;

  final friendlyDuel = false.obs;
  final RxBool smartPicks = false.obs;
  final RxBool timerEnabled = false.obs;
  final RxBool showHistory = false.obs;
  final List<Worker> _preferenceWorkers = [];
  Future<void> _writes = Future.value();

  Future<void> _initialize() async {
    final storage = Get.find<DioClient>().secureStorage;
    try {
      final raw = await storage.read(key: 'practice_preferences_v2');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        smartPicks.value = data['smartPicks'] == true;
        timerEnabled.value = data['timerEnabled'] == true;
        selectionMode.value = data['custom'] == true
            ? PracticeSelectionMode.specific
            : PracticeSelectionMode.random;
        selectedSubjectId.value = data['subject'] as String? ?? '';
        selectedSubtopicIds.assignAll(
          (data['subtopics'] as List?)?.cast<String>() ?? [],
        );
      }
    } catch (e) {
      debugPrint('Practice preferences could not be restored: $e');
    }
    if (isClosed) return;
    await fetchLiveTopics();
    if (isClosed) return;
    for (final value in <RxInterface<dynamic>>[
      smartPicks,
      timerEnabled,
      selectionMode,
      selectedSubjectId,
      selectedSubtopicIds,
    ]) {
      _preferenceWorkers.add(ever(value, (_) => _savePreferences()));
    }
  }

  void _savePreferences() {
    final raw = jsonEncode({
      'smartPicks': smartPicks.value,
      'timerEnabled': timerEnabled.value,
      'custom': selectionMode.value == PracticeSelectionMode.specific,
      'subject': selectedSubjectId.value,
      'subtopics': selectedSubtopicIds.toList(),
    });
    _writes = _writes
        .then(
          (_) => Get.find<DioClient>().secureStorage.write(
            key: 'practice_preferences_v2',
            value: raw,
          ),
        )
        .catchError((Object e) {
          debugPrint('Practice preferences could not be saved: $e');
        });
  }

  @override
  void onClose() {
    for (final worker in _preferenceWorkers) {
      worker.dispose();
    }
    super.onClose();
  }

  // History observables
  final RxList<PracticeHistoryItemModel> historyList =
      <PracticeHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs;
  final RxString historyError = ''.obs;
  final RxInt historyCompletedDrills = 0.obs;
  final RxInt historyOverallAccuracy = 0.obs;
  final RxInt historyAvgResponseTimeMs = 0.obs;
  final RxBool isReplaying = false.obs;

  String? _pendingSubjectId;
  String? _pendingTopicId;

  @override
  void onInit() {
    super.onInit();
    _initialize();
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
    return liveTopics
        .where((t) => t.subjectId == selectedSubjectId.value)
        .toList();
  }

  /// Total count of all subtopics across all live topics
  int get totalLiveSubtopicsCount {
    return liveTopics.fold<int>(
      0,
      (sum, topic) => sum + topic.subtopics.length,
    );
  }

  Future<void> fetchLiveTopics() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final topics = await _repository.getLiveTopics();
      if (isClosed) return;
      liveTopics.assignAll(topics);

      if (topics.isNotEmpty) {
        // If there was a pending preselection from Topics screen
        if (_pendingTopicId != null) {
          applyPendingPreselection();
        } else {
          // Default selection for Specific Mode
          if (selectedSubjectId.isEmpty ||
              !topics.any((t) => t.subjectId == selectedSubjectId.value)) {
            selectedSubjectId.value = topics.first.subjectId;
          }
          final available = currentSubjectTopics
              .expand((t) => t.subtopics.map((s) => s.id))
              .toSet();
          selectedSubtopicIds.removeWhere((id) => !available.contains(id));
          selectedTopicId.value = currentSubjectTopics.first.topicId;
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
      final allSubIds = topics
          .expand((t) => t.subtopics.map((s) => s.id))
          .toSet();
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
    final selectedCount = topic.subtopics
        .where((s) => selectedSubtopicIds.contains(s.id))
        .length;
    return selectedCount > 0 && selectedCount < topic.subtopics.length;
  }

  void toggleTopic(String topicId) {
    final topic = liveTopics.firstWhereOrNull((t) => t.topicId == topicId);
    if (topic == null) return;

    final next = selectedSubtopicIds.toSet();
    final ids = topic.subtopics.map((s) => s.id).toSet();
    if (isTopicFullySelected(topicId)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
      selectedTopicId.value = topicId;
    }
    selectedSubtopicIds.assignAll(next);
  }

  void toggleSubtopic(String subtopicId) {
    if (selectedSubtopicIds.contains(subtopicId)) {
      selectedSubtopicIds.remove(subtopicId);
    } else {
      selectedSubtopicIds.add(subtopicId);
    }
  }

  void selectAllCurrentSubject() {
    final allSubIds = currentSubjectTopics
        .expand((t) => t.subtopics.map((s) => s.id))
        .toSet();
    selectedSubtopicIds.assignAll(allSubIds);
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
    selectionMode.value = PracticeSelectionMode.specific;

    final targetTopic = liveTopics.firstWhereOrNull(
      (t) => t.topicId == _pendingTopicId,
    );
    if (targetTopic != null) {
      selectedSubjectId.value = targetTopic.subjectId;
      selectedTopicId.value = targetTopic.topicId;
      selectedSubtopicIds.assignAll(targetTopic.subtopics.map((s) => s.id));
    } else if (liveTopics.isNotEmpty) {
      // Fallback: match by subject or default to first
      selectedSubjectId.value = _pendingSubjectId ?? liveTopics.first.subjectId;
      selectedTopicId.value = liveTopics.first.topicId;
      selectedSubtopicIds.assignAll(
        liveTopics.first.subtopics.map((s) => s.id),
      );
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
        backgroundColor: isError
            ? Colors.redAccent.withValues(alpha: 0.9)
            : Colors.black87,
        colorText: Colors.white,
      );
    }
  }

  Future<void> startPracticeSession() async {
    if (isStartingSession.value || isReplaying.value || isClosed) return;
    isStartingSession.value = true;
    try {
      if (friendlyDuel.value) {
        if (selectionMode.value == PracticeSelectionMode.specific &&
            selectedSubtopicIds.isEmpty) {
          throw Exception('Select at least one subtopic for this duel.');
        }
        final ctx = AppRouter.navigatorKey.currentContext;
        if (ctx == null) return;
        final friend = await Navigator.of(ctx).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => const FriendsScreen(picker: true)),
        );
        if (friend == null || isClosed) return;
        final social = Get.find<SocialController>();
        final result = await social.api.post('duels', {
          'targetId': friend['id'],
          'requestKey': const Uuid().v4(),
          'subtopicIds': selectionMode.value == PracticeSelectionMode.specific
              ? selectedSubtopicIds.toList()
              : <String>[],
          'smartPicks': smartPicks.value,
          'timerEnabled': timerEnabled.value,
        });
        if (isClosed) return;
        await social.syncInbox();
        await AppRouter.router.push('/friendly-duel/${result['id']}?play=1');
        return;
      }
      PracticeSessionModel session;

      if (selectionMode.value == PracticeSelectionMode.random) {
        // Mode 1: Random drill across all live content
        session = await _repository.createSession(
          smartPicks: smartPicks.value,
          timerEnabled: timerEnabled.value,
        );
      } else {
        // Mode 2: Specific drill with user's tailored selection
        if (selectedSubtopicIds.isEmpty) {
          _showNotice(
            'Selection Required',
            'Please select at least one subtopic or topic to practice.',
          );
          isStartingSession.value = false;
          return;
        }

        session = await _repository.createSession(
          subtopicIds: selectedSubtopicIds.toList(),
          smartPicks: smartPicks.value,
          timerEnabled: timerEnabled.value,
        );
      }

      debugPrint(
        '[Practice] Session created: ${session.id}, totalQuestions: ${session.totalQuestions}',
      );

      if (isClosed) return;
      // Clean up previous session controller if still in memory
      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }

      // Navigate to the practice session screen using GoRouter
      debugPrint(
        '[Practice] Navigating to PracticeSessionScreen via GoRouter...',
      );
      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
      if (!isClosed) unawaited(fetchHistory());
    } catch (err, stack) {
      if (friendlyDuel.value &&
          Get.isRegistered<SocialController>() &&
          !isClosed) {
        final social = Get.find<SocialController>();
        await social.syncInbox();
        if (social.activeDuelId.isNotEmpty && !isClosed) {
          await AppRouter.router.push(
            '/friendly-duel/${social.activeDuelId.value}?play=1',
          );
          return;
        }
      }
      debugPrint('[Practice] startPracticeSession failed: $err\n$stack');
      _showNotice(
        'Session Failed',
        err.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      isStartingSession.value = false;
    }
  }

  /// Directly starts a practice session for a specified topic and optional subtopics
  Future<void> startPracticeSessionForTopic({
    required String subjectId,
    required String topicId,
    List<String>? subtopicIds,
  }) async {
    if (isStartingSession.value || isReplaying.value || isClosed) return;
    isStartingSession.value = true;
    _showNotice('Practice Session', 'Preparing your questions...');
    try {
      final session = await _repository.createSession(
        topicId: topicId,
        subtopicIds: subtopicIds,
        smartPicks: smartPicks.value,
        timerEnabled: timerEnabled.value,
      );

      debugPrint(
        '[Practice] Direct session created: ${session.id}, totalQuestions: ${session.totalQuestions}',
      );

      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }

      if (isClosed) return;
      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
      if (!isClosed) unawaited(fetchHistory());
    } catch (err, stack) {
      debugPrint(
        '[Practice] startPracticeSessionForTopic failed: $err\n$stack',
      );
      _showNotice(
        'Practice Notice',
        err.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      isStartingSession.value = false;
    }
  }

  /// Fetches practice history including replays and PvP replays
  Future<void> fetchHistory({bool refresh = false}) async {
    if (isLoadingHistory.value || isClosed) return;
    isLoadingHistory.value = true;
    historyError.value = '';
    try {
      final res = await _repository.getHistory(page: 1, limit: 20);
      if (isClosed) return;
      historyList.assignAll(res.history);
      historyCompletedDrills.value = res.completedDrillsCount;
      historyOverallAccuracy.value = res.overallAccuracy;
      historyAvgResponseTimeMs.value = res.avgResponseTimeMs;
    } catch (e) {
      if (!isClosed) {
        historyError.value = 'History could not be loaded. Please try again.';
      }
      debugPrint('[Practice] fetchHistory error: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  /// Replays a past practice drill with 0 rewards
  Future<void> replayPracticeSession(String sessionId) async {
    if (isReplaying.value || isStartingSession.value || isClosed) return;
    isReplaying.value = true;
    try {
      final session = await _repository.replaySession(
        sessionId,
        timerEnabled: timerEnabled.value,
      );
      if (isClosed) return;

      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }

      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
      if (!isClosed) unawaited(fetchHistory());
    } catch (e) {
      _showNotice(
        'Replay Failed',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      isReplaying.value = false;
    }
  }
}
