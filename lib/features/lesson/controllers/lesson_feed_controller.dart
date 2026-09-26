import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/lesson_node_model.dart';
import '../models/lesson_session_model.dart';
import '../repositories/lesson_repository.dart';
import '../../../core/progression/controllers/xp_controller.dart';

enum FeedStatus { initial, loading, active, submitting, completed, error }

class FeedItem {
  final bool isUser;
  final String text;
  final LessonNodeModel? node;

  FeedItem({
    required this.isUser,
    required this.text,
    this.node,
  });
}

class LessonFeedController extends GetxController {
  final LessonRepository _repository = Get.put(LessonRepository());
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScrollController scrollController = ScrollController();
  final _uuid = const Uuid();

  final Rx<FeedStatus> status = FeedStatus.initial.obs;
  final RxList<FeedItem> feedItems = <FeedItem>[].obs;
  final Rxn<LessonNodeModel> currentNode = Rxn<LessonNodeModel>();
  final Rxn<NextLearningStepModel> nextStep = Rxn<NextLearningStepModel>();
  final Rxn<String> errorMessage = Rxn<String>();

  String? sessionId;
  int stateVersion = 1;
  String? currentScriptSlug;
  String? currentRoadmapStepId;

  Future<void> initLesson({String? scriptSlug, String? roadmapStepId}) async {
    currentScriptSlug = scriptSlug;
    currentRoadmapStepId = roadmapStepId;
    status.value = FeedStatus.loading;
    errorMessage.value = null;
    nextStep.value = null;

    try {
      final session = roadmapStepId != null
          ? await _repository.startOrResumeSessionByStep(
              roadmapStepId: roadmapStepId,
              clientActionId: _uuid.v4(),
            )
          : await _repository.startOrResumeSession(
              scriptSlug: scriptSlug,
              roadmapStepId: roadmapStepId,
              clientActionId: _uuid.v4(),
            );

      _applySession(session);
      await _saveCheckpoint(session);
      status.value = session.isCompleted ? FeedStatus.completed : FeedStatus.active;
    } catch (e) {
      errorMessage.value = e.toString();
      status.value = FeedStatus.error;
    }
  }

  Future<void> submitAction({
    required String actionType,
    String? actionId,
    String? answer,
    String? userDisplayText,
    int? responseTimeMs,
  }) async {
    if (status.value == FeedStatus.submitting || sessionId == null) return;
    status.value = FeedStatus.submitting;

    // Display user answer in chat immediately
    if (userDisplayText != null && userDisplayText.isNotEmpty) {
      feedItems.add(FeedItem(isUser: true, text: userDisplayText));
      _scrollToBottom();
    }

    try {
      final response = await _repository.submitAction(
        sessionId: sessionId!,
        clientActionId: _uuid.v4(),
        stateVersion: stateVersion,
        currentNodeId: currentNode.value!.id,
        actionType: actionType,
        actionId: actionId,
        answer: answer,
        responseTimeMs: responseTimeMs,
      );

      if (response.evaluation != null &&
          response.evaluation!.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        feedItems.add(FeedItem(
          isUser: false,
          text: response.evaluation!.explanation!,
        ));
      }

      _applySession(response);
      await _saveCheckpoint(response);

      // Synchronize XP and trigger Level-Up celebration if occurred
      if (response.xp != null && Get.isRegistered<XpController>()) {
        Get.find<XpController>().handleXpUpdate(
          xp: response.xp!,
          levelUp: response.levelUp,
        );
      }

      if (response.isCompleted) {
        status.value = FeedStatus.completed;
      } else {
        status.value = FeedStatus.active;
      }
    } catch (e) {
      errorMessage.value = 'Failed to submit response. Tap to retry.';
      status.value = FeedStatus.error;
    }
  }

  Future<String> submitDoubt(String questionText) async {
    if (sessionId == null || currentNode.value == null) {
      return 'Session not active.';
    }

    try {
      return await _repository.submitInterrupt(
        sessionId: sessionId!,
        clientActionId: _uuid.v4(),
        currentNodeId: currentNode.value!.id,
        questionText: questionText,
      );
    } catch (e) {
      return 'AI Tutor doubt service is currently unreachable.';
    }
  }

  void _applySession(LessonSessionModel session) {
    sessionId = session.id;
    stateVersion = session.stateVersion;
    currentNode.value = session.currentNode;
    if (session.next != null) {
      nextStep.value = session.next;
    }
    if (session.roadmapStepId != null) {
      currentRoadmapStepId = session.roadmapStepId;
    }

    // Add tutor message to feed
    feedItems.add(FeedItem(
      isUser: false,
      text: session.currentNode.text,
      node: session.currentNode,
    ));

    _scrollToBottom();
  }

  Future<void> _saveCheckpoint(LessonSessionModel session) async {
    final checkpoint = {
      'sessionId': session.id,
      'stateVersion': session.stateVersion,
      'nodeId': session.currentNode.id,
      'scriptSlug': currentScriptSlug,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _storage.write(
      key: 'checkpoint_${session.scriptId}',
      value: jsonEncode(checkpoint),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
