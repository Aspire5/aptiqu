import 'lesson_node_model.dart';

class QuestionEvaluationModel {
  final bool isCorrect;
  final double score;
  final String? explanation;

  QuestionEvaluationModel({
    required this.isCorrect,
    required this.score,
    this.explanation,
  });

  factory QuestionEvaluationModel.fromJson(Map<String, dynamic> json) {
    return QuestionEvaluationModel(
      isCorrect: json['isCorrect'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String?,
    );
  }
}

class NextLearningStepModel {
  final String type; // 'lesson' | 'roadmap_complete'
  final bool available;
  final String? reason; // 'SCRIPT_NOT_PUBLISHED'
  final String? roadmapStepId;
  final String? topicId;
  final String? topicName;
  final String? subtopicId;
  final String? scriptId;
  final String? scriptSlug;
  final String? scriptTitle;
  final String? message;

  NextLearningStepModel({
    required this.type,
    required this.available,
    this.reason,
    this.roadmapStepId,
    this.topicId,
    this.topicName,
    this.subtopicId,
    this.scriptId,
    this.scriptSlug,
    this.scriptTitle,
    this.message,
  });

  factory NextLearningStepModel.fromJson(Map<String, dynamic> json) {
    return NextLearningStepModel(
      type: json['type'] as String? ?? 'lesson',
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
      roadmapStepId: json['roadmapStepId'] as String?,
      topicId: json['topicId'] as String?,
      topicName: json['topicName'] as String?,
      subtopicId: json['subtopicId'] as String?,
      scriptId: json['scriptId'] as String?,
      scriptSlug: json['scriptSlug'] as String?,
      scriptTitle: json['scriptTitle'] as String?,
      message: json['message'] as String?,
    );
  }
}

class LessonHistoryItemModel {
  final String id;
  final bool isUser;
  final String text;
  final LessonNodeModel? node;
  final QuestionEvaluationModel? evaluation;

  LessonHistoryItemModel({
    required this.id,
    required this.isUser,
    required this.text,
    this.node,
    this.evaluation,
  });

  factory LessonHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return LessonHistoryItemModel(
      id: json['id'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      node: json['node'] != null
          ? LessonNodeModel.fromJson(json['node'] as Map<String, dynamic>)
          : null,
      evaluation: json['evaluation'] != null
          ? QuestionEvaluationModel.fromJson(
              json['evaluation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ActiveLessonScriptSummary {
  final String id;
  final String slug;
  final String title;
  final int sequence;
  final int targetDurationMinutes;
  final String description;

  ActiveLessonScriptSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.sequence,
    required this.targetDurationMinutes,
    required this.description,
  });

  factory ActiveLessonScriptSummary.fromJson(Map<String, dynamic> json) {
    return ActiveLessonScriptSummary(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 1,
      targetDurationMinutes: json['targetDurationMinutes'] as int? ?? 8,
      description: json['description'] as String? ?? '',
    );
  }
}

class ActiveLessonStateModel {
  final bool hasActiveSession;
  final String? roadmapStepId;
  final ActiveLessonScriptSummary? script;
  final LessonSessionModel? session;

  ActiveLessonStateModel({
    required this.hasActiveSession,
    this.roadmapStepId,
    this.script,
    this.session,
  });

  factory ActiveLessonStateModel.fromJson(Map<String, dynamic> json) {
    return ActiveLessonStateModel(
      hasActiveSession: json['hasActiveSession'] as bool? ?? false,
      roadmapStepId: json['roadmapStepId'] as String?,
      script: json['script'] != null
          ? ActiveLessonScriptSummary.fromJson(json['script'] as Map<String, dynamic>)
          : null,
      session: json['session'] != null
          ? LessonSessionModel.fromJson(json['session'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LessonSessionModel {
  final String id;
  final String scriptId;
  final String scriptVersionId;
  final String? roadmapId;
  final String? roadmapStepId;
  final String? scriptSlug;
  final String? scriptTitle;
  final String status;
  final int stateVersion;
  final LessonNodeModel currentNode;
  final bool isCompleted;
  final QuestionEvaluationModel? evaluation;
  final NextLearningStepModel? next;
  final List<LessonHistoryItemModel> history;

  LessonSessionModel({
    required this.id,
    required this.scriptId,
    required this.scriptVersionId,
    this.roadmapId,
    this.roadmapStepId,
    this.scriptSlug,
    this.scriptTitle,
    required this.status,
    required this.stateVersion,
    required this.currentNode,
    this.isCompleted = false,
    this.evaluation,
    this.next,
    this.history = const [],
  });

  factory LessonSessionModel.fromJson(Map<String, dynamic> json) {
    QuestionEvaluationModel? parsedEval;
    if (json['evaluation'] != null) {
      parsedEval = QuestionEvaluationModel.fromJson(
        json['evaluation'] as Map<String, dynamic>,
      );
    }

    NextLearningStepModel? parsedNext;
    if (json['next'] != null) {
      parsedNext = NextLearningStepModel.fromJson(
        json['next'] as Map<String, dynamic>,
      );
    }

    final parsedHistory = <LessonHistoryItemModel>[];
    if (json['history'] is List) {
      for (final item in json['history'] as List) {
        if (item is Map<String, dynamic>) {
          parsedHistory.add(LessonHistoryItemModel.fromJson(item));
        }
      }
    }

    return LessonSessionModel(
      id: json['sessionId'] as String,
      scriptId: json['scriptId'] as String? ?? '',
      scriptVersionId: json['scriptVersionId'] as String? ?? '',
      roadmapId: json['roadmapId'] as String?,
      roadmapStepId: json['roadmapStepId'] as String?,
      scriptSlug: json['scriptSlug'] as String?,
      scriptTitle: json['scriptTitle'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      stateVersion: json['stateVersion'] as int? ?? 1,
      currentNode: LessonNodeModel.fromJson(json['currentNode'] as Map<String, dynamic>),
      isCompleted: json['isCompleted'] as bool? ?? false,
      evaluation: parsedEval,
      next: parsedNext,
      history: parsedHistory,
    );
  }
}
