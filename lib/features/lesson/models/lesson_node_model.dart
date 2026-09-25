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

  QuestionInlineModel({
    required this.prompt,
    required this.options,
  });

  factory QuestionInlineModel.fromJson(Map<String, dynamic> json) {
    return QuestionInlineModel(
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => ChoiceOptionModel.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
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
