import '../../../core/progression/models/xp_models.dart';

class LiveSubtopicModel {
  final String id;
  final String name;
  final String? description;

  const LiveSubtopicModel({
    required this.id,
    required this.name,
    this.description,
  });

  factory LiveSubtopicModel.fromJson(Map<String, dynamic> json) {
    return LiveSubtopicModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

class LiveTopicModel {
  final String subjectId;
  final String subjectName;
  final String topicId;
  final String topicName;
  final List<LiveSubtopicModel> subtopics;

  const LiveTopicModel({
    required this.subjectId,
    required this.subjectName,
    required this.topicId,
    required this.topicName,
    required this.subtopics,
  });

  factory LiveTopicModel.fromJson(Map<String, dynamic> json) {
    final subList = (json['subtopics'] as List<dynamic>?)
            ?.map((s) => LiveSubtopicModel.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return LiveTopicModel(
      subjectId: json['subjectId'] as String,
      subjectName: json['subjectName'] as String,
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      subtopics: subList,
    );
  }
}

class PracticeOptionModel {
  final String id;
  final String text;

  const PracticeOptionModel({required this.id, required this.text});

  factory PracticeOptionModel.fromJson(Map<String, dynamic> json) {
    return PracticeOptionModel(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}

class PracticeQuestionModel {
  final String id;
  final String prompt;
  final List<PracticeOptionModel> options;
  final String difficulty;
  final int estimatedTimeSeconds;
  final String calculationMode;
  final List<String> hints;
  final String? pattern;
  final String? correctAnswer;
  final String? explanation;
  final String? method;

  const PracticeQuestionModel({
    required this.id,
    required this.prompt,
    required this.options,
    required this.difficulty,
    required this.estimatedTimeSeconds,
    required this.calculationMode,
    required this.hints,
    this.pattern,
    this.correctAnswer,
    this.explanation,
    this.method,
  });

  factory PracticeQuestionModel.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>?)
            ?.map((o) => PracticeOptionModel.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];
    final hintsList = (json['hints'] as List<dynamic>?)
            ?.map((h) => h.toString())
            .toList() ??
        [];

    return PracticeQuestionModel(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: opts,
      difficulty: json['difficulty'] as String? ?? 'EASY',
      estimatedTimeSeconds: json['estimatedTimeSeconds'] as int? ?? 60,
      calculationMode: json['calculationMode'] as String? ?? 'MENTAL',
      hints: hintsList,
      pattern: json['pattern'] as String?,
      correctAnswer: json['correctAnswer'] as String?,
      explanation: json['explanation'] as String?,
      method: json['method'] as String?,
    );
  }
}

class PracticeSessionQuestionModel {
  final String id;
  final int sequence;
  final bool isAnswered;
  final String? userSelectedOptionId;
  final bool? isCorrect;
  final int? responseTimeMs;
  final int hintsRevealedCount;
  final PracticeQuestionModel question;

  const PracticeSessionQuestionModel({
    required this.id,
    required this.sequence,
    required this.isAnswered,
    this.userSelectedOptionId,
    this.isCorrect,
    this.responseTimeMs,
    required this.hintsRevealedCount,
    required this.question,
  });

  factory PracticeSessionQuestionModel.fromJson(Map<String, dynamic> json) {
    return PracticeSessionQuestionModel(
      id: json['id'] as String,
      sequence: json['sequence'] as int,
      isAnswered: json['isAnswered'] as bool? ?? false,
      userSelectedOptionId: json['userSelectedOptionId'] as String?,
      isCorrect: json['isCorrect'] as bool?,
      responseTimeMs: json['responseTimeMs'] as int?,
      hintsRevealedCount: json['hintsRevealedCount'] as int? ?? 0,
      question: PracticeQuestionModel.fromJson(json['question'] as Map<String, dynamic>),
    );
  }
}

class PracticeSessionModel {
  final String id;
  final String userId;
  final String subjectId;
  final String topicId;
  final List<String> subtopicIds;
  final String status;
  final int currentIndex;
  final int totalQuestions;
  final int correctCount;
  final int totalTimeMs;
  final int xpAwarded;
  final List<PracticeSessionQuestionModel> questions;

  const PracticeSessionModel({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.topicId,
    required this.subtopicIds,
    required this.status,
    required this.currentIndex,
    required this.totalQuestions,
    required this.correctCount,
    required this.totalTimeMs,
    required this.xpAwarded,
    required this.questions,
  });

  factory PracticeSessionModel.fromJson(Map<String, dynamic> json) {
    final qList = (json['questions'] as List<dynamic>?)
            ?.map((q) => PracticeSessionQuestionModel.fromJson(q as Map<String, dynamic>))
            .toList() ??
        [];

    final subIds = (json['subtopicIds'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [];

    return PracticeSessionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      subjectId: json['subjectId'] as String,
      topicId: json['topicId'] as String,
      subtopicIds: subIds,
      status: json['status'] as String,
      currentIndex: json['currentIndex'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 10,
      correctCount: json['correctCount'] as int? ?? 0,
      totalTimeMs: json['totalTimeMs'] as int? ?? 0,
      xpAwarded: json['xpAwarded'] as int? ?? 0,
      questions: qList,
    );
  }
}

class PracticeAnswerResultModel {
  final bool isCorrect;
  final String correctAnswer;
  final String explanation;
  final String method;
  final bool isComplete;
  final int totalAnswered;
  final int correctCount;
  final int xpAwarded;
  final AwardXpResultModel? xpResult;

  const PracticeAnswerResultModel({
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    required this.method,
    required this.isComplete,
    required this.totalAnswered,
    required this.correctCount,
    required this.xpAwarded,
    this.xpResult,
  });

  factory PracticeAnswerResultModel.fromJson(Map<String, dynamic> json) {
    return PracticeAnswerResultModel(
      isCorrect: json['isCorrect'] as bool,
      correctAnswer: json['correctAnswer'] as String,
      explanation: json['explanation'] as String? ?? '',
      method: json['method'] as String? ?? '',
      isComplete: json['isComplete'] as bool? ?? false,
      totalAnswered: json['totalAnswered'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      xpAwarded: json['xpAwarded'] as int? ?? 0,
      xpResult: json['xpResult'] != null
          ? AwardXpResultModel.fromJson(json['xpResult'] as Map<String, dynamic>)
          : null,
    );
  }
}
