// Aptiqu XP Progression & Level-Up Models

class XpProgressModel {
  final int earned;
  final int previousTotal;
  final int total;
  final int level;
  final int currentLevelStartXp;
  final int nextLevelStartXp;
  final int xpIntoCurrentLevel;
  final int xpRequiredForNextLevel;
  final int xpRemainingToNextLevel;
  final double progress;

  const XpProgressModel({
    this.earned = 0,
    this.previousTotal = 0,
    this.total = 0,
    this.level = 1,
    this.currentLevelStartXp = 0,
    this.nextLevelStartXp = 20,
    this.xpIntoCurrentLevel = 0,
    this.xpRequiredForNextLevel = 20,
    this.xpRemainingToNextLevel = 20,
    this.progress = 0.0,
  });

  factory XpProgressModel.initial() {
    return const XpProgressModel();
  }

  factory XpProgressModel.fromJson(Map<String, dynamic> json) {
    return XpProgressModel(
      earned: (json['earned'] as num?)?.toInt() ?? 0,
      previousTotal: (json['previousTotal'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? (json['totalXp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentLevelStartXp: (json['currentLevelStartXp'] as num?)?.toInt() ?? 0,
      nextLevelStartXp: (json['nextLevelStartXp'] as num?)?.toInt() ?? 20,
      xpIntoCurrentLevel: (json['xpIntoCurrentLevel'] as num?)?.toInt() ?? 0,
      xpRequiredForNextLevel:
          (json['xpRequiredForNextLevel'] as num?)?.toInt() ?? 20,
      xpRemainingToNextLevel:
          (json['xpRemainingToNextLevel'] as num?)?.toInt() ?? 20,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'earned': earned,
      'previousTotal': previousTotal,
      'total': total,
      'level': level,
      'currentLevelStartXp': currentLevelStartXp,
      'nextLevelStartXp': nextLevelStartXp,
      'xpIntoCurrentLevel': xpIntoCurrentLevel,
      'xpRequiredForNextLevel': xpRequiredForNextLevel,
      'xpRemainingToNextLevel': xpRemainingToNextLevel,
      'progress': progress,
    };
  }

  XpProgressModel copyWith({
    int? earned,
    int? previousTotal,
    int? total,
    int? level,
    int? currentLevelStartXp,
    int? nextLevelStartXp,
    int? xpIntoCurrentLevel,
    int? xpRequiredForNextLevel,
    int? xpRemainingToNextLevel,
    double? progress,
  }) {
    return XpProgressModel(
      earned: earned ?? this.earned,
      previousTotal: previousTotal ?? this.previousTotal,
      total: total ?? this.total,
      level: level ?? this.level,
      currentLevelStartXp: currentLevelStartXp ?? this.currentLevelStartXp,
      nextLevelStartXp: nextLevelStartXp ?? this.nextLevelStartXp,
      xpIntoCurrentLevel: xpIntoCurrentLevel ?? this.xpIntoCurrentLevel,
      xpRequiredForNextLevel:
          xpRequiredForNextLevel ?? this.xpRequiredForNextLevel,
      xpRemainingToNextLevel:
          xpRemainingToNextLevel ?? this.xpRemainingToNextLevel,
      progress: progress ?? this.progress,
    );
  }
}

class LevelUpModel {
  final bool occurred;
  final int fromLevel;
  final int toLevel;
  final int levelsGained;

  const LevelUpModel({
    this.occurred = false,
    this.fromLevel = 1,
    this.toLevel = 1,
    this.levelsGained = 0,
  });

  factory LevelUpModel.none(int currentLevel) {
    return LevelUpModel(
      occurred: false,
      fromLevel: currentLevel,
      toLevel: currentLevel,
      levelsGained: 0,
    );
  }

  factory LevelUpModel.fromJson(Map<String, dynamic> json) {
    return LevelUpModel(
      occurred: json['occurred'] as bool? ?? false,
      fromLevel: (json['fromLevel'] as num?)?.toInt() ?? 1,
      toLevel: (json['toLevel'] as num?)?.toInt() ?? 1,
      levelsGained: (json['levelsGained'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'occurred': occurred,
      'fromLevel': fromLevel,
      'toLevel': toLevel,
      'levelsGained': levelsGained,
    };
  }
}
