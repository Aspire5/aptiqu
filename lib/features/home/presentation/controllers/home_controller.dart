import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/routing/app_router.dart';

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

  @override
  void onInit() {
    super.onInit();
    _loadInitialConversation();
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
            'Hey Shagun, Welcome to AptiQu! ⚡\nI am your interactive AI Tutor. I will help you build mathematical intuition step-by-step through guided dialogue.\n\nOur first 15-minute curriculum session is ready on the server: Foundations of Ratios 101.\nShall we begin?',
        time: 'Just now',
        question: QuestionData(
          title: 'CURRICULUM TRACK #1',
          desc: 'Start 15-Minute Guided AI Tutor Lesson on Ratios:',
          difficulty: 'Live Session • 15 min',
          inputType: QuestionInputType.select,
          options: ["🚀 Start Live AI Lesson", 'Explore Topics'],
        ),
      ),
    );
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
        // Proceed with live backend AI Tutor lesson
        conversationStep.value = 2;
        messages.add(
          ChatMessageModel(
            id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.ai,
            text:
                'Connecting to AptiQu AI Tutor server for "Ratio & Proportion 101"... ⚡\nOpening your interactive lesson stream now!',
            time: _getCurrentTime(),
          ),
        );
        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 500), () {
          AppRouter.router.push('/lesson/math_ratios_101');
        });
      } else {
        // Picked another topic
        Future.delayed(const Duration(milliseconds: 400), () {
          messages.add(
            ChatMessageModel(
              id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.ai,
              text:
                  'Opening curriculum topics! You can start the Ratio & Proportion live session anytime from the Topics tab.',
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
  void startLiveLesson([String topicSlug = 'math_ratios_101']) {
    AppRouter.router.push('/lesson/$topicSlug');
  }

  /// Handle Voice/Viva submission (InputType.voice)
  void handleVoiceSubmission(String messageId) {
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final q = messages[msgIndex].question;
    if (q == null || q.isCompleted) return;

    q.isCompleted = true;
    messages.refresh();

    // User spoken answer
    messages.add(
      ChatMessageModel(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.user,
        text:
            '🎙️ "Because multiplying or dividing both terms by the same non-zero constant k is equivalent to multiplying the fraction by (k/k) = 1, so the numerical value remains invariant."',
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
              'Great reasoning! 👏 To experience full interactive dialogue, formula cards, and mental calculation drills, start the 15-minute live AI session below:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'RATIOS 101 CURRICULUM',
            desc: 'Foundations of Ratios: Intuition to Mastery',
            difficulty: 'Live Session • 15 min',
            inputType: QuestionInputType.select,
            options: ['🚀 Launch Live Lesson', 'Browse Topics'],
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
              'Answer recorded! 🎯 To experience the full guided conversation with smart hints and real-time step explanations, start the live AI Tutor lesson:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'RATIOS 101 CURRICULUM',
            desc: 'Foundations of Ratios: Intuition to Mastery • 15 min',
            difficulty: 'Live Session • 15 min',
            inputType: QuestionInputType.select,
            options: ['🚀 Launch Live Lesson', 'Browse Topics'],
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
