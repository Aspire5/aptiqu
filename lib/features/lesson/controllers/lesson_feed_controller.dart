import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/lesson_node_model.dart';
import '../models/lesson_session_model.dart';
import '../repositories/lesson_repository.dart';

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
  final Rxn<String> errorMessage = Rxn<String>();

  String? sessionId;
  int stateVersion = 1;
  String? currentScriptSlug;

  Future<void> initLesson(String scriptSlug) async {
    currentScriptSlug = scriptSlug;
    status.value = FeedStatus.loading;
    errorMessage.value = null;

    try {
      final session = await _repository.startOrResumeSession(
        scriptSlug: scriptSlug,
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

      _applySession(response);
      await _saveCheckpoint(response);

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
