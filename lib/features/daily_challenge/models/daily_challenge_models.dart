import '../../practice/models/practice_models.dart';

class DailyChallengeStatusModel {
  final int streak;
  final int highestStreak;
  final bool isDue;
  final bool isCompletedToday;
  final bool canAttempt;
  final int tier;
  final String tierTitle;
  final int questionCount;
  final List<String> difficulties;
  final int timeLimitPerQuestion;
  final bool hasHints;
  final int msUntilMidnight;
  final DailyParticipationSummary? todayParticipation;

  const DailyChallengeStatusModel({
    required this.streak,
    required this.highestStreak,
    required this.isDue,
    required this.isCompletedToday,
    required this.canAttempt,
    required this.tier,
    required this.tierTitle,
    required this.questionCount,
    required this.difficulties,
    required this.timeLimitPerQuestion,
    required this.hasHints,
    required this.msUntilMidnight,
    this.todayParticipation,
  });

  factory DailyChallengeStatusModel.fromJson(Map<String, dynamic> json) {
    return DailyChallengeStatusModel(
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      highestStreak: (json['highestStreak'] as num?)?.toInt() ?? 0,
      isDue: json['isDue'] as bool? ?? true,
      isCompletedToday: json['isCompletedToday'] as bool? ?? false,
      canAttempt: json['canAttempt'] as bool? ?? true,
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      tierTitle: json['tierTitle']?.toString() ?? 'Novice Duelist',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 1,
      difficulties: (json['difficulties'] as List<dynamic>?)
              ?.map((d) => d.toString())
              .toList() ??
          ['EASY'],
      timeLimitPerQuestion:
          (json['timeLimitPerQuestion'] as num?)?.toInt() ?? 60,
      hasHints: json['hasHints'] as bool? ?? false,
      msUntilMidnight: (json['msUntilMidnight'] as num?)?.toInt() ?? 0,
      todayParticipation: json['todayParticipation'] != null
          ? DailyParticipationSummary.fromJson(
              Map<String, dynamic>.from(json['todayParticipation'] as Map))
          : null,
    );
  }
}

class DailyParticipationSummary {
  final String id;
  final String status;
  final int correctCount;
  final int totalQuestions;
  final int totalTimeMs;
  final int avgTimeMs;
  final int xpAwarded;
  final int coinsAwarded;
  final String? completedAt;

  const DailyParticipationSummary({
    required this.id,
    required this.status,
    required this.correctCount,
    required this.totalQuestions,
    required this.totalTimeMs,
    required this.avgTimeMs,
    required this.xpAwarded,
    required this.coinsAwarded,
    this.completedAt,
  });

  factory DailyParticipationSummary.fromJson(Map<String, dynamic> json) {
    return DailyParticipationSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      totalTimeMs: (json['totalTimeMs'] as num?)?.toInt() ?? 0,
      avgTimeMs: (json['avgTimeMs'] as num?)?.toInt() ?? 0,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      completedAt: json['completedAt']?.toString(),
    );
  }
}

class DailyChallengeQuestionModel {
  final int sequence;
  final String difficulty;
  final int timeLimit;
  final bool isAnswered;
  final String? userSelectedOptionId;
  final bool? isCorrect;
  final int? responseTimeMs;
  final String id;
  final String prompt;
  final List<PracticeOptionModel> options;
  final String? correctAnswer;
  final String? explanation;
  final String? method;
  final String? pyq;
  final String? alternativeExplanation;
  final String? preferredSolution;
  final String? preferredReason;

  const DailyChallengeQuestionModel({
    required this.sequence,
    required this.difficulty,
    required this.timeLimit,
    required this.isAnswered,
    this.userSelectedOptionId,
    this.isCorrect,
    this.responseTimeMs,
    required this.id,
    required this.prompt,
    required this.options,
    this.correctAnswer,
    this.explanation,
    this.method,
    this.pyq,
    this.alternativeExplanation,
    this.preferredSolution,
    this.preferredReason,
  });

