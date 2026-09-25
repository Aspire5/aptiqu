import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
            'Hey Shagun, Welcome to AptiQu! ⚡\nI will help you sharpen your mathematical aptitude and reasoning skills in a fun interactive manner!\n\nShall we proceed with the very first topic of our syllabus — Ratio & Proportion?',
        time: 'Just now',
        question: QuestionData(
          title: 'SYLLABUS TOPIC #1',
          desc: 'Select your preferred starting option:',
          difficulty: 'Starting Point',
          inputType: QuestionInputType.select,
          options: ["Yes, let's begin!", 'Choose Another Topic'],
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
        // Proceed with Ratio & Proportion
        conversationStep.value = 2;
        _triggerStep2RatioIntro();
      } else {
        // Picked another topic
        Future.delayed(const Duration(milliseconds: 600), () {
          messages.add(
            ChatMessageModel(
              id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
              sender: MessageSender.ai,
              text:
                  'No problem! You can explore all topics from the TOPICS tab anytime. For now, Ratio & Proportion forms the foundation of 80% of arithmetic topics. Let\'s do a quick look!',
              time: _getCurrentTime(),
            ),
          );
          _triggerStep2RatioIntro();
        });
      }
    } else if (conversationStep.value == 2) {
      // User answered warm up check
      conversationStep.value = 3;
      _triggerStep3VivaCheck(optionIndex == 0);
    }
  }

  /// Step 2: Topic Divider + Introduction + Warm-Up Multi-Choice Check
  void _triggerStep2RatioIntro() {
    Future.delayed(const Duration(milliseconds: 500), () {
      // 1. Topic divider acting as a heading
      messages.add(
        ChatMessageModel(
          id: 'divider_1',
          sender: MessageSender.ai,
          text: '',
          time: '',
          isTopicDivider: true,
          topicTitle: 'TOPIC: RATIO & PROPORTION',
        ),
      );
      _scrollToBottom();

      // 2. Message 2 with basic intro and warm-up question in the same container
      Future.delayed(const Duration(milliseconds: 500), () {
        messages.add(
          ChatMessageModel(
            id: 'msg_2',
            sender: MessageSender.ai,
            text:
                'Awesome! Let\'s build your foundational intuition first.\n\nA ratio is simply a mathematical comparison of two quantities of the same kind by division (a : b = a/b).\nFor example, if a bag has 2 red marbles and 3 blue marbles, their ratio is 2 : 3.\n\nLet\'s check your understanding with a quick warm-up question:',
            time: _getCurrentTime(),
            question: QuestionData(
              title: 'Warm-Up Check',
              desc:
                  'If a class has 20 boys and 30 girls, what is the simplest ratio of boys to girls?',
              difficulty: 'Level 1 • Quick Drill',
              inputType: QuestionInputType.select,
              options: ['2 : 3', '3 : 2', '4 : 5', '1 : 2'],
              correctOptionIndex: 0,
            ),
          ),
        );
        _scrollToBottom();
      });
    });
  }

  /// Step 3: Viva Oral Conceptual Check (InputType.voice)
  void _triggerStep3VivaCheck(bool isCorrect) {
    Future.delayed(const Duration(milliseconds: 600), () {
      final feedback = isCorrect
          ? 'Spot on! 🎯 20/30 simplifies down to 2/3 by dividing both by 10.'
          : 'Good try! 20/30 simplifies to 2/3 when dividing both numerator and denominator by 10.';

      messages.add(
        ChatMessageModel(
          id: 'msg_3',
          sender: MessageSender.ai,
          text:
              '$feedback\n\nNow, let\'s test your conceptual intuition viva-style! In your own words, why does multiplying or dividing both terms of a ratio by the same non-zero number not change the ratio?',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'Viva Conceptual Check',
            desc:
                'Explain the fundamental invariance property of ratios in your own words:',
            difficulty: 'Oral Viva • +30 Coins',
            inputType: QuestionInputType.voice,
          ),
        ),
      );
      _scrollToBottom();
    });
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

    conversationStep.value = 4;
    _triggerStep4CompoundRatioText();
  }

  /// Step 4: Text-Based Mathematical Drill (InputType.text)
  void _triggerStep4CompoundRatioText() {
    Future.delayed(const Duration(milliseconds: 700), () {
      messages.add(
        ChatMessageModel(
          id: 'msg_4',
          sender: MessageSender.ai,
          text:
              'Brilliant viva articulation, Shagun! 👏 That is exactly the Fundamental Invariance Principle.\n\nNow, let\'s apply compound ratios. Try solving this on your notepad and enter your simplified answer below:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'Compound Ratio Challenge',
            desc:
                'If A : B = 3 : 4 and B : C = 8 : 9, find the ratio of A : C in simplest form.',
            difficulty: 'Tier II Drill • +40 Coins',
            inputType: QuestionInputType.text,
            placeholder: 'Type answer e.g. 2:3 or 2/3',
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

    conversationStep.value = 5;
    _triggerStep5ScanDrill();
  }

  /// Step 5: Scratchpad / Paper Scan Drill (InputType.scan)
  void _triggerStep5ScanDrill() {
    Future.delayed(const Duration(milliseconds: 700), () {
      messages.add(
        ChatMessageModel(
          id: 'msg_5',
          sender: MessageSender.ai,
          text:
              'Outstanding deduction! 🏆\n(A/C) = (A/B) × (B/C) = (3/4) × (8/9) = 24/36 = 2/3, so A : C = 2 : 3.\n\nYou have mastered the core fundamentals! For multi-step problem solving, solve this on paper and upload a photo of your rough work:',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'Scratchpad Reasoning Drill',
            desc:
                'Divide ₹1,500 among A, B, and C in the ratio 2 : 3 : 5. Find C\'s share and upload your steps:',
            difficulty: 'Scratchpad • +50 Coins',
            inputType: QuestionInputType.scan,
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
        text:
            '📄 [Uploaded Handwritten Steps: C\'s share = (5/10) × ₹1,500 = ₹750 ✓]',
        time: _getCurrentTime(),
      ),
    );
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      messages.add(
        ChatMessageModel(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.ai,
          text:
              'Perfect handwritten methodology, Shagun! 🌟\nYour steps are crisp: Total units = 2 + 3 + 5 = 10 units. C receives 5/10 = 50% = ₹750.\n\nYou are officially ready for the Timed Speed Quiz! Would you like to launch it now?',
          time: _getCurrentTime(),
          question: QuestionData(
            title: 'Speed Quiz Arena',
            desc: '10 Timed Questions • 5 Minutes • Instant Rank Assessment',
            difficulty: 'Arena Challenge',
            inputType: QuestionInputType.select,
            options: ['Launch Speed Quiz ⚡', 'Review Ratio Formulae'],
          ),
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
