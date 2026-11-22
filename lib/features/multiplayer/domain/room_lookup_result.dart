import 'package:flutter/foundation.dart';
import 'room.dart';

/// Authoritative room status enumeration for code search lookups.
enum RoomLookupStatus {
  waiting,
  full,
  boardPreparation,
  playing,
  roundCompleted,
  closed,
  expired,
  notFound;

  bool get isWaiting => this == RoomLookupStatus.waiting;
  bool get isFull => this == RoomLookupStatus.full;
  bool get isBoardPreparation => this == RoomLookupStatus.boardPreparation;
  bool get isPlaying => this == RoomLookupStatus.playing;
  bool get isRoundCompleted => this == RoomLookupStatus.roundCompleted;
  bool get isClosed => this == RoomLookupStatus.closed;
  bool get isExpired => this == RoomLookupStatus.expired;
  bool get isNotFound => this == RoomLookupStatus.notFound;
}

/// Structured immutable domain model for authoritative room code searches.
@immutable
class RoomLookupResult {
  final RoomLookupStatus status;
  final String? roomId;
  final String code;
  final String? name;
  final String? hostName;
  final int currentPlayers;
  final int maxPlayers;
  final bool canJoin;
  final String userMessage;

  const RoomLookupResult({
    required this.status,
    this.roomId,
    required this.code,
    this.name,
    this.hostName,
    this.currentPlayers = 0,
    this.maxPlayers = 4,
    required this.canJoin,
    required this.userMessage,
  });

  factory RoomLookupResult.notFound(String code) {
    return RoomLookupResult(
      status: RoomLookupStatus.notFound,
      code: code,
      canJoin: false,
      userMessage:
          "We couldn't find a room with that code. Please check and try again.",
    );
  }

  factory RoomLookupResult.fromRoom({
    required Room room,
    required int playerCount,
    String? hostDisplayName,
  }) {
    final host = hostDisplayName ?? 'Host Player';

    if (room.status == RoomStatus.closed) {
      return RoomLookupResult(
        status: RoomLookupStatus.closed,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage: 'This room has been closed by its host.',
      );
    }

    if (room.status == RoomStatus.expired) {
      return RoomLookupResult(
        status: RoomLookupStatus.expired,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage: 'This room is no longer available.',
      );
    }

    if (room.status == RoomStatus.preparing) {
      return RoomLookupResult(
        status: RoomLookupStatus.boardPreparation,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage:
            'This room is preparing its game board. New players cannot join right now.',
      );
    }

    if (room.status == RoomStatus.inProgress) {
      return RoomLookupResult(
        status: RoomLookupStatus.playing,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage: 'This game is already in progress.',
      );
    }

    if (room.status == RoomStatus.completed) {
      return RoomLookupResult(
        status: RoomLookupStatus.roundCompleted,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage:
            'This round has finished. Waiting for host to initiate the next round.',
      );
    }

    // WAITING status: check capacity
    if (playerCount >= room.maxPlayers) {
      return RoomLookupResult(
        status: RoomLookupStatus.full,
        roomId: room.id,
        code: room.code,
        name: room.name,
        hostName: host,
        currentPlayers: playerCount,
        maxPlayers: room.maxPlayers,
        canJoin: false,
        userMessage: 'This room is full. You cannot join right now.',
      );
    }

    return RoomLookupResult(
      status: RoomLookupStatus.waiting,
      roomId: room.id,
      code: room.code,
      name: room.name,
      hostName: host,
      currentPlayers: playerCount,
      maxPlayers: room.maxPlayers,
      canJoin: true,
      userMessage: 'Room found! Ready to join.',
    );
  }
}
