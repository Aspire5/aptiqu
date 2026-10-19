import 'package:intl/intl.dart';

enum RankedLeague {
  unranked,
  bronze,
  silver,
  gold,
  platinum,
  diamond;

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
  String get asset => 'assets/images/ranked/rank_$name.webp';
  static RankedLeague parse(Object? value) => values.firstWhere(
    (v) => v.name.toUpperCase() == value,
    orElse: () => throw const FormatException('Unknown league'),
  );
}

Map<String, dynamic> rankedMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
int rankedInt(Object? value) {
  if (value is! num || !value.isFinite || value != value.round()) {
    throw const FormatException('Invalid integer');
  }
  return value.toInt();
}

String signedElo(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '−${value.abs()}'
    : '0';
String seasonLabel(String id) {
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(id);
  if (match == null) return id;
  return DateFormat(
    'MMMM yyyy',
  ).format(DateTime.utc(int.parse(match[1]!), int.parse(match[2]!)));
}

String istInstant(DateTime instant) =>
    '${DateFormat('d MMM, HH:mm').format(instant.toUtc().add(const Duration(minutes: 330)))} IST';

class RankedSeason {
  final String id, status;
  final DateTime startsAt, endsAt;
  RankedSeason.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      status = j['status'] as String,
      startsAt = DateTime.parse(j['startsAt'] as String).toUtc(),
      endsAt = DateTime.parse(j['endsAt'] as String).toUtc();
  String get label => seasonLabel(id);
  bool get finalized => status == 'FINALIZED';
  String get context => status == 'CLOSING'
      ? 'Results finalizing'
      : finalized
      ? 'Final results'
      : status == 'NOT_STARTED'
      ? 'Season not started'
      : 'Ends ${istInstant(endsAt)}';
}

class RankedStanding {
  final RankedLeague league;
  final int rating,
      played,
      wins,
      losses,
      draws,
      version,
      completed,
      required,
      remaining;
  final int? position, peakRating;
  final bool qualified, provisional, hasRecord;
  final String? nextLabel;
  final int? toNext;
  final double? progress;
  RankedStanding.fromJson(Map<String, dynamic> j)
    : league = RankedLeague.parse(j['league']),
      rating = rankedInt(j['rating']),
      played = rankedInt(j['played']),
      wins = rankedInt(j['wins']),
      losses = rankedInt(j['losses']),
      draws = rankedInt(j['draws']),
      version = rankedInt(j['version']),
      qualified = j['qualified'] == true,
      provisional = j['ratingIsProvisional'] == true,
      hasRecord = j['hasRecord'] == true,
      position = j['position'] == null ? null : rankedInt(j['position']),
      peakRating = j['peakRating'] == null ? null : rankedInt(j['peakRating']),
      completed = rankedInt(rankedMap(j['placements'])['completed']),
      required = rankedInt(rankedMap(j['placements'])['required']),
      remaining = rankedInt(rankedMap(j['placements'])['remaining']),
      nextLabel = j['nextLeague'] == null
          ? null
          : RankedLeague.parse(rankedMap(j['nextLeague'])['league']).label,
      toNext = j['nextLeague'] == null
          ? null
          : rankedInt(rankedMap(j['nextLeague'])['remaining']),
      progress = j['nextLeague'] == null
          ? null
          : (rankedMap(j['nextLeague'])['progress'] as num?)?.toDouble();
  String get positionLabel => !qualified
      ? 'Not qualified yet'
      : position == null
      ? 'Global position unavailable'
      : 'Global #$position';
  String get placementLabel => 'Placements $completed of $required';
}

class RankedSummary {
  final RankedSeason season;
  final RankedStanding standing;
  final DateTime asOf;
  final String currentSeasonId;
  final String? activeMatchId, recoveryState;
  final bool admissionPaused, ratedAdmission, seedPending;
  RankedSummary.fromJson(Map<String, dynamic> j)
    : season = RankedSeason.fromJson(rankedMap(j['season'])),
      standing = RankedStanding.fromJson(rankedMap(j['standing'])),
      asOf = DateTime.parse(j['asOf'] as String).toUtc(),
      currentSeasonId = j['currentSeasonId'] as String,
      activeMatchId = j['activeMatch'] == null
          ? null
          : rankedMap(j['activeMatch'])['matchId'] as String?,
      recoveryState = j['activeMatch'] == null
          ? null
          : rankedMap(j['activeMatch'])['recoveryState'] as String?,
      seedPending = j['seedPending'] == true,
      admissionPaused =
          j['capabilities'] is Map &&
          rankedMap(j['capabilities'])['admissionPaused'] == true,
      ratedAdmission =
          j['capabilities'] is Map &&
          rankedMap(j['capabilities'])['ratedAdmission'] == true;
}

class RankedSection {
  final String status;
  final RankedSummary? summary;
  const RankedSection(this.status, [this.summary]);
  static RankedSection? parse(Object? value) {
    if (value == null) return null;
    try {
      final j = rankedMap(value);
      return j['status'] == 'AVAILABLE'
          ? RankedSection('AVAILABLE', RankedSummary.fromJson(j))
          : RankedSection(
              j['status'] == 'DISABLED' ? 'DISABLED' : 'UNAVAILABLE',
            );
    } catch (_) {
      return const RankedSection('UNAVAILABLE');
    }
  }
}

class RankedEntry {
  final String userId, name;
  final String? avatarUrl;
  final int rating, position;
  final RankedLeague league;
  RankedEntry.fromJson(Map<String, dynamic> j)
    : userId = j['userId'] as String,
      name = j['name'] as String,
      avatarUrl = j['avatarUrl'] as String?,
      rating = rankedInt(j['rating']),
      position = rankedInt(j['position']),
      league = RankedLeague.parse(j['league']);
}

class RankedChange {
  final String eventId, seasonId, changeKind;
  final int before, delta, after, version;
  final RankedLeague leagueBefore, leagueAfter;
  final int? placementCompleted, placementRequired;
  RankedChange.fromJson(Map<String, dynamic> j, {String? season})
    : eventId = j['eventId'] as String,
      seasonId = (j['seasonId'] ?? season) as String,
      changeKind = j['changeKind'] as String,
      before = rankedInt(j['before']),
      delta = rankedInt(j['delta']),
      after = rankedInt(j['after']),
      version = rankedInt(j['seasonVersionAfter']),
      leagueBefore = RankedLeague.parse(j['leagueBefore']),
      leagueAfter = RankedLeague.parse(j['leagueAfter']),
      placementCompleted = j['qualification'] is Map
          ? rankedInt(rankedMap(j['qualification'])['completed'])
          : null,
      placementRequired = j['qualification'] is Map
          ? rankedInt(rankedMap(j['qualification'])['required'])
          : null;
  static RankedChange? parse(Object? j, {String? season}) {
    try {
      final result = RankedChange.fromJson(rankedMap(j), season: season);
      return result.eventId.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  String get label => switch (changeKind) {
    'PROMOTION' => 'Promoted to ${leagueAfter.label}',
    'DEMOTION' => 'Now in ${leagueAfter.label}',
    'PLACEMENT_COMPLETE' => 'Placement complete · ${leagueAfter.label}',
    _ =>
      leagueAfter == RankedLeague.unranked
          ? 'Placements $placementCompleted of $placementRequired'
          : leagueAfter.label,
  };
}
