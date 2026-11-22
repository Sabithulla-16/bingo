import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/multiplayer/domain/room_lookup_result.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Room Lifecycle & Database Status Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final hostUser = PlayerProfile(
      id: 'reg_host_1',
      displayName: 'Captain Host',
      email: 'host@bingo.app',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final player2 = PlayerProfile(
      id: 'reg_p2',
      displayName: 'Player Two',
      email: 'p2@bingo.app',
      avatarColorHex: '#20243A',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(hostUser);
      mockProfile = MockProfileRepository(hostUser);
      mockProfile.setProfile(player2);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test(
      'host leaving waiting room updates status to closed with closedAt',
      () async {
        final room = await repository.createRoom(
          name: 'Private Room',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        expect(room.status, equals(RoomStatus.waiting));
        expect(room.isClosed, isFalse);

        // Host leaves the waiting room
        await repository.leaveRoom(room.id);

        final updatedRoom = await repository.getRoom(room.id);
        expect(updatedRoom, isNotNull);
        expect(updatedRoom!.status, equals(RoomStatus.closed));
        expect(updatedRoom.isClosed, isTrue);
        expect(updatedRoom.closedAt, isNotNull);

        // Lookup by code reflects closed status
        final lookup = await repository.lookupRoomByCode(room.code);
        expect(lookup.status, equals(RoomLookupStatus.closed));
        expect(lookup.canJoin, isFalse);
        expect(lookup.userMessage, contains('closed'));
      },
    );

    test(
      'closeRoom explicitly marks room as closed and sets timestamp',
      () async {
        final room = await repository.createRoom(
          name: 'Tournament Room',
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        await repository.closeRoom(room.id);

        final closedRoom = await repository.getRoom(room.id);
        expect(closedRoom, isNotNull);
        expect(closedRoom!.status, equals(RoomStatus.closed));
        expect(closedRoom.closedAt, isNotNull);

        final lookup = await repository.lookupRoomByCode(room.code);
        expect(lookup.status, equals(RoomLookupStatus.closed));
        expect(lookup.canJoin, isFalse);
      },
    );

    test(
      'host leaving active match transfers host role to next seated player',
      () async {
        final room = await repository.createRoom(
          name: 'Active Duel',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        // Player 2 joins and readies
        mockAuth.currentProfile = player2;
        await repository.joinRoomByCode(room.code);
        await repository.toggleReady(roomId: room.id, isReady: true);

        // Host starts the game
        mockAuth.currentProfile = hostUser;
        await repository.startGame(room.id);

        // Host leaves active room
        await repository.leaveRoom(room.id);

        // Room remains open with Player 2 promoted to host
        final updatedRoom = await repository.getRoom(room.id);
        expect(updatedRoom, isNotNull);
        expect(updatedRoom!.status, isNot(equals(RoomStatus.closed)));
        expect(updatedRoom.hostId, equals(player2.id));

        final players = await repository.getRoomPlayers(room.id);
        expect(players.any((p) => p.userId == hostUser.id), isFalse);
        final remainingHost = players.firstWhere((p) => p.userId == player2.id);
        expect(remainingHost.isHost, isTrue);
      },
    );
  });
}
