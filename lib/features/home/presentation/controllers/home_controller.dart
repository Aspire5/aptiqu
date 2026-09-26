import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../models/roadmap_model.dart';
import '../../repositories/roadmap_repository.dart';
import '../../../lesson/models/lesson_session_model.dart';
import '../../../lesson/models/lesson_node_model.dart';
import '../../../lesson/repositories/lesson_repository.dart';

enum MessageSender { ai, user }

enum QuestionInputType { none, select, text, voice, scan }

/// Unified Question Model supporting Select, Text, Voice, and Scan
class QuestionData {
  final String title;
  final String desc;
  final String difficulty;
  final QuestionInputType inputType;
  final List<String> options;
  final int? correctOptionIndex;
  final String? placeholder;
  int? selectedOptionIndex;
  String? submittedText;
  bool isCompleted;

  QuestionData({
    required this.title,
    required this.desc,
    this.difficulty = 'Intro Drill',
    required this.inputType,
    this.options = const [],
    this.correctOptionIndex,
    this.placeholder,
    this.selectedOptionIndex,
    this.submittedText,
    this.isCompleted = false,
  });
}

class ChatMessageModel {
  final String id;
  final MessageSender sender;
  final String text;
  final String time;
  final bool isTopicDivider;
  final String? topicTitle;
  final QuestionData? question;
  final bool? isCorrect;
  final LessonNodeModel? node;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.isTopicDivider = false,
    this.topicTitle,
    this.question,
    this.isCorrect,
    this.node,
  });
}

/// Controller managing the Home interactive learning playground
class HomeController extends GetxController {
  final scrollController = ScrollController();
  final RxInt selectedNavIndex = 0.obs;
  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;

  // Active step tracker for the offline interactive script
  final RxInt conversationStep = 1.obs;

  // Triggers cinematic zoom-in camera animation on roadmap
  final RxInt topicsTabTapCount = 0.obs;

  // Fullscreen mode for immersive map exploration
  final RxBool isFullScreen = false.obs;

  void selectTopicsTab() {
    selectedNavIndex.value = 1;
    topicsTabTapCount.value++;
  }

  void toggleFullScreen() {
    isFullScreen.value = !isFullScreen.value;
  }

  // Roadmap & Curriculum state
  final RoadmapRepository roadmapRepo = Get.put(RoadmapRepository());
  final LessonRepository lessonRepo = Get.put(LessonRepository());
  final _uuid = const Uuid();

  final Rxn<ActiveRoadmapModel> activeRoadmap = Rxn<ActiveRoadmapModel>();
  final RxList<RoadmapSubjectSummary> subjects = <RoadmapSubjectSummary>[].obs;
  final RxString selectedSubjectId = ''.obs;
  final Rxn<SubjectLearningMapModel> subjectLearningMap =
      Rxn<SubjectLearningMapModel>();
  final RxBool isLoadingMap = false.obs;
  final RxnString roadmapError = RxnString();

