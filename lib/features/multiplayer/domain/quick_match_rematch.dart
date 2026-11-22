import 'package:flutter/foundation.dart';
import 'quick_match.dart';

enum QuickMatchRematchStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled;

  static QuickMatchRematchStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'ACCEPTED':
        return QuickMatchRematchStatus.accepted;
      case 'DECLINED':
        return QuickMatchRematchStatus.declined;
      case 'EXPIRED':
        return QuickMatchRematchStatus.expired;
      case 'CANCELLED':
        return QuickMatchRematchStatus.cancelled;
      case 'PENDING':
      default:
        return QuickMatchRematchStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case QuickMatchRematchStatus.accepted:
        return 'ACCEPTED';
      case QuickMatchRematchStatus.declined:
        return 'DECLINED';
      case QuickMatchRematchStatus.expired:
        return 'EXPIRED';
      case QuickMatchRematchStatus.cancelled:
        return 'CANCELLED';
      case QuickMatchRematchStatus.pending:
        return 'PENDING';
    }
  }
}

@immutable
class QuickMatchRematchRequest {
  final String id;
  final String previousMatchId;
  final String requesterUserId;
  final String opponentUserId;
  final QuickMatchRematchStatus status;
  final String? newMatchId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime updatedAt;
  final QuickMatchOpponent? opponent;

  const QuickMatchRematchRequest({
    required this.id,
    required this.previousMatchId,
    required this.requesterUserId,
    required this.opponentUserId,
    required this.status,
    this.newMatchId,
    required this.expiresAt,
    required this.createdAt,
    this.respondedAt,
    required this.updatedAt,
    this.opponent,
  });

  bool get isPending => status == QuickMatchRematchStatus.pending;
  bool get isAccepted => status == QuickMatchRematchStatus.accepted;
  bool get isDeclined => status == QuickMatchRematchStatus.declined;
  bool get isExpired =>
      status == QuickMatchRematchStatus.expired ||
      (isPending && DateTime.now().isAfter(expiresAt));
  bool get isCancelled => status == QuickMatchRematchStatus.cancelled;

  bool isRequester(String currentUserId) => requesterUserId == currentUserId;

  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory QuickMatchRematchRequest.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    QuickMatchOpponent? opp;
    if (json['opponent'] is Map) {
      opp = QuickMatchOpponent.fromJson(
        Map<String, dynamic>.from(json['opponent'] as Map),
      );
    }

    return QuickMatchRematchRequest(
      id: json['id'] as String? ?? json['request_id'] as String? ?? '',
      previousMatchId: json['previous_match_id'] as String? ?? '',
      requesterUserId: json['requester_user_id'] as String? ??
          (json['is_requester'] == true ? currentUserId ?? '' : ''),
      opponentUserId: json['opponent_user_id'] as String? ?? '',
      status: QuickMatchRematchStatus.fromString(json['status'] as String?),
      newMatchId: json['new_match_id'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())?.toLocal() ??
              DateTime.now().add(const Duration(seconds: 30))
          : DateTime.now().add(const Duration(seconds: 30)),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'].toString())?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      opponent: opp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'previous_match_id': previousMatchId,
      'requester_user_id': requesterUserId,
      'opponent_user_id': opponentUserId,
      'status': status.toDbString(),
      'new_match_id': newMatchId,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

@immutable
class QuickMatchParticipantResult {
  final String id;
  final String displayName;
  final String avatarColorHex;
  final int linesClaimed;
  final List<String> claimedLineTypes;
  final bool isWinner;
  final bool isForfeited;

  const QuickMatchParticipantResult({
    required this.id,
    required this.displayName,
    required this.avatarColorHex,
    required this.linesClaimed,
    this.claimedLineTypes = const [],
    this.isWinner = false,
    this.isForfeited = false,
  });

  factory QuickMatchParticipantResult.fromJson(Map<String, dynamic> json) {
    return QuickMatchParticipantResult(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Player',
      avatarColorHex: json['avatar_color_hex'] as String? ?? '#20243A',
      linesClaimed: (json['lines_claimed'] as num?)?.toInt() ?? 0,
      claimedLineTypes: (json['claimed_line_types'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isWinner: json['is_winner'] == true,
      isForfeited: json['is_forfeited'] == true,
    );
  }
}

@immutable
class QuickMatchResultData {
  final String matchId;
  final String roomId;
  final String roomCode;
  final String gameId;
  final QuickMatchStatus status;
  final String? winnerUserId;
  final int totalCalls;
  final int durationSeconds;
  final List<int> calledNumbers;
  final QuickMatchParticipantResult player1;
  final QuickMatchParticipantResult player2;

  const QuickMatchResultData({
    required this.matchId,
    required this.roomId,
    required this.roomCode,
    required this.gameId,
    required this.status,
    this.winnerUserId,
    this.totalCalls = 0,
    this.durationSeconds = 0,
    this.calledNumbers = const [],
    required this.player1,
    required this.player2,
  });

  bool isVictory(String currentUserId) {
    if (winnerUserId != null && winnerUserId!.isNotEmpty) {
      return winnerUserId == currentUserId;
    }
    final me = myResult(currentUserId);
    final opp = opponentResult(currentUserId);
    if (me.isForfeited) return false;
    if (opp.isForfeited) return true;
    return me.isWinner || (me.linesClaimed >= 5 && opp.linesClaimed < 5);
  }

  bool isDraw(String currentUserId) {
    final me = myResult(currentUserId);
    final opp = opponentResult(currentUserId);
    if (me.isForfeited || opp.isForfeited) return false;
    return winnerUserId == null && me.linesClaimed == opp.linesClaimed;
  }

  QuickMatchParticipantResult myResult(String currentUserId) {
    if (player1.id == currentUserId) return player1;
    return player2;
  }

  QuickMatchParticipantResult opponentResult(String currentUserId) {
    if (player1.id == currentUserId) return player2;
    return player1;
  }

  factory QuickMatchResultData.fromJson(Map<String, dynamic> json) {
    final p1 = json['player1'] is Map
        ? QuickMatchParticipantResult.fromJson(
            Map<String, dynamic>.from(json['player1'] as Map))
        : const QuickMatchParticipantResult(
            id: '',
            displayName: 'Player 1',
            avatarColorHex: '#20243A',
            linesClaimed: 0,
          );

    final p2 = json['player2'] is Map
        ? QuickMatchParticipantResult.fromJson(
            Map<String, dynamic>.from(json['player2'] as Map))
        : const QuickMatchParticipantResult(
            id: '',
            displayName: 'Player 2',
            avatarColorHex: '#FC695C',
            linesClaimed: 0,
          );

    final called = (json['called_numbers'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [];

    return QuickMatchResultData(
      matchId: json['match_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      roomCode: json['room_code'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      status: QuickMatchStatus.fromString(json['status'] as String?),
      winnerUserId: json['winner_user_id'] as String?,
      totalCalls: (json['total_calls'] as num?)?.toInt() ?? called.length,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      calledNumbers: called,
      player1: p1,
      player2: p2,
    );
  }
}