  factory DailyChallengeQuestionModel.fromJson(Map<String, dynamic> json) {
    final qMap = json['question'] as Map<String, dynamic>? ?? {};

    List<PracticeOptionModel> opts = [];
    if (qMap['options'] is List) {
      opts = (qMap['options'] as List)
          .map((o) => PracticeOptionModel.fromJson(o))
          .toList();
    }

    return DailyChallengeQuestionModel(
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      difficulty: json['difficulty']?.toString() ?? 'EASY',
      timeLimit: (json['timeLimit'] as num?)?.toInt() ?? 60,
      isAnswered: json['isAnswered'] as bool? ?? false,
      userSelectedOptionId: json['userSelectedOptionId']?.toString(),
      isCorrect: json['isCorrect'] as bool?,
      responseTimeMs: (json['responseTimeMs'] as num?)?.toInt(),
      id: qMap['id']?.toString() ?? '',
      prompt: qMap['prompt']?.toString() ?? '',
      options: opts,
      correctAnswer: qMap['correctAnswer']?.toString(),
      explanation: qMap['explanation']?.toString(),
      method: qMap['method']?.toString(),
      pyq: qMap['pyq']?.toString(),
      alternativeExplanation: qMap['alternativeExplanation']?.toString(),
      preferredSolution: qMap['preferredSolution']?.toString(),
      preferredReason: qMap['preferredReason']?.toString(),
    );
  }
}

class DailyChallengeSessionModel {
  final String participationId;
  final String dateString;
  final String status;
  final int currentStreak;
  final int tier;
  final int totalQuestions;
  final int timeLimitPerQuestion;
  final List<DailyChallengeQuestionModel> questions;

  const DailyChallengeSessionModel({
    required this.participationId,
    required this.dateString,
    required this.status,
    required this.currentStreak,
    required this.tier,
    required this.totalQuestions,
    required this.timeLimitPerQuestion,
    required this.questions,
  });

  factory DailyChallengeSessionModel.fromJson(Map<String, dynamic> json) {
    List<DailyChallengeQuestionModel> qList = [];
    if (json['questions'] is List) {
      qList = (json['questions'] as List)
          .map((q) => DailyChallengeQuestionModel.fromJson(
              Map<String, dynamic>.from(q as Map)))
          .toList();
    }

    return DailyChallengeSessionModel(
      participationId: json['participationId']?.toString() ?? '',
      dateString: json['dateString']?.toString() ?? '',
      status: json['status']?.toString() ?? 'IN_PROGRESS',
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? qList.length,
      timeLimitPerQuestion:
          (json['timeLimitPerQuestion'] as num?)?.toInt() ?? 60,
      questions: qList,
    );
  }
}

class DailyChallengeAnswerResultModel {
  final bool isCorrect;
  final String correctAnswer;
  final String explanation;
  final String method;
  final String? alternativeExplanation;
  final String? preferredSolution;
  final String? preferredReason;
  final int sequence;
  final bool isComplete;
  final int answeredCount;
  final int totalQuestions;
  final int correctCount;
  final int avgTimeMs;
  final int streak;
  final int highestStreak;
  final bool streakIncremented;
  final int xpAwarded;
  final int coinsAwarded;

  const DailyChallengeAnswerResultModel({
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    required this.method,
    this.alternativeExplanation,
    this.preferredSolution,
    this.preferredReason,
    required this.sequence,
    required this.isComplete,
    required this.answeredCount,
    required this.totalQuestions,
    required this.correctCount,
    required this.avgTimeMs,
    required this.streak,
    required this.highestStreak,
    required this.streakIncremented,
    required this.xpAwarded,
    required this.coinsAwarded,
  });

