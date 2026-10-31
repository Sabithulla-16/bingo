enum MatchOutcome { victory, defeat, draw }

/// Record of an individual completed game.
class MatchRecord {
  final String id;
  final String roomName;
  final int roundNumber;
  final int linesClaimed;
  final int callsCount;
  final MatchOutcome outcome;
  final DateTime timestamp;

  const MatchRecord({
    required this.id,
    required this.roomName,
    required this.roundNumber,
    required this.linesClaimed,
    required this.callsCount,
    required this.outcome,
    required this.timestamp,
  });

  String get formattedTimeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Today, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      id: json['id'] as String,
      roomName: json['room_name'] as String? ?? 'Casual Game',
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      linesClaimed: (json['lines_claimed'] as num?)?.toInt() ?? 0,
      callsCount: (json['calls_count'] as num?)?.toInt() ?? 0,
      outcome: MatchOutcome.values.firstWhere(
        (e) => e.name == json['outcome'],
        orElse: () => MatchOutcome.defeat,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_name': roomName,
      'round_number': roundNumber,
      'lines_claimed': linesClaimed,
      'calls_count': callsCount,
      'outcome': outcome.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Lifetime career statistics for a player.
class PlayerCareerStats {
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int bestStreak;
  final int highestLinesClaimed;
  final double averageCallsPerMatch;
  final List<MatchRecord> recentMatches;

  const PlayerCareerStats({
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.highestLinesClaimed = 0,
    this.averageCallsPerMatch = 0.0,
    this.recentMatches = const [],
  });

  /// Overall win percentage (0 to 100).
  int get winRatePercentage {
    if (totalMatches == 0) return 0;
    return ((wins / totalMatches) * 100).round();
  }

  factory PlayerCareerStats.fromJson(Map<String, dynamic> json) {
    final matchesJson = json['recent_matches'] as List<dynamic>? ?? [];
    return PlayerCareerStats(
      totalMatches: (json['total_matches'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
      highestLinesClaimed:
          (json['highest_lines_claimed'] as num?)?.toInt() ?? 0,
      averageCallsPerMatch:
          (json['average_calls_per_match'] as num?)?.toDouble() ?? 0.0,
      recentMatches: matchesJson
          .map((e) => MatchRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_matches': totalMatches,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'highest_lines_claimed': highestLinesClaimed,
      'average_calls_per_match': averageCallsPerMatch,
      'recent_matches': recentMatches.map((e) => e.toJson()).toList(),
    };
  }

  static PlayerCareerStats sampleData() {
    return PlayerCareerStats(
      totalMatches: 25,
      wins: 12,
      losses: 10,
      draws: 3,
      currentStreak: 2,
      bestStreak: 5,
      highestLinesClaimed: 5,
      averageCallsPerMatch: 18.4,
      recentMatches: [
        MatchRecord(
          id: 'm_25',
          roomName: 'Friday BINGO Club',
          roundNumber: 5,
          linesClaimed: 5,
          callsCount: 18,
          outcome: MatchOutcome.victory,
          timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        ),
        MatchRecord(
          id: 'm_24',
          roomName: 'Weekend BINGO',
          roundNumber: 2,
          linesClaimed: 3,
          callsCount: 21,
          outcome: MatchOutcome.defeat,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        MatchRecord(
          id: 'm_23',
          roomName: 'Friends Room',
          roundNumber: 1,
          linesClaimed: 4,
          callsCount: 25,
          outcome: MatchOutcome.draw,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
        MatchRecord(
          id: 'm_22',
          roomName: 'Friday BINGO Club',
          roundNumber: 4,
          linesClaimed: 5,
          callsCount: 16,
          outcome: MatchOutcome.victory,
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ],
    );
  }
}
