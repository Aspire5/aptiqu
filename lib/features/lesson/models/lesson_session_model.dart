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

class LessonSessionModel {
  final String id;
  final String scriptId;
  final String scriptVersionId;
  final String status;
  final int stateVersion;
  final LessonNodeModel currentNode;
  final bool isCompleted;
  final QuestionEvaluationModel? evaluation;

  LessonSessionModel({
    required this.id,
    required this.scriptId,
    required this.scriptVersionId,
    required this.status,
    required this.stateVersion,
    required this.currentNode,
    this.isCompleted = false,
    this.evaluation,
  });

  factory LessonSessionModel.fromJson(Map<String, dynamic> json) {
    QuestionEvaluationModel? parsedEval;
    if (json['evaluation'] != null) {
      parsedEval = QuestionEvaluationModel.fromJson(
        json['evaluation'] as Map<String, dynamic>,
      );
    }

    return LessonSessionModel(
      id: json['sessionId'] as String,
      scriptId: json['scriptId'] as String? ?? '',
      scriptVersionId: json['scriptVersionId'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      stateVersion: json['stateVersion'] as int? ?? 1,
      currentNode: LessonNodeModel.fromJson(json['currentNode'] as Map<String, dynamic>),
      isCompleted: json['isCompleted'] as bool? ?? false,
      evaluation: parsedEval,
    );
  }
}