  factory DailyChallengeAnswerResultModel.fromJson(Map<String, dynamic> json) {
    return DailyChallengeAnswerResultModel(
      isCorrect: json['isCorrect'] as bool? ?? false,
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      alternativeExplanation: json['alternativeExplanation']?.toString(),
      preferredSolution: json['preferredSolution']?.toString(),
      preferredReason: json['preferredReason']?.toString(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      isComplete: json['isComplete'] as bool? ?? false,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 1,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      avgTimeMs: (json['avgTimeMs'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      highestStreak: (json['highestStreak'] as num?)?.toInt() ?? 0,
      streakIncremented: json['streakIncremented'] as bool? ?? false,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyHistoryAnswerItem {
  final int sequence;
  final bool isCorrect;
  final int responseTimeMs;
  final String questionPrompt;
  final String difficulty;

  const DailyHistoryAnswerItem({
    required this.sequence,
    required this.isCorrect,
    required this.responseTimeMs,
    required this.questionPrompt,
    required this.difficulty,
  });

  factory DailyHistoryAnswerItem.fromJson(Map<String, dynamic> json) {
    return DailyHistoryAnswerItem(
      sequence: (json['sequence'] as num?)?.toInt() ?? 1,
      isCorrect: json['isCorrect'] as bool? ?? false,
      responseTimeMs: (json['responseTimeMs'] as num?)?.toInt() ?? 0,
      questionPrompt: json['questionPrompt']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'EASY',
    );
  }
}

class DailyHistoryItemModel {
  final String id;
  final String dateString;
  final String status;
  final int correctCount;
  final int totalQuestions;
  final int totalTimeMs;
  final int avgTimeMs;
  final int streakAtAttempt;
  final bool streakIncremented;
  final int xpAwarded;
  final int coinsAwarded;
  final String startedAt;
  final String? completedAt;
  final List<DailyHistoryAnswerItem> answers;

  const DailyHistoryItemModel({
    required this.id,
    required this.dateString,
    required this.status,
    required this.correctCount,
    required this.totalQuestions,
    required this.totalTimeMs,
    required this.avgTimeMs,
    required this.streakAtAttempt,
    required this.streakIncremented,
    required this.xpAwarded,
    required this.coinsAwarded,
    required this.startedAt,
    this.completedAt,
    required this.answers,
  });

  factory DailyHistoryItemModel.fromJson(Map<String, dynamic> json) {
    List<DailyHistoryAnswerItem> ansList = [];
    if (json['answers'] is List) {
      ansList = (json['answers'] as List)
          .map((a) => DailyHistoryAnswerItem.fromJson(
              Map<String, dynamic>.from(a as Map)))
          .toList();
    }

    return DailyHistoryItemModel(
      id: json['id']?.toString() ?? '',
      dateString: json['dateString']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      totalTimeMs: (json['totalTimeMs'] as num?)?.toInt() ?? 0,
      avgTimeMs: (json['avgTimeMs'] as num?)?.toInt() ?? 0,
      streakAtAttempt: (json['streakAtAttempt'] as num?)?.toInt() ?? 0,
      streakIncremented: json['streakIncremented'] as bool? ?? false,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      coinsAwarded: (json['coinsAwarded'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt']?.toString() ?? '',
      completedAt: json['completedAt']?.toString(),
      answers: ansList,
    );
  }
}

class DailyHistoryResponseModel {
  final List<DailyHistoryItemModel> history;
  final int currentStreak;
  final int highestStreak;
  final int totalCompleted;
  final int overallAvgTimeMs;
  final int page;
  final int totalPages;

  const DailyHistoryResponseModel({
    required this.history,
    required this.currentStreak,
    required this.highestStreak,
    required this.totalCompleted,
    required this.overallAvgTimeMs,
    required this.page,
    required this.totalPages,
  });

  factory DailyHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['history'] as List<dynamic>?)
            ?.map((h) => DailyHistoryItemModel.fromJson(
                Map<String, dynamic>.from(h as Map)))
            .toList() ??
        [];

    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return DailyHistoryResponseModel(
      history: list,
      currentStreak: (stats['currentStreak'] as num?)?.toInt() ?? 0,
      highestStreak: (stats['highestStreak'] as num?)?.toInt() ?? 0,
      totalCompleted: (stats['totalCompleted'] as num?)?.toInt() ?? 0,
      overallAvgTimeMs: (stats['overallAvgTimeMs'] as num?)?.toInt() ?? 0,
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
