class ChoiceOptionModel {
  final String id;
  final String label;

  ChoiceOptionModel({required this.id, required this.label});

  factory ChoiceOptionModel.fromJson(Map<String, dynamic> json) {
    return ChoiceOptionModel(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }
}

class QuestionInlineModel {
  final String prompt;
  final List<ChoiceOptionModel> options;
  final List<String> hints;
  final int xp;
  final String difficulty;
  final String questionType;

  QuestionInlineModel({
    required this.prompt,
    required this.options,
    this.hints = const [],
    int? xp,
    this.difficulty = 'EASY',
    this.questionType = 'PRACTICE',
  }) : xp = xp ?? calculateQuestionXp(questionType, difficulty);

  static int calculateQuestionXp(String type, String difficulty) {
    int typeXp;
    final upperType = type.trim().toUpperCase();
    if (upperType == 'RANKED') {
      typeXp = 10;
    } else {
      typeXp = 5; // PRACTICE or UNRANKED
    }

    int diffXp;
    final upperDiff = difficulty.trim().toUpperCase();
    if (upperDiff == 'HARD' || upperDiff == '3') {
      diffXp = 15;
    } else if (upperDiff == 'MEDIUM' || upperDiff == 'MED' || upperDiff == '2') {
      diffXp = 10;
    } else {
      diffXp = 5; // EASY
    }

    return typeXp + diffXp;
  }

  factory QuestionInlineModel.fromJson(Map<String, dynamic> json) {
    final diff = json['difficulty'] as String? ?? 'EASY';
    final qType = json['questionType'] as String? ?? 'PRACTICE';
    final computedXp = (json['xp'] as num?)?.toInt() ?? calculateQuestionXp(qType, diff);

    return QuestionInlineModel(
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => ChoiceOptionModel.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      hints: (json['hints'] as List<dynamic>?)
              ?.map((h) => h.toString())
              .toList() ??
          const [],
      xp: computedXp,
      difficulty: diff,
      questionType: qType,
    );
  }
}

class LessonNodeModel {
  final String id;
  final String type; // CONTENT, CHOICE, QUESTION, TEXT_INPUT, COMPLETION
  final String text;
  final String? mediaUrl;
  final String avatarPersona;
  final List<ChoiceOptionModel> choiceOptions;
  final String? inputPlaceholder;
  final QuestionInlineModel? inlineQuestion;
  final bool interruptible;

  LessonNodeModel({
    required this.id,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.avatarPersona = 'TUTOR',
    this.choiceOptions = const [],
    this.inputPlaceholder,
    this.inlineQuestion,
    this.interruptible = false,
  });

  bool get isCompletion => type == 'COMPLETION';
  bool get isChoice => type == 'CHOICE';
  bool get isQuestion => type == 'QUESTION';
  bool get isTextInput => type == 'TEXT_INPUT';

  List<String> get hints => inlineQuestion?.hints ?? const [];
  int get xp => inlineQuestion != null
      ? QuestionInlineModel.calculateQuestionXp(
          inlineQuestion!.questionType, inlineQuestion!.difficulty)
      : 10;
  String get difficulty => inlineQuestion?.difficulty ?? 'EASY';
  String get questionType => inlineQuestion?.questionType ?? 'PRACTICE';

  factory LessonNodeModel.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final input = json['input'] as Map<String, dynamic>?;
    final qRef = json['questionReference'] as Map<String, dynamic>?;

    List<ChoiceOptionModel> parsedOptions = [];
    if (input != null && input['options'] != null) {
      parsedOptions = (input['options'] as List<dynamic>)
          .map((o) => ChoiceOptionModel.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    QuestionInlineModel? parsedInline;
    if (qRef != null && qRef['inlineData'] != null) {
      parsedInline = QuestionInlineModel.fromJson(
        qRef['inlineData'] as Map<String, dynamic>,
      );
    }

    return LessonNodeModel(
      id: json['id'] as String,
      type: json['type'] as String,
      text: content['text'] as String? ?? '',
      mediaUrl: content['mediaUrl'] as String?,
      avatarPersona: content['avatarPersona'] as String? ?? 'TUTOR',
      choiceOptions: parsedOptions,
      inputPlaceholder: input?['placeholder'] as String?,
      inlineQuestion: parsedInline,
      interruptible: json['interruptible'] as bool? ?? false,
    );
  }
}
