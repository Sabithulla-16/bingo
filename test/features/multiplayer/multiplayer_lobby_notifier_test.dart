import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/presentation/multiplayer_lobby_notifier.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('MultiplayerLobbyNotifier Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;
    final hostProfile = PlayerProfile(
      id: 'host_id',
      displayName: 'Captain Host',
      email: 'host@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(hostProfile);
      mockProfile = MockProfileRepository(hostProfile);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('init loads room and players, identifies host correctly', () async {
      final room = await repository.createRoom(
        name: 'Fun Room',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final notifier = MultiplayerLobbyNotifier(
        roomId: room.id,
        repository: repository,
        authRepo: mockAuth,
      );
      addTearDown(notifier.dispose);

      // Wait for initial async load
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.room, isNotNull);
      expect(notifier.state.room!.name, equals('Fun Room'));
      expect(notifier.state.players.length, equals(1));
      expect(notifier.state.isHost, isTrue);
      expect(notifier.state.canStartGame, isFalse); // Only 1 player in room
    });

    test(
      'canStartGame becomes true when second player joins and readies up',
      () async {
        final room = await repository.createRoom(
          name: 'Fun Room',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        // Player 2 joins
        final p2 = PlayerProfile(
          id: 'p2_id',
          displayName: 'Player Two',
          email: 'p2@bingo.dev',
          avatarColorHex: '#20243A',
          chips: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockAuth.currentProfile = p2;
        mockProfile.setProfile(p2);
        await repository.joinRoomByCode(room.code);

        // Switch back to host notifier
        mockAuth.currentProfile = hostProfile;
        mockProfile.setProfile(hostProfile);
        final notifier = MultiplayerLobbyNotifier(
          roomId: room.id,
          repository: repository,
          authRepo: mockAuth,
        );
        addTearDown(notifier.dispose);

        // Player 2 readies up
        mockAuth.currentProfile = p2;
        mockProfile.setProfile(p2);
        await repository.toggleReady(roomId: room.id, isReady: true);

        // Host readies up
        mockAuth.currentProfile = hostProfile;
        mockProfile.setProfile(hostProfile);
        await repository.toggleReady(roomId: room.id, isReady: true);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(notifier.state.players.length, equals(2));
        expect(notifier.state.allPlayersReady, isTrue);
        expect(notifier.state.canStartGame, isTrue);
      },
    );
  });
}
