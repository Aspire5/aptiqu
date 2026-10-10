import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../models/roadmap_model.dart';
import '../../repositories/roadmap_repository.dart';
import '../../../lesson/models/lesson_session_model.dart';
import '../../../lesson/models/lesson_node_model.dart';
import '../../../lesson/repositories/lesson_repository.dart';
import '../../../../core/progression/controllers/xp_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

enum MessageSender { ai, user }

enum QuestionInputType { none, select, text, voice, scan }

enum QuestionDifficultyLevel { easy, medium, hard }

enum QuestionModeType { practice, unranked, ranked }

extension QuestionDifficultyLevelExt on QuestionDifficultyLevel {
  String get displayName {
    switch (this) {
      case QuestionDifficultyLevel.easy:
        return 'Easy';
      case QuestionDifficultyLevel.medium:
        return 'Medium';
      case QuestionDifficultyLevel.hard:
        return 'Hard';
    }
  }

  static QuestionDifficultyLevel fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'MEDIUM':
        return QuestionDifficultyLevel.medium;
      case 'HARD':
        return QuestionDifficultyLevel.hard;
      case 'EASY':
      default:
        return QuestionDifficultyLevel.easy;
    }
  }
}

extension QuestionModeTypeExt on QuestionModeType {
  String get displayName {
    switch (this) {
      case QuestionModeType.practice:
        return 'Practice';
      case QuestionModeType.unranked:
        return 'Unranked';
      case QuestionModeType.ranked:
        return 'Ranked';
    }
  }

  static QuestionModeType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'UNRANKED':
        return QuestionModeType.unranked;
      case 'RANKED':
        return QuestionModeType.ranked;
      case 'PRACTICE':
      default:
        return QuestionModeType.practice;
    }
  }
}

/// Unified Question Model supporting Select, Text, Voice, and Scan
class QuestionData {
  final String title;
  final String desc;
  final String difficulty;
  final QuestionInputType inputType;
  final List<String> options;
  final List<String> optionIds;
  final int? correctOptionIndex;
  final String? placeholder;
  final QuestionModeType questionType;
  final QuestionDifficultyLevel difficultyLevel;
  final int xp;
  final List<String> hints;
  int revealedHintsCount;
  int? selectedOptionIndex;
  String? submittedText;
  bool isCompleted;
  bool hasEvaluated;
  bool? isUserCorrect;
  String? correctOptionId;

  QuestionData({
    required this.title,
    required this.desc,
    this.difficulty = 'Easy',
    required this.inputType,
    this.options = const [],
    this.optionIds = const [],
    this.correctOptionIndex,
    this.placeholder,
    this.questionType = QuestionModeType.practice,
    this.difficultyLevel = QuestionDifficultyLevel.easy,
    int? xp,
    this.hints = const [],
    this.revealedHintsCount = 0,
    this.selectedOptionIndex,
    this.submittedText,
    this.isCompleted = false,
    this.hasEvaluated = false,
    this.isUserCorrect,
    this.correctOptionId,
  }) : xp = xp ?? QuestionInlineModel.calculateQuestionXp(questionType.name, difficultyLevel.name);
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
  final bool hasContinueAction;
  final bool isThinking;
  bool isContinueCompleted;

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
    this.hasContinueAction = false,
    this.isThinking = false,
    this.isContinueCompleted = false,
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
    if (selectedSubjectId.isNotEmpty) {
      fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
    }
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
  final RxString activeRoadmapStepId = ''.obs;
  final RxString activeScriptTitle = ''.obs;
  final RxInt activeScriptSequence = 1.obs;
  final RxBool isLessonActive = false.obs;
  final RxBool isSubmittingAction = false.obs;
  int _conversationGeneration = 0;
  GlobalKey latestAiMessageKey = GlobalKey();
  String? targetedMessageId;

  // Subject Card Selection Overlay (active on fresh login/boot until a subject is played)
  final RxBool showSubjectCards = true.obs;

  void playSubject(RoadmapSubjectSummary subject) {
    selectedSubjectId.value = subject.id;
    showSubjectCards.value = false;
    final stepId = subject.activeStepId;
    if (stepId != null && stepId.isNotEmpty) {
      activeRoadmapStepId.value = stepId;
      loadLessonState(stepId);
    } else {
      fetchSubjectMap(subject.id, updateLessonState: true);
    }
  }

