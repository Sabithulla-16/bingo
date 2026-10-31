enum MultiplayerGameStatus {
  preparing,
  inProgress,
  completed,
  cancelled;

  static MultiplayerGameStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return MultiplayerGameStatus.inProgress;
      case 'completed':
        return MultiplayerGameStatus.completed;
      case 'cancelled':
        return MultiplayerGameStatus.cancelled;
      case 'preparing':
      default:
        return MultiplayerGameStatus.preparing;
    }
  }

  String toDbString() {
    switch (this) {
      case MultiplayerGameStatus.inProgress:
        return 'in_progress';
      case MultiplayerGameStatus.completed:
        return 'completed';
      case MultiplayerGameStatus.cancelled:
        return 'cancelled';
      case MultiplayerGameStatus.preparing:
        return 'preparing';
    }
  }
}

class MultiplayerGame {
  final String id;
  final String roomId;
  final MultiplayerGameStatus status;
  final DateTime prepDeadline;
  final String? currentTurnUserId;
  final DateTime? turnDeadline;
  final List<int> calledNumbers;
  final int roundNumber;
  final String? winnerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MultiplayerGame({
    required this.id,
    required this.roomId,
    required this.status,
    required this.prepDeadline,
    this.currentTurnUserId,
    this.turnDeadline,
    this.calledNumbers = const [],
    this.roundNumber = 1,
    this.winnerUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  int? get lastCalledNumber =>
      calledNumbers.isNotEmpty ? calledNumbers.last : null;

  String? get winnerId => winnerUserId;

  bool isNumberCalled(int number) => calledNumbers.contains(number);

  MultiplayerGame copyWith({
    String? id,
    String? roomId,
    MultiplayerGameStatus? status,
    DateTime? prepDeadline,
    String? currentTurnUserId,
    DateTime? turnDeadline,
    List<int>? calledNumbers,
    int? roundNumber,
    String? winnerUserId,
    String? winnerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MultiplayerGame(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      prepDeadline: prepDeadline ?? this.prepDeadline,
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      calledNumbers: calledNumbers ?? this.calledNumbers,
      roundNumber: roundNumber ?? this.roundNumber,
      winnerUserId: winnerId ?? winnerUserId ?? this.winnerUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MultiplayerGame.fromJson(Map<String, dynamic> json) {
    final called = (json['called_numbers'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];

    return MultiplayerGame(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      status: MultiplayerGameStatus.fromString(json['status'] as String? ?? 'preparing'),
      prepDeadline: json['prep_deadline'] != null
          ? DateTime.parse(json['prep_deadline'] as String)
          : DateTime.now().add(const Duration(seconds: 45)),
      currentTurnUserId: json['current_turn_user_id'] as String?,
      turnDeadline: json['turn_deadline'] != null
          ? DateTime.parse(json['turn_deadline'] as String)
          : null,
      calledNumbers: called,
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      winnerUserId: json['winner_user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'status': status.toDbString(),
      'prep_deadline': prepDeadline.toIso8601String(),
      'current_turn_user_id': currentTurnUserId,
      'turn_deadline': turnDeadline?.toIso8601String(),
      'called_numbers': calledNumbers,
      'round_number': roundNumber,
      'winner_user_id': winnerUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class MultiplayerPlayerState {
  final String userId;
  final String displayName;
  final String avatarColorHex;
  final List<int> boardNumbers;
  final bool isBoardConfirmed;
  final int linesClaimed;
  final List<String> claimedLineTypes;
  final bool isWinner;
  final int seatIndex;
  final bool isHost;

  const MultiplayerPlayerState({
    required this.userId,
    required this.displayName,
    required this.avatarColorHex,
    this.boardNumbers = const [],
    this.isBoardConfirmed = false,
    this.linesClaimed = 0,
    this.claimedLineTypes = const [],
    this.isWinner = false,
    this.seatIndex = 0,
    this.isHost = false,
  });

  /// Letter progress: B-I-N-G-O (1 line = B, 2 = B-I, 3 = B-I-N, etc.)
  List<bool> get letterProgress {
    return [
      linesClaimed >= 1,
      linesClaimed >= 2,
      linesClaimed >= 3,
      linesClaimed >= 4,
      linesClaimed >= 5,
    ];
  }

  MultiplayerPlayerState copyWith({
    String? userId,
    String? displayName,
    String? avatarColorHex,
    List<int>? boardNumbers,
    bool? isBoardConfirmed,
    int? linesClaimed,
    List<String>? claimedLineTypes,
    bool? isWinner,
    int? seatIndex,
    bool? isHost,
  }) {
    return MultiplayerPlayerState(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      boardNumbers: boardNumbers ?? this.boardNumbers,
      isBoardConfirmed: isBoardConfirmed ?? this.isBoardConfirmed,
      linesClaimed: linesClaimed ?? this.linesClaimed,
      claimedLineTypes: claimedLineTypes ?? this.claimedLineTypes,
      isWinner: isWinner ?? this.isWinner,
      seatIndex: seatIndex ?? this.seatIndex,
      isHost: isHost ?? this.isHost,
    );
  }
}
