import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/room_lookup_result.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Structured Room Search & Status Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final hostUser = PlayerProfile(
      id: 'search_host',
      displayName: 'Captain Search',
      email: 'search@bingo.app',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(hostUser);
      mockProfile = MockProfileRepository(hostUser);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('lookup returns notFound for non-existent room code', () async {
      final result = await repository.lookupRoomByCode('NON999');

      expect(result.status, equals(RoomLookupStatus.notFound));
      expect(result.canJoin, isFalse);
      expect(result.userMessage, contains("We couldn't find a room"));
    });

    test('lookup returns waiting when room has slots and is open', () async {
      final room = await repository.createRoom(
        name: 'Open Game',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final result = await repository.lookupRoomByCode(room.code);

      expect(result.status, equals(RoomLookupStatus.waiting));
      expect(result.canJoin, isTrue);
      expect(result.name, equals('Open Game'));
      expect(result.currentPlayers, equals(1));
      expect(result.maxPlayers, equals(4));
      expect(result.hostName, equals('Captain Search'));
      expect(result.userMessage, contains('Ready to join'));
    });

    test('lookup returns full when all player seats are occupied', () async {
      final room = await repository.createRoom(
        name: 'Duel Arena',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      // Player 2 joins
      final p2 = PlayerProfile(
        id: 'challenger_p2',
        displayName: 'Challenger',
        email: 'p2@bingo.app',
        avatarColorHex: '#20243A',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockAuth.currentProfile = p2;
      mockProfile.setProfile(p2);
      await repository.joinRoomByCode(room.code);

      final result = await repository.lookupRoomByCode(room.code);

      expect(result.status, equals(RoomLookupStatus.full));
      expect(result.canJoin, isFalse);
      expect(result.currentPlayers, equals(2));
      expect(result.userMessage, contains('full'));
    });

    test('lookup returns closed when host exits or room is closed', () async {
      final room = await repository.createRoom(
        name: 'Quick Match',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await repository.closeRoom(room.id);

      final result = await repository.lookupRoomByCode(room.code);

      expect(result.status, equals(RoomLookupStatus.closed));
      expect(result.canJoin, isFalse);
      expect(result.userMessage, contains('closed'));
    });
  });
}
