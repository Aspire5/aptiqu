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
    this.xp = 10,
    this.difficulty = 'EASY',
    this.questionType = 'PRACTICE',
  });

  factory QuestionInlineModel.fromJson(Map<String, dynamic> json) {
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
      xp: (json['xp'] as num?)?.toInt() ?? 10,
      difficulty: json['difficulty'] as String? ?? 'EASY',
      questionType: json['questionType'] as String? ?? 'PRACTICE',
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
  int get xp => inlineQuestion?.xp ?? 10;
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
