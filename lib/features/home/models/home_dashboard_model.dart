import '../../pvp/ranked/ranked_models.dart';

class HomePerformance {
  final int attempted;
  final int correct;
  final double? accuracy;
  final double? averageSolveTimeMs;
  const HomePerformance({
    this.attempted = 0,
    this.correct = 0,
    this.accuracy,
    this.averageSolveTimeMs,
  });
  factory HomePerformance.fromJson(Map<String, dynamic> json) =>
      HomePerformance(
        attempted: (json['attempted'] as num).toInt(),
        correct: (json['correct'] as num).toInt(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        averageSolveTimeMs: (json['averageSolveTimeMs'] as num?)?.toDouble(),
      );
}

class HomeActivityDay {
  final String date;
  final int attempted;
  final int correct;
  final bool dailyChallengeCompleted;
  const HomeActivityDay(
    this.date,
    this.attempted,
    this.correct, {
    this.dailyChallengeCompleted = false,
  });
  factory HomeActivityDay.fromJson(Map<String, dynamic> j) => HomeActivityDay(
    j['date'],
    (j['attempted'] as num).toInt(),
    (j['correct'] as num).toInt(),
    dailyChallengeCompleted: j['dailyChallengeCompleted'] == true,
  );
}

class HomeResume {
  final String stepId;
  final String title;
  final String? topic;
  const HomeResume(this.stepId, this.title, this.topic);
  factory HomeResume.fromJson(Map<String, dynamic> j) =>
      HomeResume(j['stepId'], j['title'], j['topic']);
}

class HomeBadge {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;
  final bool unlocked;
  const HomeBadge(
    this.title,
    this.description,
    this.progress,
    this.target,
    this.unlocked, {
    this.id = '',
  });
  factory HomeBadge.fromJson(Map<String, dynamic> j) => HomeBadge(
    j['title'],
    j['description'],
    (j['progress'] as num).toInt(),
    (j['target'] as num).toInt(),
    j['unlocked'],
    id: j['id'] as String? ?? '',
  );
}

class HomeRanked {
  final String result;
  final int correct;
  final int questions;
  const HomeRanked(this.result, this.correct, this.questions);
  factory HomeRanked.fromJson(Map<String, dynamic> j) =>
      HomeRanked(j['result'], j['correct'], j['questions']);
}

class HomeDashboardModel {
  final String? today;
  final HomePerformance performance;
  final Map<String, HomePerformance> difficulty;
  final List<HomeActivityDay> activity;
  final List<HomeBadge> badges;
  final HomeResume? resume;
  final HomeRanked? ranked;
  final RankedSection? rankedLeague;
  const HomeDashboardModel({
    this.today,
    required this.performance,
    required this.difficulty,
    required this.activity,
    required this.badges,
    this.resume,
    this.ranked,
    this.rankedLeague,
  });
  factory HomeDashboardModel.fromJson(Map<String, dynamic> j) =>
      HomeDashboardModel(
        today: j['today'],
        performance: HomePerformance.fromJson(j['performance']),
        difficulty: {
          for (final row in j['difficulty'])
            row['difficulty'] as String: HomePerformance.fromJson(row),
        },
        activity: [
          for (final row in j['activity']) HomeActivityDay.fromJson(row),
        ],
        badges: [for (final row in j['badges']) HomeBadge.fromJson(row)],
        resume: j['resume'] == null ? null : HomeResume.fromJson(j['resume']),
        ranked: j['ranked'] == null ? null : HomeRanked.fromJson(j['ranked']),
        rankedLeague: RankedSection.parse(j['rankedLeague']),
      );
}