  void viewSubjectDetails(RoadmapSubjectSummary subject) {
    selectedSubjectId.value = subject.id;
    selectedNavIndex.value = 1;
    fetchSubjectMap(subject.id, updateLessonState: false);
  }

  void exitToSubjectCards() {
    _conversationGeneration++;
    messages.removeWhere((message) => message.isThinking);
    isSubmittingAction.value = false;
    showSubjectCards.value = true;
    fetchActiveRoadmap();
  }

  @override
  void onInit() {
    super.onInit();
    _loadInitialConversation();
    fetchActiveRoadmap();
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().fetchUserProfile();
    }
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
        await fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
      }
    } catch (e) {
      roadmapError.value = e.toString();
    }
  }

  Future<void> selectSubject(String subjectId) async {
    selectedSubjectId.value = subjectId;
    await fetchSubjectMap(subjectId, updateLessonState: false);
  }

  Future<void> fetchSubjectMap(String subjectId, {bool updateLessonState = true}) async {
    if (activeRoadmap.value == null) return;
    try {
      isLoadingMap.value = true;
      roadmapError.value = null;
      final map = await roadmapRepo.getSubjectLearningMap(
        roadmapId: activeRoadmap.value!.id,
        subjectId: subjectId,
      );
      subjectLearningMap.value = map;

      if (updateLessonState) {
        final availableTopic = map.topics.firstWhereOrNull(
          (t) => t.isAvailable || t.isInProgress,
        );
        final stepId = availableTopic?.roadmapStepId;
        if (stepId == null) {
          roadmapError.value = 'No lessons available for this topic yet.';
          activeRoadmapStepId.value = '';
          return;
        }
        activeRoadmapStepId.value = stepId;

        await loadLessonState(stepId);
      }
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
        _clearConversation();

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
                question: null,
                node: item.node,
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
    _clearConversation();

    final displayTitle = title ?? activeScriptTitle.value;
    final cleanTitle =
        displayTitle.isNotEmpty ? displayTitle : 'The Four Basics';
    final subDesc = desc ?? 'Ready to jump into today\'s session?';

    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final rawName = auth?.currentUser.value?.firstName.trim();
    final greeting = (rawName != null && rawName.isNotEmpty) ? 'Hey $rawName' : 'Welcome to AptiQu';

    messages.add(
      ChatMessageModel(
        id: 'msg_1',
        sender: MessageSender.ai,
        text:
            '$greeting! 👋\n\n$subDesc\n\nWe\'ll build speed and mental shortcuts step by step.\n\nReady to begin playing?',
        time: 'Just now',
        question: QuestionData(
          title: 'SECTION #$activeScriptSequence',
          desc: cleanTitle,
          difficulty: 'Beginner • 8 min',
          inputType: QuestionInputType.select,
          options: ["🚀 Start Playing", 'Back to Subjects'],
        ),
      ),
    );
  }

  /// Appends an interactive lesson node to the Home playground
  void _addNodeToPlayground(LessonNodeModel node, {bool updateKey = true}) {
    QuestionData? questionData;
    bool hasContinueAction = false;

    if (node.isCompletion) {
      questionData = QuestionData(
        title: 'SECTION COMPLETED',
        desc: '🎉 You completed this section! Great job.',
        difficulty: 'Milestone',
        inputType: QuestionInputType.select,
        options: ['Continue Playing →', 'Back to Subjects'],
      );
    } else if (node.isChoice || node.isQuestion) {
      final options = node.choiceOptions.isNotEmpty
          ? node.choiceOptions.map((o) => o.label).toList()
          : (node.inlineQuestion?.options.map((o) => o.label).toList() ??
              ['Continue →']);
      final optionIds = node.choiceOptions.isNotEmpty
          ? node.choiceOptions.map((o) => o.id).toList()
          : (node.inlineQuestion?.options.map((o) => o.id).toList() ??
              ['opt_continue']);

      final qType = QuestionModeTypeExt.fromString(node.questionType);
      final diffLevel = QuestionDifficultyLevelExt.fromString(node.difficulty);

      questionData = QuestionData(
        title: qType.displayName.toUpperCase(),
        desc: node.inlineQuestion?.prompt ?? node.text,
        difficulty: diffLevel.displayName,
        inputType: QuestionInputType.select,
        options: options,
        optionIds: optionIds,
        questionType: qType,
        difficultyLevel: diffLevel,
        xp: node.xp,
        hints: node.hints,
      );
    } else if (node.isTextInput) {
      questionData = QuestionData(
        title: 'TYPE ANSWER',
        desc: node.text,
        placeholder: node.inputPlaceholder ?? 'Type your answer here...',
        inputType: QuestionInputType.text,
      );
    } else {
      // CONTENT node -> embedded "Continue →" action button within the same message container!
      questionData = null;
      hasContinueAction = true;
    }

    final messageId = 'node_${node.id}_${DateTime.now().millisecondsSinceEpoch}';
    if (updateKey) {
      latestAiMessageKey = GlobalKey();
      targetedMessageId = messageId;
    }
    messages.add(
      ChatMessageModel(
        id: messageId,
        sender: MessageSender.ai,
        text: node.text,
        time: _getCurrentTime(),
        question: questionData,
        node: node,
        hasContinueAction: hasContinueAction,
        isContinueCompleted: false,
      ),
    );
    if (updateKey) {
      _scrollToNewMessage();
    }
  }

  void _addCompletionToPlayground(LessonSessionModel response, {bool updateKey = true}) {
    final next = response.next;
    final currentSubject = subjects.firstWhereOrNull((s) => s.id == selectedSubjectId.value);
    final currentSubjectName = currentSubject?.name ?? 'Subject';

    String completionTitle = 'SECTION COMPLETED';
    String completionDesc = 'Completed: ${activeScriptTitle.value}';
    String aiCelebrationText = '🎉 Outstanding work! You have finished this section.';
    List<String> options = [];

    if (next != null && next.available && next.roadmapStepId != null) {
      final isDifferentSubject = next.subjectId != null && next.subjectId != selectedSubjectId.value;

      if (isDifferentSubject) {
        completionTitle = 'SUBJECT COMPLETED';
        final nextSubjName = next.subjectName ?? next.topicName ?? 'Next Subject';
        completionDesc = 'All topics in $currentSubjectName completed!\nUp next: $nextSubjName';
        aiCelebrationText = '🏆 Incredible! You have completed all active topics in $currentSubjectName.';
        options = [
          'Continue Playing: $nextSubjName →',
          'Back to Subjects',
        ];
      } else {
        final nextTopicTitle = next.topicName ?? 'Next Topic';
        final nextSecTitle = next.scriptTitle ?? nextTopicTitle;
        completionTitle = 'TOPIC SECTION COMPLETED';
        completionDesc = 'Up next: $nextSecTitle';
        options = [
          'Continue Playing: $nextSecTitle →',
          'Back to Subjects',
        ];
      }
    } else {
      completionTitle = 'SUBJECT COMPLETED';
      completionDesc = 'You have completed all available topics in $currentSubjectName!';
      aiCelebrationText = '🏆 Mastered! You have completed all currently active topics in $currentSubjectName.';
      options = [
        'Back to Subjects',
        'Explore Practice Arena',
      ];
    }

    final messageId = 'completion_${DateTime.now().millisecondsSinceEpoch}';
    if (updateKey) {
      latestAiMessageKey = GlobalKey();
      targetedMessageId = messageId;
    }
    messages.add(
      ChatMessageModel(
        id: messageId,
        sender: MessageSender.ai,
        text: aiCelebrationText,
        time: _getCurrentTime(),
        question: QuestionData(
          title: completionTitle,
          desc: completionDesc,
          difficulty: 'Completed',
          inputType: QuestionInputType.select,
          options: options,
        ),
      ),
    );
    if (updateKey) {
      _scrollToNewMessage();
    }
  }

  /// Handle option selection (InputType.select)
  Future<void> handleOptionSelection(String messageId, int optionIndex) async {
    if (isSubmittingAction.value) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;
    if (optionIndex < 0 || optionIndex >= q.options.length) return;

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
        final generation = _conversationGeneration;
        final thinkingStarted = Stopwatch()..start();
        final thinkingId = _showThinking();
        try {
          final session = await lessonRepo.startOrResumeSessionByStep(
            roadmapStepId: activeRoadmapStepId.value,
            clientActionId: _uuid.v4(),
          );
          if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
            return;
          }
          currentSession.value = session;
          isLessonActive.value = true;
          activeScriptTitle.value =
              session.scriptTitle ?? activeScriptTitle.value;
          _addNodeToPlayground(session.currentNode);
        } catch (e) {
          _removeThinking(thinkingId);
          if (_conversationGeneration != generation) return;
          q.isCompleted = false;
          q.selectedOptionIndex = null;
          messages.refresh();
          messages.add(
            ChatMessageModel(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.ai,
              text:
                  'Unable to start playing right now. Please check your connection and tap Start Playing again.',
              time: _getCurrentTime(),
            ),
          );
        } finally {
          if (_conversationGeneration == generation) {
            isSubmittingAction.value = false;
          }
        }
      } else {
        exitToSubjectCards();
      }
      return;
    }

    // 2. Next Lesson button on completion card
    if (q.title == 'SECTION COMPLETED' ||
        q.title == 'TOPIC SECTION COMPLETED' ||
        q.title == 'TOPIC COMPLETED' ||
        q.title == 'SUBJECT COMPLETED' ||
        q.title == 'LESSON COMPLETE') {
      q.selectedOptionIndex = optionIndex;
      q.isCompleted = true;
      messages.refresh();

      if (selectedText == 'Back to Subjects') {
        exitToSubjectCards();
        return;
      }

      if (selectedText == 'Explore Practice Arena') {
        selectedNavIndex.value = 2;
        return;
      }

      final next = currentSession.value?.next;
      if (next != null && next.available && next.roadmapStepId != null) {
        if (next.subjectId != null && next.subjectId != selectedSubjectId.value) {
          selectedSubjectId.value = next.subjectId!;
        }
        activeRoadmapStepId.value = next.roadmapStepId!;
        await startNextLesson(stepId: next.roadmapStepId!);
      } else {
        exitToSubjectCards();
      }
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
    final generation = _conversationGeneration;
    final thinkingStarted = Stopwatch()..start();
    final thinkingId = _showThinking();
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

      if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
        return;
      }

      currentSession.value = response;

      // Synchronize XP and trigger Level-Up celebration if occurred
      if (response.xp != null && Get.isRegistered<XpController>()) {
        Get.find<XpController>().handleXpUpdate(
          xp: response.xp!,
          levelUp: response.levelUp,
        );
      }

      // Evaluation results for option feedback (green check / red cross)
      if (response.evaluation != null) {
        q.hasEvaluated = true;
        q.isUserCorrect = response.evaluation!.isCorrect;
        q.correctOptionId = response.evaluation!.correctOptionId;
        messages.refresh();
      }

      // Evaluation explanation if present
      bool hasExplanation = false;
      if (response.evaluation?.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        hasExplanation = true;
        final evalId = 'eval_${DateTime.now().millisecondsSinceEpoch}';
        latestAiMessageKey = GlobalKey();
        targetedMessageId = evalId;
        messages.add(
          ChatMessageModel(
            id: evalId,
            sender: MessageSender.ai,
            text: response.evaluation!.explanation!,
            time: _getCurrentTime(),
            isCorrect: response.evaluation!.isCorrect,
          ),
        );
      }

      if (response.isCompleted) {
        _addCompletionToPlayground(response, updateKey: !hasExplanation);
        if (selectedSubjectId.isNotEmpty) {
          fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
        }
      } else {
        _addNodeToPlayground(response.currentNode, updateKey: !hasExplanation);
      }
      _scrollToNewMessage();
    } catch (e) {
      _removeThinking(thinkingId);
      if (_conversationGeneration != generation) return;
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
      if (_conversationGeneration == generation) {
        isSubmittingAction.value = false;
      }
    }
  }

  /// Starts the next lesson and clears the playground
  Future<void> startNextLesson({String? stepId}) async {
    _clearConversation();
    final generation = _conversationGeneration;
    final thinkingStarted = Stopwatch()..start();
    final thinkingId = _showThinking();
    try {
      final targetStep = stepId ?? activeRoadmapStepId.value;
      activeRoadmapStepId.value = targetStep;

      final session = await lessonRepo.startOrResumeSessionByStep(
        roadmapStepId: targetStep,
        clientActionId: _uuid.v4(),
      );
      if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
        return;
      }
      currentSession.value = session;
      activeScriptTitle.value = session.scriptTitle ?? 'Playing';
      isLessonActive.value = true;
      _addNodeToPlayground(session.currentNode);
      if (selectedSubjectId.isNotEmpty) {
        fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
      }
    } catch (e) {
      _removeThinking(thinkingId);
      if (_conversationGeneration != generation) return;
      exitToSubjectCards();
    }
  }

  /// Handle Continue button embedded inside the AI message bubble
  Future<void> handleContinueAction(String messageId) async {
    if (isSubmittingAction.value) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final msg = messages[msgIndex];
    if (msg.isContinueCompleted) return;
    if (currentSession.value == null) return;

    msg.isContinueCompleted = true;
    messages.refresh();

    // User message bubble "Continue →"
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: 'Continue →',
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    final session = currentSession.value!;
    final node = session.currentNode;

    isSubmittingAction.value = true;
    final generation = _conversationGeneration;
    final thinkingStarted = Stopwatch()..start();
    final thinkingId = _showThinking();
    try {
      final response = await lessonRepo.submitAction(
        sessionId: session.id,
        clientActionId: _uuid.v4(),
        stateVersion: session.stateVersion,
        currentNodeId: node.id,
        actionType: 'CONTINUE',
      );

      if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
        return;
      }

      currentSession.value = response;

      // Synchronize XP and trigger Level-Up celebration if occurred
      if (response.xp != null && Get.isRegistered<XpController>()) {
        Get.find<XpController>().handleXpUpdate(
          xp: response.xp!,
          levelUp: response.levelUp,
        );
      }

      bool hasExplanation = false;
      if (response.evaluation?.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        hasExplanation = true;
        final evalId = 'eval_${DateTime.now().millisecondsSinceEpoch}';
        latestAiMessageKey = GlobalKey();
        targetedMessageId = evalId;
        messages.add(
          ChatMessageModel(
            id: evalId,
            sender: MessageSender.ai,
            text: response.evaluation!.explanation!,
            time: _getCurrentTime(),
            isCorrect: response.evaluation!.isCorrect,
          ),
        );
      }

      if (response.isCompleted) {
        _addCompletionToPlayground(response, updateKey: !hasExplanation);
        if (selectedSubjectId.isNotEmpty) {
          fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
        }
      } else {
        _addNodeToPlayground(response.currentNode, updateKey: !hasExplanation);
      }
      _scrollToNewMessage();
    } catch (e) {
      _removeThinking(thinkingId);
      if (_conversationGeneration != generation) return;
      msg.isContinueCompleted = false;
      messages.refresh();
      messages.add(
        ChatMessageModel(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text: 'Connection hiccup. Please tap Continue again.',
          time: _getCurrentTime(),
        ),
      );
    } finally {
      if (_conversationGeneration == generation) {
        isSubmittingAction.value = false;
      }
    }
  }

  /// Start or replay a specific subtopic lesson
  Future<void> startSubtopicLesson({
    required String roadmapStepId,
    String? scriptSlug,
    String? scriptTitle,
    bool restart = true,
  }) async {
    selectedNavIndex.value = 0; // Switch directly to Home tab
    showSubjectCards.value = false;
    _clearConversation();
    currentSession.value = null;
    isLessonActive.value = false;
    activeRoadmapStepId.value = roadmapStepId;
    activeScriptTitle.value = scriptTitle ?? 'Playing';
    targetedMessageId = null;
    isSubmittingAction.value = true;
    final generation = _conversationGeneration;
    final thinkingStarted = Stopwatch()..start();
    final thinkingId = _showThinking();
    try {
      final session = await lessonRepo.startOrResumeSessionByStep(
        roadmapStepId: roadmapStepId,
        clientActionId: _uuid.v4(),
        scriptSlug: scriptSlug,
        restart: restart,
      );
      if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
        return;
      }
      currentSession.value = session;
      isLessonActive.value = true;
      activeScriptTitle.value = session.scriptTitle ?? (scriptTitle ?? 'Playing');
      _addNodeToPlayground(session.currentNode);
      if (selectedSubjectId.isNotEmpty) {
        fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
      }
    } catch (e) {
      _removeThinking(thinkingId);
      if (_conversationGeneration != generation) return;
      messages.add(
        ChatMessageModel(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text: 'Unable to start this subtopic script. Please try again.',
          time: _getCurrentTime(),
        ),
      );
    } finally {
      if (_conversationGeneration == generation) {
        isSubmittingAction.value = false;
      }
    }
  }

  /// Handle Text Submission (InputType.text)
  Future<void> handleTextSubmission(String messageId, String text) async {
    if (text.trim().isEmpty || isSubmittingAction.value) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;
    if (currentSession.value == null) return;

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

    final session = currentSession.value!;
    final node = session.currentNode;

    isSubmittingAction.value = true;
    final generation = _conversationGeneration;
    final thinkingStarted = Stopwatch()..start();
    final thinkingId = _showThinking();
    try {
      final response = await lessonRepo.submitAction(
        sessionId: session.id,
        clientActionId: _uuid.v4(),
        stateVersion: session.stateVersion,
        currentNodeId: node.id,
        actionType: 'TEXT_INPUT',
        answer: text.trim(),
      );

      if (!await _finishThinking(thinkingId, thinkingStarted, generation)) {
        return;
      }

      currentSession.value = response;

      // Synchronize XP and trigger Level-Up celebration if occurred
      if (response.xp != null && Get.isRegistered<XpController>()) {
        Get.find<XpController>().handleXpUpdate(
          xp: response.xp!,
          levelUp: response.levelUp,
        );
      }

      bool hasExplanation = false;
      if (response.evaluation?.explanation != null &&
          response.evaluation!.explanation!.isNotEmpty) {
        hasExplanation = true;
        final evalId = 'eval_${DateTime.now().millisecondsSinceEpoch}';
        latestAiMessageKey = GlobalKey();
        targetedMessageId = evalId;
        messages.add(
          ChatMessageModel(
            id: evalId,
            sender: MessageSender.ai,
            text: response.evaluation!.explanation!,
            time: _getCurrentTime(),
            isCorrect: response.evaluation!.isCorrect,
          ),
        );
      }

      if (response.isCompleted) {
        _addCompletionToPlayground(response, updateKey: !hasExplanation);
        if (selectedSubjectId.isNotEmpty) {
          fetchSubjectMap(selectedSubjectId.value, updateLessonState: false);
        }
      } else {
        _addNodeToPlayground(response.currentNode, updateKey: !hasExplanation);
      }
      _scrollToNewMessage();
    } catch (e) {
      _removeThinking(thinkingId);
      if (_conversationGeneration != generation) return;
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
      if (_conversationGeneration == generation) {
        isSubmittingAction.value = false;
      }
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
    if (topic.isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming Soon: Content for "${topic.topicName}" is currently being prepared.',
          ),
          backgroundColor: AptiquColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      activeRoadmapStepId.value = topic.roadmapStepId;
      showSubjectCards.value = false;
      selectedNavIndex.value = 0; // Go directly to Home playground!
      final firstSubtopic =
          topic.subtopics.isNotEmpty ? topic.subtopics.first : null;
      startSubtopicLesson(
        roadmapStepId: topic.roadmapStepId,
        scriptSlug: firstSubtopic?.scriptSlug,
        scriptTitle: firstSubtopic?.title ?? topic.topicName,
        restart: true,
      );
    }
  }

  void _scrollToNewMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void performScroll() {
        final keyContext = latestAiMessageKey.currentContext;
        if (keyContext != null && keyContext.mounted) {
          Scrollable.ensureVisible(
            keyContext,
            alignment: 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        } else if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }

      if (latestAiMessageKey.currentContext?.mounted == true) {
        performScroll();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
      }
    });
  }

  void _clearConversation() {
    _conversationGeneration++;
    isSubmittingAction.value = false;
    messages.clear();
  }

  String _showThinking() {
    final id = 'thinking_${_uuid.v4()}';
    messages.add(ChatMessageModel(
      id: id,
      sender: MessageSender.ai,
      text: 'Thinking...',
      time: '',
      isThinking: true,
    ));
    _scrollToBottom();
    return id;
  }

  void _removeThinking(String id) {
    messages.removeWhere((message) => message.id == id);
  }

  Future<bool> _finishThinking(
      String id, Stopwatch timer, int generation) async {
    final remaining = const Duration(milliseconds: 500) - timer.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (_conversationGeneration != generation ||
        !messages.any((message) => message.id == id)) {
      return false;
    }
    _removeThinking(id);
    return true;
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
    _conversationGeneration++;
    scrollController.dispose();
    super.onClose();
  }
}
