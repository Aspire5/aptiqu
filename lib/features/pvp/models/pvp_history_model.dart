class PvpOpponentModel {
  final String? userId;
  final String name;
  final String? avatarUrl;
  final int level;

  const PvpOpponentModel({
    this.userId,
    required this.name,
    this.avatarUrl,
    required this.level,
  });

  factory PvpOpponentModel.fromJson(Map<String, dynamic> json) {
    return PvpOpponentModel(
      userId: json['userId']?.toString(),
      name: json['name']?.toString() ?? 'Opponent',
      avatarUrl: json['avatarUrl']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }
}

class PvpMatchHistoryItemModel {
  final String matchId;
  final int score;
  final int opponentScore;
  final int totalQuestions;
  final bool isWinner;
  final bool isTie;
  final int xpAwarded;
  final String joinedAt;
  final String status;
  final int avgResponseTimeMs;
  final PvpOpponentModel opponent;

  const PvpMatchHistoryItemModel({
    required this.matchId,
    required this.score,
    required this.opponentScore,
    required this.totalQuestions,
    required this.isWinner,
    required this.isTie,
    required this.xpAwarded,
    required this.joinedAt,
    required this.status,
    required this.avgResponseTimeMs,
    required this.opponent,
  });

  factory PvpMatchHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return PvpMatchHistoryItemModel(
      matchId: json['matchId']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      opponentScore: (json['opponentScore'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 10,
      isWinner: json['isWinner'] as bool? ?? false,
      isTie: json['isTie'] as bool? ?? false,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      joinedAt: json['joinedAt']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      avgResponseTimeMs: (json['avgResponseTimeMs'] as num?)?.toInt() ?? 0,
      opponent: PvpOpponentModel.fromJson(
        Map<String, dynamic>.from(json['opponent'] as Map? ?? {}),
      ),
    );
  }
}
