/// Aptiqu User Domain Model
/// Consistent with backend multi-schema database models.
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime? dob;
  final String gender;
  final String religion;
  final String country;
  final String avatarUrl;
  final int level;
  final int totalXp;
  final int xpIntoCurrentLevel;
  final int xpRequiredForNextLevel;
  final double progress;
  final String streak;
  final int coins;
  final bool isRegistrationComplete;
  final UserStatsModel? stats;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    this.lastName = '',
    this.dob,
    this.gender = '',
    this.religion = '',
    this.country = '',
    this.avatarUrl = '',
    this.level = 1,
    this.totalXp = 0,
    this.xpIntoCurrentLevel = 0,
    this.xpRequiredForNextLevel = 20,
    this.progress = 0.0,
    this.streak = '0d',
    this.coins = 0,
    this.isRegistrationComplete = false,
    this.stats,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? gender,
    String? religion,
    String? country,
    String? avatarUrl,
    int? level,
    int? totalXp,
    int? xpIntoCurrentLevel,
    int? xpRequiredForNextLevel,
    double? progress,
    String? streak,
    int? coins,
    bool? isRegistrationComplete,
    UserStatsModel? stats,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      religion: religion ?? this.religion,
      country: country ?? this.country,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      xpIntoCurrentLevel: xpIntoCurrentLevel ?? this.xpIntoCurrentLevel,
      xpRequiredForNextLevel:
          xpRequiredForNextLevel ?? this.xpRequiredForNextLevel,
      progress: progress ?? this.progress,
      streak: streak ?? this.streak,
      coins: coins ?? this.coins,
      isRegistrationComplete:
          isRegistrationComplete ?? this.isRegistrationComplete,
      stats: stats ?? this.stats,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      gender: json['gender'] ?? '',
      religion: json['religion'] ?? '',
      country: json['country'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalXp: (json['totalXp'] as num?)?.toInt() ??
          (json['xp']?['total'] as num?)?.toInt() ??
          0,
      xpIntoCurrentLevel:
          (json['xpIntoCurrentLevel'] as num?)?.toInt() ??
          (json['xp']?['xpIntoCurrentLevel'] as num?)?.toInt() ??
          0,
      xpRequiredForNextLevel:
          (json['xpRequiredForNextLevel'] as num?)?.toInt() ??
          (json['xp']?['xpRequiredForNextLevel'] as num?)?.toInt() ??
          20,
      progress: (json['progress'] as num?)?.toDouble() ??
          (json['xp']?['progress'] as num?)?.toDouble() ??
          0.0,
      // Streak from backend
      streak: json['streak']?.toString() ?? '0d',
      // Coins from backend
      coins: json['coins'] ?? 0,
      isRegistrationComplete: json['isRegistrationComplete'] ?? false,
      stats: json['stats'] != null
          ? UserStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Default demo user matching Shagun
  factory UserModel.demoShagun() {
    return UserModel(
      id: 'shagun_101',
      email: 'shagun@gmail.com',
      firstName: 'Shagun',
      lastName: 'Kumar',
      dob: DateTime(2002, 5, 14),
      gender: 'Male',
      religion: 'Prefer not to say',
      country: 'India',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
      level: 1,
      streak: '0d',
      coins: 0,
      isRegistrationComplete: true,
      stats: const UserStatsModel(),
    );
  }
}

class TopicStatsModel {
  final int completed;
  final int total;

  const TopicStatsModel({this.completed = 0, this.total = 0});

  factory TopicStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TopicStatsModel();
    return TopicStatsModel(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionDifficultyStatsModel {
  final int solved;
  final int total;

  const QuestionDifficultyStatsModel({this.solved = 0, this.total = 0});

  factory QuestionDifficultyStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QuestionDifficultyStatsModel();
    return QuestionDifficultyStatsModel(
      solved: (json['solved'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionStatsModel {
  final QuestionDifficultyStatsModel easy;
  final QuestionDifficultyStatsModel medium;
  final QuestionDifficultyStatsModel hard;

  const QuestionStatsModel({
    this.easy = const QuestionDifficultyStatsModel(),
    this.medium = const QuestionDifficultyStatsModel(),
    this.hard = const QuestionDifficultyStatsModel(),
  });

  factory QuestionStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QuestionStatsModel();
    return QuestionStatsModel(
      easy: QuestionDifficultyStatsModel.fromJson(
          json['easy'] as Map<String, dynamic>?),
      medium: QuestionDifficultyStatsModel.fromJson(
          json['medium'] as Map<String, dynamic>?),
      hard: QuestionDifficultyStatsModel.fromJson(
          json['hard'] as Map<String, dynamic>?),
    );
  }
}

class UserStatsModel {
  final TopicStatsModel topics;
  final QuestionStatsModel questions;

  const UserStatsModel({
    this.topics = const TopicStatsModel(),
    this.questions = const QuestionStatsModel(),
  });

  factory UserStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserStatsModel();
    return UserStatsModel(
      topics: TopicStatsModel.fromJson(json['topics'] as Map<String, dynamic>?),
      questions:
          QuestionStatsModel.fromJson(json['questions'] as Map<String, dynamic>?),
    );
  }
}
