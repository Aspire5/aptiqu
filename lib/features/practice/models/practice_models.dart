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

  factory PracticeOptionModel.fromJson(dynamic json) {
    if (json is Map) {
      return PracticeOptionModel(
        id: json['id']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
      );
    }
    return PracticeOptionModel(id: '', text: json?.toString() ?? '');
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
    List<PracticeOptionModel> opts = [];
    if (json['options'] is List) {
      opts = (json['options'] as List)
          .map((o) => PracticeOptionModel.fromJson(o))
          .toList();
    }
    List<String> hintsList = [];
    if (json['hints'] is List) {
      hintsList = (json['hints'] as List).map((h) => h.toString()).toList();
    }

    return PracticeQuestionModel(
      id: json['id']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      options: opts,
      difficulty: json['difficulty']?.toString() ?? 'EASY',
      estimatedTimeSeconds: (json['estimatedTimeSeconds'] as num?)?.toInt() ?? 60,
      calculationMode: json['calculationMode']?.toString() ?? 'MENTAL',
      hints: hintsList,
      pattern: json['pattern']?.toString(),
      correctAnswer: json['correctAnswer']?.toString(),
      explanation: json['explanation']?.toString(),
      method: json['method']?.toString(),
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
    final rawQ = json['question'];
    final qMap = rawQ is Map ? Map<String, dynamic>.from(rawQ) : <String, dynamic>{};

    return PracticeSessionQuestionModel(
      id: json['id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      isAnswered: json['isAnswered'] as bool? ?? false,
      userSelectedOptionId: json['userSelectedOptionId']?.toString(),
      isCorrect: json['isCorrect'] as bool?,
      responseTimeMs: (json['responseTimeMs'] as num?)?.toInt(),
      hintsRevealedCount: (json['hintsRevealedCount'] as num?)?.toInt() ?? 0,
      question: PracticeQuestionModel.fromJson(qMap),
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
  final bool isReplay;
  final String? replaySourceType;
  final String? replaySourceId;
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
    this.isReplay = false,
    this.replaySourceType,
    this.replaySourceId,
    required this.questions,
  });

  factory PracticeSessionModel.fromJson(Map<String, dynamic> json) {
    List<PracticeSessionQuestionModel> qList = [];
    if (json['questions'] is List) {
      qList = (json['questions'] as List)
          .whereType<Map>()
          .map((q) => PracticeSessionQuestionModel.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    }

    List<String> subIds = [];
    if (json['subtopicIds'] is List) {
      subIds = (json['subtopicIds'] as List).map((s) => s.toString()).toList();
    }

    return PracticeSessionModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      subjectId: json['subjectId']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      subtopicIds: subIds,
      status: json['status']?.toString() ?? 'ACTIVE',
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? qList.length,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalTimeMs: (json['totalTimeMs'] as num?)?.toInt() ?? 0,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      isReplay: json['isReplay'] as bool? ?? false,
      replaySourceType: json['replaySourceType']?.toString(),
      replaySourceId: json['replaySourceId']?.toString(),
      questions: qList,
    );
  }
}

class PracticeHistoryItemModel {
  final String id;
  final String topicId;
  final String subjectId;
  final String status;
  final int correctCount;
  final int totalQuestions;
  final int totalTimeMs;
  final int xpAwarded;
  final bool isReplay;
  final String? replaySourceType;
  final String? replaySourceId;
  final String createdAt;
  final String? completedAt;

  const PracticeHistoryItemModel({
    required this.id,
    required this.topicId,
    required this.subjectId,
    required this.status,
    required this.correctCount,
    required this.totalQuestions,
    required this.totalTimeMs,
    required this.xpAwarded,
    required this.isReplay,
    this.replaySourceType,
    this.replaySourceId,
    required this.createdAt,
    this.completedAt,
  });

  factory PracticeHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return PracticeHistoryItemModel(
      id: json['id']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      subjectId: json['subjectId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 10,
      totalTimeMs: (json['totalTimeMs'] as num?)?.toInt() ?? 0,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      isReplay: json['isReplay'] as bool? ?? false,
      replaySourceType: json['replaySourceType']?.toString(),
      replaySourceId: json['replaySourceId']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      completedAt: json['completedAt']?.toString(),
    );
  }
}

class PracticeHistoryResponseModel {
  final List<PracticeHistoryItemModel> history;
  final int completedDrillsCount;
  final int overallAccuracy;
  final int avgResponseTimeMs;
  final int page;
  final int totalPages;

  const PracticeHistoryResponseModel({
    required this.history,
    required this.completedDrillsCount,
    required this.overallAccuracy,
    required this.avgResponseTimeMs,
    required this.page,
    required this.totalPages,
  });

  factory PracticeHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['history'] as List<dynamic>?)
            ?.map((h) => PracticeHistoryItemModel.fromJson(Map<String, dynamic>.from(h as Map)))
            .toList() ??
        [];

    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return PracticeHistoryResponseModel(
      history: list,
      completedDrillsCount: (stats['completedDrillsCount'] as num?)?.toInt() ?? 0,
      overallAccuracy: (stats['overallAccuracy'] as num?)?.toInt() ?? 0,
      avgResponseTimeMs: (stats['avgResponseTimeMs'] as num?)?.toInt() ?? 0,
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
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

extension CalculationModeFormatter on String {
  String toHumanCalculationMode() {
    switch (toUpperCase()) {
      case 'LIGHT_PEN_AND_PAPER':
        return 'Light Pen & Paper';
      case 'FULL_PEN_AND_PAPER':
        return 'Pen & Paper';
      case 'MENTAL':
        return 'Mental Only';
      default:
        return replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }
}
