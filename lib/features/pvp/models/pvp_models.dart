class PvpPlayerInfoModel {
  final String userId;
  final String firstName;
  final String? avatarUrl;
  final int score;
  final bool isWinner;
  final int xpAwarded;
  final bool isAfk;

  const PvpPlayerInfoModel({
    required this.userId,
    required this.firstName,
    this.avatarUrl,
    this.score = 0,
    this.isWinner = false,
    this.xpAwarded = 0,
    this.isAfk = false,
  });

  factory PvpPlayerInfoModel.fromJson(Map<String, dynamic> json) {
    return PvpPlayerInfoModel(
      userId: json['userId'] as String,
      firstName: json['firstName'] as String? ?? 'Warrior',
      avatarUrl: json['avatarUrl'] as String?,
      score: json['score'] as int? ?? 0,
      isWinner: json['isWinner'] as bool? ?? false,
      xpAwarded: json['xpAwarded'] as int? ?? 0,
      isAfk: json['isAfk'] as bool? ?? false,
    );
  }
}

class PvpQuestionOptionModel {
  final String id;
  final String text;

  const PvpQuestionOptionModel({required this.id, required this.text});

  factory PvpQuestionOptionModel.fromJson(Map<String, dynamic> json) {
    return PvpQuestionOptionModel(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}

class PvpQuestionDataModel {
  final String id;
  final String prompt;
  final List<PvpQuestionOptionModel> options;
  final String difficulty;
  final String? pattern;
  final String? pyq;

  const PvpQuestionDataModel({
    required this.id,
    required this.prompt,
    required this.options,
    required this.difficulty,
    this.pattern,
    this.pyq,
  });

  factory PvpQuestionDataModel.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>?)
            ?.map((o) => PvpQuestionOptionModel.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];

    return PvpQuestionDataModel(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      options: opts,
      difficulty: json['difficulty'] as String? ?? 'EASY',
      pattern: json['pattern'] as String?,
      pyq: json['pyq'] as String?,
    );
  }
}
