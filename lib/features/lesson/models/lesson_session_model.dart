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

class LessonSessionModel {
  final String id;
  final String scriptId;
  final String scriptVersionId;
  final String? roadmapId;
  final String? roadmapStepId;
  final String? scriptSlug;
  final String status;
  final int stateVersion;
  final LessonNodeModel currentNode;
  final bool isCompleted;
  final QuestionEvaluationModel? evaluation;
  final NextLearningStepModel? next;

  LessonSessionModel({
    required this.id,
    required this.scriptId,
    required this.scriptVersionId,
    this.roadmapId,
    this.roadmapStepId,
    this.scriptSlug,
    required this.status,
    required this.stateVersion,
    required this.currentNode,
    this.isCompleted = false,
    this.evaluation,
    this.next,
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

    return LessonSessionModel(
      id: json['sessionId'] as String,
      scriptId: json['scriptId'] as String? ?? '',
      scriptVersionId: json['scriptVersionId'] as String? ?? '',
      roadmapId: json['roadmapId'] as String?,
      roadmapStepId: json['roadmapStepId'] as String?,
      scriptSlug: json['scriptSlug'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      stateVersion: json['stateVersion'] as int? ?? 1,
      currentNode: LessonNodeModel.fromJson(json['currentNode'] as Map<String, dynamic>),
      isCompleted: json['isCompleted'] as bool? ?? false,
      evaluation: parsedEval,
      next: parsedNext,
    );
  }
}