  // Active Lesson Session State in the Home Playground
  final Rxn<LessonSessionModel> currentSession = Rxn<LessonSessionModel>();
  final RxString activeRoadmapStepId = 'ga-qa-01'.obs;
  final RxString activeScriptTitle = ''.obs;
  final RxInt activeScriptSequence = 1.obs;
  final RxBool isLessonActive = false.obs;
  final RxBool isSubmittingAction = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialConversation();
    fetchActiveRoadmap();
  }

  Future<void> fetchActiveRoadmap() async {
    try {
      roadmapError.value = null;
      final roadmap = await roadmapRepo.getActiveRoadmap();
      activeRoadmap.value = roadmap;
      subjects.value = roadmap.subjects;

      if (subjects.isNotEmpty) {
        if (selectedSubjectId.isEmpty ||
            !subjects.any((s) => s.id == selectedSubjectId.value)) {
          selectedSubjectId.value = subjects.first.id;
        }
        await fetchSubjectMap(selectedSubjectId.value);
      }
    } catch (e) {
      roadmapError.value = e.toString();
    }
  }

  Future<void> selectSubject(String subjectId) async {
    selectedSubjectId.value = subjectId;
    await fetchSubjectMap(subjectId);
  }

  Future<void> fetchSubjectMap(String subjectId) async {
    if (activeRoadmap.value == null) return;
    try {
      isLoadingMap.value = true;
      roadmapError.value = null;
      final map = await roadmapRepo.getSubjectLearningMap(
        roadmapId: activeRoadmap.value!.id,
        subjectId: subjectId,
      );
      subjectLearningMap.value = map;

      final availableTopic = map.topics.firstWhereOrNull(
        (t) => t.isAvailable || t.isInProgress,
      );
      final stepId = availableTopic?.roadmapStepId ?? 'ga-qa-01';
      activeRoadmapStepId.value = stepId;

      await loadLessonState(stepId);
    } catch (e) {
      roadmapError.value = e.toString();
    } finally {
      isLoadingMap.value = false;
    }
  }

  /// Loads or resumes the active lesson state for the current roadmap step.
  /// If user left a script in progress, it restores the playground to that exact position.
  Future<void> loadLessonState(String stepId) async {
    try {
      activeRoadmapStepId.value = stepId;
      final state = await lessonRepo.getActiveLessonState(stepId);

      if (state.script != null) {
        activeScriptTitle.value = state.script!.title;
        activeScriptSequence.value = state.script!.sequence;
      }

      if (state.hasActiveSession && state.session != null) {
        final session = state.session!;
        currentSession.value = session;
        isLessonActive.value = true;
        messages.clear();

        // Replay history so user continues right where they left off
        for (final item in session.history) {
          if (item.isUser) {
            messages.add(
              ChatMessageModel(
                id: item.id,
                sender: MessageSender.user,
                text: item.text,
                time: '',
              ),
            );
          } else {
            messages.add(
              ChatMessageModel(
                id: item.id,
                sender: MessageSender.ai,
                text: item.text,
                time: '',
                question: item.node != null
                    ? QuestionData(
                        title: 'STEP',
                        desc: item.node!.text,
                        inputType: QuestionInputType.none,
                        isCompleted: true,
                      )
                    : null,
              ),
            );
          }
        }

        // Add current interactive node
        _addNodeToPlayground(session.currentNode);
      } else {
        isLessonActive.value = false;
        currentSession.value = null;
        _loadInitialConversation(
          title: state.script?.title,
          desc: state.script?.description,
        );
      }
    } catch (e) {
      _loadInitialConversation();
    }
  }

  void _loadInitialConversation({String? title, String? desc}) {
    messages.clear();

    final displayTitle = title ?? activeScriptTitle.value;
    final cleanTitle =
        displayTitle.isNotEmpty ? displayTitle : 'The Four Basics';
    final subDesc = desc ?? 'Ready to jump into today\'s lesson?';

    messages.add(
      ChatMessageModel(
        id: 'msg_1',
        sender: MessageSender.ai,
        text:
            'Hey Shagun, welcome to AptiQu! 👋\n\n$subDesc\n\nWe\'ll build speed and mental shortcuts step by step.\n\nReady to begin?',
        time: 'Just now',
        question: QuestionData(
          title: 'LESSON #$activeScriptSequence',
          desc: cleanTitle,
          difficulty: 'Beginner • 8 min',
          inputType: QuestionInputType.select,
          options: ["🚀 Start Lesson", 'Explore Topics'],
        ),
      ),
    );
  }

  /// Appends an interactive lesson node to the Home playground
  void _addNodeToPlayground(LessonNodeModel node) {
    QuestionData? questionData;

    if (node.isCompletion) {
      questionData = QuestionData(
        title: 'LESSON COMPLETE',
        desc: '🎉 You completed this lesson! Great job.',
        difficulty: 'Milestone',
        inputType: QuestionInputType.select,
        options: ['Start Next Lesson →'],
      );
    } else if (node.isChoice || node.isQuestion) {
      final options = node.choiceOptions.isNotEmpty
          ? node.choiceOptions.map((o) => o.label).toList()
          : (node.inlineQuestion?.options.map((o) => o.label).toList() ??
              ['Continue →']);

      questionData = QuestionData(
        title: 'QUICK CHECK',
        desc: node.inlineQuestion?.prompt ?? node.text,
        difficulty: 'Drill',
        inputType: QuestionInputType.select,
        options: options,
      );
    } else if (node.isTextInput) {
      questionData = QuestionData(
        title: 'TYPE ANSWER',
        desc: node.text,
        placeholder: node.inputPlaceholder ?? 'Type your answer here...',
        inputType: QuestionInputType.text,
      );
    } else {
      // CONTENT node -> embedded "Continue →" action button within the container!
      questionData = QuestionData(
        title: 'STEP',
        desc: 'Read the explanation above and tap continue.',
        difficulty: 'Concept',
        inputType: QuestionInputType.select,
        options: ['Continue →'],
      );
    }

    messages.add(
      ChatMessageModel(
        id: 'node_${node.id}_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.ai,
        text: node.text,
        time: _getCurrentTime(),
        question: questionData,
        node: node,
      ),
    );
    _scrollToBottom();
  }

  void _addCompletionToPlayground(LessonSessionModel response) {
    final nextTitle = response.next?.scriptTitle ?? 'Next Lesson';

    messages.add(
      ChatMessageModel(
        id: 'completion_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.ai,
        text: '🎉 Outstanding work! You have finished this lesson.',
        time: _getCurrentTime(),
        question: QuestionData(
          title: 'LESSON COMPLETE',
          desc: 'Completed: ${activeScriptTitle.value} (+10 XP)',
          difficulty: 'Completed',
          inputType: QuestionInputType.select,
          options: ['Start Next Lesson: $nextTitle →'],
        ),
      ),
    );
    _scrollToBottom();
  }

  /// Handle option selection (InputType.select)
  Future<void> handleOptionSelection(String messageId, int optionIndex) async {
    if (isSubmittingAction.value) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    final selectedText = q.options[optionIndex];

    // 1. Initial Start Lesson Card
    if (messageId == 'msg_1') {
      q.selectedOptionIndex = optionIndex;
      q.isCompleted = true;
      messages.refresh();

      messages.add(
        ChatMessageModel(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.user,
          text: selectedText,
          time: _getCurrentTime(),
        ),
      );
      _scrollToBottom();

      if (optionIndex == 0) {
        // Start lesson right in the Home playground!
        isSubmittingAction.value = true;
        try {
          final session = await lessonRepo.startOrResumeSessionByStep(
            roadmapStepId: activeRoadmapStepId.value,
            clientActionId: _uuid.v4(),
          );
          currentSession.value = session;
          isLessonActive.value = true;
          activeScriptTitle.value =
              session.scriptTitle ?? activeScriptTitle.value;
          _addNodeToPlayground(session.currentNode);
        } catch (e) {
          messages.add(
            ChatMessageModel(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.ai,
              text:
                  'Unable to start lesson right now. Please check your connection and tap Start Lesson again.',
              time: _getCurrentTime(),
            ),
          );
        } finally {
          isSubmittingAction.value = false;
        }
      } else {
        selectedNavIndex.value = 1;
      }
      return;
    }

    // 2. Next Lesson button on completion card
    if (q.title == 'LESSON COMPLETE') {
      q.selectedOptionIndex = optionIndex;
      q.isCompleted = true;
      messages.refresh();

      await startNextLesson();
      return;
    }

    // 3. Interactive lesson session node
    if (currentSession.value == null) return;
    final session = currentSession.value!;
    final node = session.currentNode;

    q.selectedOptionIndex = optionIndex;
    q.isCompleted = true;
    messages.refresh();

    // User message bubble
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: selectedText,
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    isSubmittingAction.value = true;
    try {
      String actionType = 'CONTINUE';
      String? actionId;
      String? answer;

      if (node.isChoice || node.isQuestion) {
        actionType = 'CHOICE';
        final options = node.choiceOptions.isNotEmpty
            ? node.choiceOptions
            : (node.inlineQuestion?.options ?? []);

        if (options.isNotEmpty && optionIndex < options.length) {
          actionId = options[optionIndex].id;
          answer = options[optionIndex].id;
        } else {
          actionId = selectedText;
          answer = selectedText;
        }
      }

      final response = await lessonRepo.submitAction(
        sessionId: session.id,
        clientActionId: _uuid.v4(),
        stateVersion: session.stateVersion,
        currentNodeId: node.id,
        actionType: actionType,
        actionId: actionId,
        answer: answer,
      );

      currentSession.value = response;

      // Evaluation explanation if present
      if (response.evaluation?.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        messages.add(
          ChatMessageModel(
            id: 'eval_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.ai,
            text: response.evaluation!.explanation!,
            time: _getCurrentTime(),
            isCorrect: response.evaluation!.isCorrect,
          ),
        );
        _scrollToBottom();
      }

      if (response.isCompleted) {
        _addCompletionToPlayground(response);
      } else {
        _addNodeToPlayground(response.currentNode);
      }
    } catch (e) {
      messages.add(
        ChatMessageModel(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text: 'Connection hiccup. Tap the option again to continue.',
          time: _getCurrentTime(),
        ),
      );
      q.isCompleted = false;
      messages.refresh();
    } finally {
      isSubmittingAction.value = false;
    }
  }

  /// Starts the next lesson script and clears the playground
  Future<void> startNextLesson() async {
    try {
      messages.clear();
      final session = await lessonRepo.startOrResumeSessionByStep(
        roadmapStepId: activeRoadmapStepId.value,
        clientActionId: _uuid.v4(),
      );
      currentSession.value = session;
      activeScriptTitle.value = session.scriptTitle ?? 'Today\'s Lesson';
      isLessonActive.value = true;
      _addNodeToPlayground(session.currentNode);
    } catch (e) {
      await loadLessonState(activeRoadmapStepId.value);
    }
  }

  /// Handle Text Submission (InputType.text)
  Future<void> handleTextSubmission(String messageId, String text) async {
    if (text.trim().isEmpty || isSubmittingAction.value) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.submittedText = text.trim();
    q.isCompleted = true;
    messages.refresh();

    // User message
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: text.trim(),
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    if (currentSession.value == null) return;
    final session = currentSession.value!;
    final node = session.currentNode;

    isSubmittingAction.value = true;
    try {
      final response = await lessonRepo.submitAction(
        sessionId: session.id,
        clientActionId: _uuid.v4(),
        stateVersion: session.stateVersion,
        currentNodeId: node.id,
        actionType: 'TEXT_INPUT',
        answer: text.trim(),
      );

      currentSession.value = response;

      if (response.evaluation?.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        messages.add(
          ChatMessageModel(
            id: 'eval_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.ai,
            text: response.evaluation!.explanation!,
            time: _getCurrentTime(),
            isCorrect: response.evaluation!.isCorrect,
          ),
        );
        _scrollToBottom();
      }

      if (response.isCompleted) {
        _addCompletionToPlayground(response);
      } else {
        _addNodeToPlayground(response.currentNode);
      }
    } catch (e) {
      messages.add(
        ChatMessageModel(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text: 'Connection hiccup. Tap submit again to retry.',
          time: _getCurrentTime(),
        ),
      );
      q.isCompleted = false;
      messages.refresh();
    } finally {
      isSubmittingAction.value = false;
    }
  }

  /// Handle Voice/Viva submission (InputType.voice)
  void handleVoiceSubmission(String messageId) {
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.isCompleted = true;
    messages.refresh();

    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text:
            '🎙️ "Breaking numbers down into smaller parts makes the calculation much easier to do mentally."',
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    if (currentSession.value != null) {
      handleOptionSelection(messageId, 0);
    }
  }

  /// Handle Scan Notes submission (InputType.scan)
  void handleScanSubmission(String messageId) {
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.isCompleted = true;
    messages.refresh();

    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: '📄 [Uploaded Handwritten Solution]',
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    if (currentSession.value != null) {
      handleOptionSelection(messageId, 0);
    }
  }

  /// User taps a topic on the Roadmap map
  void onTopicTapped(BuildContext context, LearningMapTopicItemModel topic) {
    if (topic.isAvailable || topic.isInProgress) {
      activeRoadmapStepId.value = topic.roadmapStepId;
      selectedNavIndex.value = 0; // Go directly to Home playground!
      loadLessonState(topic.roadmapStepId);
    } else if (topic.isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming Soon: Guided lesson for "${topic.topicName}" is currently being prepared.',
          ),
          backgroundColor: AptiquColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (topic.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Topic Locked: Complete preceding topics in your roadmap to unlock "${topic.topicName}".',
          ),
          backgroundColor: AptiquColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 250,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
