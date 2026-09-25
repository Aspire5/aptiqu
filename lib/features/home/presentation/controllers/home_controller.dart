import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../models/roadmap_model.dart';
import '../../repositories/roadmap_repository.dart';

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

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.isTopicDivider = false,
    this.topicTitle,
    this.question,
  });
}

/// Controller managing the AI-led conversation script and dynamic input interactions
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
  final Rxn<ActiveRoadmapModel> activeRoadmap = Rxn<ActiveRoadmapModel>();
  final RxList<RoadmapSubjectSummary> subjects = <RoadmapSubjectSummary>[].obs;
  final RxString selectedSubjectId = ''.obs;
  final Rxn<SubjectLearningMapModel> subjectLearningMap = Rxn<SubjectLearningMapModel>();
  final RxBool isLoadingMap = false.obs;
  final RxnString roadmapError = RxnString();

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
        if (selectedSubjectId.isEmpty || !subjects.any((s) => s.id == selectedSubjectId.value)) {
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
      _updateWelcomeIfInitial();
    } catch (e) {
      roadmapError.value = e.toString();
    } finally {
      isLoadingMap.value = false;
    }
  }

  void onTopicTapped(BuildContext context, LearningMapTopicItemModel topic) {
    if (topic.isAvailable || topic.isInProgress) {
      AppRouter.router.push('/lesson-step/${topic.roadmapStepId}');
    } else if (topic.isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming Soon: Guided lesson script for "${topic.topicName}" is currently being prepared.',
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

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void _loadInitialConversation() {
    messages.clear();

    // Dialog 1: Welcome & Topic Selection
    messages.add(
      ChatMessageModel(
        id: 'msg_1',
        sender: MessageSender.ai,
        text:
            'Hey Shagun, welcome to AptiQu! 👋\n\nBefore we start solving aptitude questions, let\'s make numbers feel simpler.\n\nWe\'ll start with patterns, mental calculation shortcuts, and techniques you will use everywhere.\n\nReady to jump in?',
        time: 'Just now',
        question: QuestionData(
          title: 'CURRENT TOPIC',
          desc: 'Mathematical Foundations & Mental Calculation',
          difficulty: 'Beginner • 5 min',
          inputType: QuestionInputType.select,
          options: ["🚀 Start Lesson", 'Explore Topics'],
        ),
      ),
    );
  }

  void _updateWelcomeIfInitial() {
    if (messages.isNotEmpty && messages.first.id == 'msg_1') {
      final q = messages.first.question;
      if (q != null && !q.isCompleted) {
        final availableTopic = subjectLearningMap.value?.topics.firstWhereOrNull(
          (t) => t.isAvailable || t.isInProgress,
        );
        if (availableTopic != null) {
          messages[0] = ChatMessageModel(
            id: 'msg_1',
            sender: MessageSender.ai,
            text:
                'Hey Shagun, welcome to AptiQu! 👋\n\nBefore we start solving aptitude questions, let\'s make numbers feel simpler.\n\nWe\'ll start with patterns, mental calculation shortcuts, and techniques you will use everywhere.\n\nReady to jump in?',
            time: 'Just now',
            question: QuestionData(
              title: 'CURRENT TOPIC',
              desc: availableTopic.topicName,
              difficulty: 'Beginner • 5 min',
              inputType: QuestionInputType.select,
              options: ["🚀 Start Lesson", 'Explore Topics'],
            ),
          );
        }
      }
    }
  }

  /// Handle option selection (InputType.select)
  void handleOptionSelection(String messageId, int optionIndex) {
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.selectedOptionIndex = optionIndex;
    q.isCompleted = true;
    messages.refresh();

    final selectedText = q.options[optionIndex];

    // User response bubble
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: selectedText,
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    // Natural conversation step progression
    if (conversationStep.value == 1) {
      if (optionIndex == 0) {
        // Proceed with lesson
        conversationStep.value = 2;
        messages.add(
          ChatMessageModel(
            id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.ai,
            text: 'Opening your interactive lesson stream now! ⚡',
            time: _getCurrentTime(),
          ),
        );
        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 500), () {
          startLiveLesson();
        });
      } else {
        // Picked another topic
        Future.delayed(const Duration(milliseconds: 400), () {
          messages.add(
            ChatMessageModel(
              id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.ai,
              text:
                  'Opening curriculum topics! You can explore all roadmap topics anytime from the Topics tab.',
              time: _getCurrentTime(),
            ),
          );
          selectedNavIndex.value = 1;
        });
      }
    } else if (conversationStep.value == 2) {
      if (optionIndex == 0) {
        startLiveLesson();
      } else {
        selectedNavIndex.value = 1;
      }
    }
  }

  /// Direct launch for live backend AI Tutor session
  void startLiveLesson([String? topicSlug]) {
    final availableTopic = subjectLearningMap.value?.topics.firstWhereOrNull(
      (t) => t.isAvailable || t.isInProgress,
    );
    if (availableTopic != null) {
      AppRouter.router.push('/lesson-step/${availableTopic.roadmapStepId}');
    } else if (topicSlug != null && topicSlug.isNotEmpty) {
      AppRouter.router.push('/lesson/$topicSlug');
    } else {
      final firstTopic = subjectLearningMap.value?.topics.firstOrNull;
      if (firstTopic != null) {
        AppRouter.router.push('/lesson-step/${firstTopic.roadmapStepId}');
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

    final activeTopicName = subjectLearningMap.value?.topics
            .firstWhereOrNull((t) => t.isAvailable || t.isInProgress)
            ?.topicName ??
        'Mathematical Foundations & Mental Calculation';

    // User spoken answer
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

    Future.delayed(const Duration(milliseconds: 600), () {
      messages.add(
        ChatMessageModel(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text:
              'Great reasoning! 👏 To practice step-by-step with real-time feedback, jump into your roadmap lesson below:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'CURRENT LESSON',
            desc: activeTopicName,
            difficulty: 'Guided • 5 min',
            inputType: QuestionInputType.select,
            options: ['🚀 Start Lesson', 'Browse Topics'],
          ),
        ),
      );
      _scrollToBottom();
    });
  }

  /// Handle Text Submission (InputType.text)
  void handleTextSubmission(String messageId, String text) {
    if (text.trim().isEmpty) return;

    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.submittedText = text.trim();
    q.isCompleted = true;
    messages.refresh();

    final activeTopicName = subjectLearningMap.value?.topics
            .firstWhereOrNull((t) => t.isAvailable || t.isInProgress)
            ?.topicName ??
        'Mathematical Foundations & Mental Calculation';

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

    Future.delayed(const Duration(milliseconds: 600), () {
      messages.add(
        ChatMessageModel(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text:
              'Got it! 🎯 To continue step-by-step through interactive drills and mental calculation patterns, start the lesson below:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'CURRENT LESSON',
            desc: activeTopicName,
            difficulty: 'Guided • 5 min',
            inputType: QuestionInputType.select,
            options: ['🚀 Start Lesson', 'Browse Topics'],
          ),
        ),
      );
      _scrollToBottom();
    });
  }

  /// Handle Scan Notes submission (InputType.scan)
  void handleScanSubmission(String messageId) {
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.isCompleted = true;
    messages.refresh();

    // User uploaded scan note
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text: '📄 [Uploaded Handwritten Solution]',
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 600), () {
      messages.add(
        ChatMessageModel(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text:
              'Notes received! 🌟 You can also submit handwriting directly inside any live lesson session using the camera button in the top bar.',
          time: _getCurrentTime(),
        ),
      );
      _scrollToBottom();
    });
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
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
