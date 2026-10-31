import 'package:flutter/foundation.dart';

/// Status state lifecycle of a multiplayer game room.
enum RoomStatus {
  waiting,
  preparing,
  inProgress,
  completed;

  static RoomStatus fromString(String? value) {
    switch (value) {
      case 'preparing':
        return RoomStatus.preparing;
      case 'in_progress':
        return RoomStatus.inProgress;
      case 'completed':
        return RoomStatus.completed;
      case 'waiting':
      default:
        return RoomStatus.waiting;
    }
  }

  String toDbString() {
    switch (this) {
      case RoomStatus.preparing:
        return 'preparing';
      case RoomStatus.inProgress:
        return 'in_progress';
      case RoomStatus.completed:
        return 'completed';
      case RoomStatus.waiting:
        return 'waiting';
    }
  }
}

/// Immutable domain model representing a multiplayer game room.
@immutable
class Room {
  final String id;
  final String code;
  final String name;
  final String hostId;
  final int maxPlayers;
  final int prepTimeSeconds;
  final int turnTimeSeconds;
  final RoomStatus status;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    required this.maxPlayers,
    required this.prepTimeSeconds,
    required this.turnTimeSeconds,
    required this.status,
    required this.createdAt,
  });

  bool get isWaiting => status == RoomStatus.waiting;
  bool get isPreparing => status == RoomStatus.preparing;
  bool get isInProgress => status == RoomStatus.inProgress;
  bool get isCompleted => status == RoomStatus.completed;

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? hostId,
    int? maxPlayers,
    int? prepTimeSeconds,
    int? turnTimeSeconds,
    RoomStatus? status,
    DateTime? createdAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      prepTimeSeconds: prepTimeSeconds ?? this.prepTimeSeconds,
      turnTimeSeconds: turnTimeSeconds ?? this.turnTimeSeconds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as String,
      code: (map['code'] as String).toUpperCase(),
      name: map['name'] as String? ?? 'Bingo Room',
      hostId: map['host_id'] as String,
      maxPlayers: (map['max_players'] as num?)?.toInt() ?? 4,
      prepTimeSeconds: (map['prep_time_seconds'] as num?)?.toInt() ?? 45,
      turnTimeSeconds: (map['turn_time_seconds'] as num?)?.toInt() ?? 20,
      status: RoomStatus.fromString(map['status'] as String?),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'host_id': hostId,
      'max_players': maxPlayers,
      'prep_time_seconds': prepTimeSeconds,
      'turn_time_seconds': turnTimeSeconds,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Immutable domain model representing a player participating in a multiplayer room.
@immutable
class RoomPlayer {
  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String avatarColorHex;
  final bool isHost;
  final bool isReady;
  final int seatIndex;
  final DateTime joinedAt;

  const RoomPlayer({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.avatarColorHex,
    required this.isHost,
    required this.isReady,
    required this.seatIndex,
    required this.joinedAt,
  });

  RoomPlayer copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? displayName,
    String? avatarColorHex,
    bool? isHost,
    bool? isReady,
    int? seatIndex,
    DateTime? joinedAt,
  }) {
    return RoomPlayer(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      seatIndex: seatIndex ?? this.seatIndex,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory RoomPlayer.fromMap(Map<String, dynamic> map) {
    // Flatten joined profile if present
    final profile = map['profiles'] as Map<String, dynamic>?;
    final name = profile != null
        ? profile['display_name'] as String?
        : map['display_name'] as String?;
    final color = profile != null
        ? profile['avatar_color_hex'] as String?
        : map['avatar_color_hex'] as String?;

    return RoomPlayer(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      displayName: name ?? 'Player',
      avatarColorHex: color ?? '#20243A',
      isHost: map['is_host'] as bool? ?? false,
      isReady: map['is_ready'] as bool? ?? false,
      seatIndex: (map['seat_index'] as num?)?.toInt() ?? 0,
      joinedAt: map['joined_at'] != null
          ? DateTime.parse(map['joined_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'display_name': displayName,
      'avatar_color_hex': avatarColorHex,
      'is_host': isHost,
      'is_ready': isReady,
      'seat_index': seatIndex,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomPlayer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
