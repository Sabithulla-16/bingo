import 'package:flutter/foundation.dart';

/// Represents a single player's performance outcome in a finished round.
@immutable
class RoundPlayerOutcome {
  final String userId;
  final String displayName;
  final String avatarColorHex;
  final bool isWinner;
  final bool isHost;
  final bool isYou;
  final bool isForfeited;
  final int linesClaimedCount;
  final List<String> claimedLetters;

  const RoundPlayerOutcome({
    required this.userId,
    required this.displayName,
    this.avatarColorHex = '#FC695C',
    this.isWinner = false,
    this.isHost = false,
    this.isYou = false,
    this.isForfeited = false,
    this.linesClaimedCount = 0,
    this.claimedLetters = const [],
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'avatar_color_hex': avatarColorHex,
    'is_winner': isWinner,
    'is_host': isHost,
    'is_forfeited': isForfeited,
    'lines_claimed_count': linesClaimedCount,
    'claimed_letters': claimedLetters,
  };

  factory RoundPlayerOutcome.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final uid = (json['user_id'] ?? json['id']) as String? ?? '';
    final linesCount = (json['lines_claimed_count'] as num?)?.toInt() ??
        (json['lines_claimed'] as num?)?.toInt() ??
        0;
    final isWin = (json['is_winner'] as bool? ?? false) || linesCount >= 5;
    final isForfeited = json['is_forfeited'] == true;
    return RoundPlayerOutcome(
      userId: uid,
      displayName: (json['display_name'] ?? json['name']) as String? ?? 'Player',
      avatarColorHex: json['avatar_color_hex'] as String? ?? '#FC695C',
      isWinner: isWin,
      isHost: json['is_host'] as bool? ?? false,
      isYou: currentUserId != null && currentUserId == uid,
      isForfeited: isForfeited,
      linesClaimedCount: linesCount,
      claimedLetters:
          (json['claimed_letters'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['B', 'I', 'N', 'G', 'O'].take(linesCount).toList(),
    );
  }
}

/// Historical record of a completed round in a room.
@immutable
class RoomRoundRecord {
  final String id;
  final String roomId;
  final int roundNumber;
  final String? winnerId;
  final String winnerName;
  final int totalCalls;
  final int playerCount;
  final List<RoundPlayerOutcome> playerOutcomes;
  final DateTime finishedAt;

  const RoomRoundRecord({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    this.winnerId,
    required this.winnerName,
    required this.totalCalls,
    required this.playerCount,
    required this.playerOutcomes,
    required this.finishedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_id': roomId,
    'round_number': roundNumber,
    'winner_id': winnerId,
    'winner_name': winnerName,
    'total_calls': totalCalls,
    'player_count': playerCount,
    'player_outcomes': playerOutcomes.map((o) => o.toJson()).toList(),
    'finished_at': finishedAt.toIso8601String(),
  };

  factory RoomRoundRecord.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final outcomesRaw =
        (json['player_outcomes'] ?? json['outcomes']) as List<dynamic>? ?? [];
    final wId = (json['winner_id'] ?? json['winner_user_id']) as String?;
    final wName =
        (json['winner_name'] ?? json['winner_display_name']) as String? ?? 'Winner';
    final finishedTimeStr =
        (json['finished_at'] ?? json['completed_at']) as String?;
    final pCount = (json['player_count'] as num?)?.toInt() ?? outcomesRaw.length;

    return RoomRoundRecord(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      winnerId: wId,
      winnerName: wName,
      totalCalls: (json['total_calls'] as num?)?.toInt() ?? 0,
      playerCount: pCount > 0 ? pCount : outcomesRaw.length,
      playerOutcomes: outcomesRaw
          .map(
            (o) => RoundPlayerOutcome.fromJson(
              o as Map<String, dynamic>,
              currentUserId: currentUserId,
            ),
          )
          .toList(),
      finishedAt: finishedTimeStr != null
          ? DateTime.tryParse(finishedTimeStr) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Cumulative standings for a player in a room session across all played rounds.
@immutable
class RoomPlayerStanding {
  final String userId;
  final String displayName;
  final String avatarColorHex;
  final bool isHost;
  final bool isYou;
  final int rank;
  final int roundsPlayed;
  final int roundsWon;
  final int draws;
  final int losses;
  final double winRate;
  final int currentStreak;
  final int bestStreak;
  final String lastResult;
  final List<int> wonRounds;

  const RoomPlayerStanding({
    required this.userId,
    required this.displayName,
    this.avatarColorHex = '#FC695C',
    this.isHost = false,
    this.isYou = false,
    this.rank = 1,
    this.roundsPlayed = 0,
    this.roundsWon = 0,
    this.draws = 0,
    this.losses = 0,
    this.winRate = 0.0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastResult = '',
    this.wonRounds = const [],
  });

  RoomPlayerStanding copyWith({
    int? rank,
    int? roundsPlayed,
    int? roundsWon,
    int? draws,
    int? losses,
    double? winRate,
    int? currentStreak,
    int? bestStreak,
    String? lastResult,
    List<int>? wonRounds,
  }) {
    return RoomPlayerStanding(
      userId: userId,
      displayName: displayName,
      avatarColorHex: avatarColorHex,
      isHost: isHost,
      isYou: isYou,
      rank: rank ?? this.rank,
      roundsPlayed: roundsPlayed ?? this.roundsPlayed,
      roundsWon: roundsWon ?? this.roundsWon,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      winRate: winRate ?? this.winRate,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastResult: lastResult ?? this.lastResult,
      wonRounds: wonRounds ?? this.wonRounds,
    );
  }
}

/// High-level 3-card bento summary for a room session.
@immutable
class RoomSessionOverview {
  final int totalRounds;
  final int activePlayers;
  final String leaderName;
  final int leaderWins;

  const RoomSessionOverview({
    required this.totalRounds,
    required this.activePlayers,
    required this.leaderName,
    required this.leaderWins,
  });
}
