import 'package:flutter/foundation.dart';

enum MatchmakingQueueStatus {
  idle,
  searching,
  matched,
  cancelled,
  expired;

  static MatchmakingQueueStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'SEARCHING':
        return MatchmakingQueueStatus.searching;
      case 'MATCHED':
        return MatchmakingQueueStatus.matched;
      case 'CANCELLED':
        return MatchmakingQueueStatus.cancelled;
      case 'EXPIRED':
        return MatchmakingQueueStatus.expired;
      case 'IDLE':
      default:
        return MatchmakingQueueStatus.idle;
    }
  }

  String toDbString() {
    switch (this) {
      case MatchmakingQueueStatus.searching:
        return 'SEARCHING';
      case MatchmakingQueueStatus.matched:
        return 'MATCHED';
      case MatchmakingQueueStatus.cancelled:
        return 'CANCELLED';
      case MatchmakingQueueStatus.expired:
        return 'EXPIRED';
      case MatchmakingQueueStatus.idle:
        return 'IDLE';
    }
  }
}

enum QuickMatchStatus {
  countdown,
  boardPreparation,
  inProgress,
  completed,
  cancelled,
  forfeited;

  static QuickMatchStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'COUNTDOWN':
        return QuickMatchStatus.countdown;
      case 'BOARD_PREPARATION':
      case 'PREPARING':
        return QuickMatchStatus.boardPreparation;
      case 'IN_PROGRESS':
      case 'PLAYING':
        return QuickMatchStatus.inProgress;
      case 'COMPLETED':
        return QuickMatchStatus.completed;
      case 'CANCELLED':
        return QuickMatchStatus.cancelled;
      case 'FORFEITED':
        return QuickMatchStatus.forfeited;
      default:
        return QuickMatchStatus.countdown;
    }
  }

  String toDbString() {
    switch (this) {
      case QuickMatchStatus.countdown:
        return 'COUNTDOWN';
      case QuickMatchStatus.boardPreparation:
        return 'BOARD_PREPARATION';
      case QuickMatchStatus.inProgress:
        return 'IN_PROGRESS';
      case QuickMatchStatus.completed:
        return 'COMPLETED';
      case QuickMatchStatus.cancelled:
        return 'CANCELLED';
      case QuickMatchStatus.forfeited:
        return 'FORFEITED';
    }
  }
}

@immutable
class QuickMatchOpponent {
  final String id;
  final String displayName;
  final String avatarColorHex;

  const QuickMatchOpponent({
    required this.id,
    required this.displayName,
    required this.avatarColorHex,
  });

  factory QuickMatchOpponent.fromJson(Map<String, dynamic> json) {
    return QuickMatchOpponent(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Opponent',
      avatarColorHex: json['avatar_color_hex'] as String? ?? '#FC695C',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_color_hex': avatarColorHex,
    };
  }
}

@immutable
class MatchmakingQueueEntry {
  final String id;
  final String userId;
  final MatchmakingQueueStatus status;
  final DateTime queuedAt;
  final DateTime? matchedAt;
  final String? matchId;
  final String region;

  const MatchmakingQueueEntry({
    required this.id,
    required this.userId,
    required this.status,
    required this.queuedAt,
    this.matchedAt,
    this.matchId,
    this.region = 'auto',
  });

  factory MatchmakingQueueEntry.fromJson(Map<String, dynamic> json) {
    return MatchmakingQueueEntry(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: MatchmakingQueueStatus.fromString(json['status'] as String?),
      queuedAt: json['queued_at'] != null
          ? DateTime.parse(json['queued_at'] as String)
          : DateTime.now(),
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'] as String)
          : null,
      matchId: json['match_id'] as String?,
      region: json['region'] as String? ?? 'auto',
    );
  }
}

@immutable
class QuickMatch {
  final String id;
  final String roomId;
  final String roomCode;
  final String gameId;
  final String player1Id;
  final String player2Id;
  final QuickMatchStatus status;
  final DateTime countdownDeadline;
  final QuickMatchOpponent? opponent;
  final QuickMatchOpponent? player1;
  final QuickMatchOpponent? player2;

  const QuickMatch({
    required this.id,
    required this.roomId,
    required this.roomCode,
    required this.gameId,
    required this.player1Id,
    required this.player2Id,
    required this.status,
    required this.countdownDeadline,
    this.opponent,
    this.player1,
    this.player2,
  });

  factory QuickMatch.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final p1Json = json['player1'] as Map<String, dynamic>?;
    final p2Json = json['player2'] as Map<String, dynamic>?;
    final opponentJson = json['opponent'] as Map<String, dynamic>?;

    final p1 = p1Json != null ? QuickMatchOpponent.fromJson(p1Json) : null;
    final p2 = p2Json != null ? QuickMatchOpponent.fromJson(p2Json) : null;

    QuickMatchOpponent? derivedOpponent;
    if (opponentJson != null) {
      derivedOpponent = QuickMatchOpponent.fromJson(opponentJson);
    } else if (currentUserId != null) {
      if (json['player1_id'] == currentUserId && p2 != null) {
        derivedOpponent = p2;
      } else if (json['player2_id'] == currentUserId && p1 != null) {
        derivedOpponent = p1;
      }
    }

    return QuickMatch(
      id: json['match_id'] as String? ?? json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      roomCode: json['room_code'] as String? ?? '......',
      gameId: json['game_id'] as String? ?? '',
      player1Id: json['player1_id'] as String? ?? '',
      player2Id: json['player2_id'] as String? ?? '',
      status: QuickMatchStatus.fromString(json['status'] as String?),
      countdownDeadline: json['countdown_deadline'] != null
          ? DateTime.parse(json['countdown_deadline'] as String)
          : DateTime.now().add(const Duration(seconds: 10)),
      opponent: derivedOpponent,
      player1: p1,
      player2: p2,
    );
  }

  QuickMatch forUser(String currentUserId) {
    QuickMatchOpponent? derivedOpponent = opponent;
    if (player1Id == currentUserId && player2 != null) {
      derivedOpponent = player2;
    } else if (player2Id == currentUserId && player1 != null) {
      derivedOpponent = player1;
    }
    return QuickMatch(
      id: id,
      roomId: roomId,
      roomCode: roomCode,
      gameId: gameId,
      player1Id: player1Id,
      player2Id: player2Id,
      status: status,
      countdownDeadline: countdownDeadline,
      opponent: derivedOpponent,
      player1: player1,
      player2: player2,
    );
  }

  QuickMatch copyWith({
    String? id,
    String? roomId,
    String? roomCode,
    String? gameId,
    String? player1Id,
    String? player2Id,
    QuickMatchStatus? status,
    DateTime? countdownDeadline,
    QuickMatchOpponent? opponent,
    QuickMatchOpponent? player1,
    QuickMatchOpponent? player2,
  }) {
    return QuickMatch(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      gameId: gameId ?? this.gameId,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      status: status ?? this.status,
      countdownDeadline: countdownDeadline ?? this.countdownDeadline,
      opponent: opponent ?? this.opponent,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
    );
  }
}
