import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/multiplayer/presentation/multiplayer_lobby_notifier.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/profile/presentation/profile_screen.dart';
import 'package:bingo/features/room_statistics/domain/room_statistics.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Critical Bug Fixes & Realtime Synchronization Tests', () {
    late PlayerProfile hostUser;
    late PlayerProfile guestUser1;
    late PlayerProfile guestUser2;
    late MockAuthRepository authRepoHost;
    late MockAuthRepository authRepoGuest1;
    late MockProfileRepository profileRepo;
    late MultiplayerRepositoryImpl repository;

    setUp(() {
      MultiplayerRepositoryImpl.resetStaticStoresForTesting();
      hostUser = PlayerProfile(
        id: 'host-1',
        displayName: 'Host Alice',
        email: 'alice@bingo.test',
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      guestUser1 = PlayerProfile(
        id: 'guest-1',
        displayName: 'Guest Bob',
        email: 'bob@bingo.test',
        avatarId: 'avatar_ocean',
        avatarColorHex: '#4A90E2',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      guestUser2 = PlayerProfile(
        id: 'guest-2',
        displayName: 'Guest Charlie',
        email: 'charlie@bingo.test',
        avatarId: 'avatar_mint',
        avatarColorHex: '#2ECC71',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      authRepoHost = MockAuthRepository(hostUser);
      authRepoGuest1 = MockAuthRepository(guestUser1);
      profileRepo = MockProfileRepository(hostUser)
        ..setProfile(guestUser1)
        ..setProfile(guestUser2);

      repository = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authRepoHost,
        profileRepository: profileRepo,
      );
    });

    test('1. RoomRoundRecord.fromJson parses both canonical and RPC dual column formats', () {
      final rpcJson = {
        'id': 'rec-1',
        'room_id': 'room-1',
        'round_number': 1,
        'winner_user_id': 'host-1',
        'winner_display_name': 'Host Alice',
        'outcomes': [
          {
            'user_id': 'host-1',
            'display_name': 'Host Alice',
            'is_winner': true,
            'lines_claimed': 5,
          },
          {
            'user_id': 'guest-1',
            'display_name': 'Guest Bob',
            'is_winner': false,
            'lines_claimed': 2,
          },
        ],
        'completed_at': '2026-11-01T12:00:00Z',
        'total_calls': 24,
      };

      final record = RoomRoundRecord.fromJson(rpcJson);
      expect(record.winnerId, equals('host-1'));
      expect(record.winnerName, equals('Host Alice'));
      expect(record.playerOutcomes.length, equals(2));
      expect(record.playerOutcomes[0].userId, equals('host-1'));
      expect(record.playerOutcomes[0].linesClaimedCount, equals(5));
      expect(record.playerOutcomes[1].linesClaimedCount, equals(2));
      expect(record.finishedAt.isUtc, isTrue);

      // Verify it never defaults winner to "Unknown" when winner_display_name is present
      expect(record.winnerName, isNot(equals('Unknown')));
    });

    test('2. Turn rotation strictly excludes forfeited players in 3-player match', () async {
      final room = await repository.createRoom(
        name: 'Trio Arena',
        maxPlayers: 3,
        prepTimeSeconds: 15,
        turnTimeSeconds: 15,
      );

      // Add guests
      final guest1Repo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: MockAuthRepository(guestUser1),
        profileRepository: profileRepo,
      );
      await guest1Repo.joinRoomByCode(room.code);

      final guest2Repo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: MockAuthRepository(guestUser2),
        profileRepository: profileRepo,
      );
      await guest2Repo.joinRoomByCode(room.code);

      // Guests toggle ready
      await guest1Repo.toggleReady(roomId: room.id, isReady: true);
      await guest2Repo.toggleReady(roomId: room.id, isReady: true);

      // Submit boards and mark ready
      final dummyBoard = List.generate(25, (i) => i + 1);
      await repository.startGame(room.id);
      final game = await repository.getGameForRoom(room.id);

      await repository.submitBoard(gameId: game.id, numbers: dummyBoard);
      await guest1Repo.submitBoard(gameId: game.id, numbers: dummyBoard);
      await guest2Repo.submitBoard(gameId: game.id, numbers: dummyBoard);

      final activeGame = await repository.getGameForRoom(room.id);
      final activePlayers = await repository.getGamePlayers(activeGame.id);
      expect(activePlayers.length, equals(3));

      // Guest 1 forfeits
      await guest1Repo.forfeitMatch(gameId: activeGame.id, roomId: room.id);

      final playersAfterForfeit = await repository.getGamePlayers(activeGame.id);
      final p1 = playersAfterForfeit.firstWhere((p) => p.userId == 'guest-1');
      expect(p1.isForfeited, isTrue);

      // Current player calls number: rotation advances strictly among active players (!p.isForfeited)
      final currentUserId = activeGame.currentTurnUserId;
      expect(currentUserId, isNotNull);

      if (currentUserId == 'host-1') {
        await repository.callNumber(gameId: activeGame.id, number: 7);
        final g = await repository.getGameForRoom(room.id);
        // Next must be guest-2 (skipping guest-1)
        expect(g.currentTurnUserId, equals('guest-2'));

        await guest2Repo.callNumber(gameId: activeGame.id, number: 12);
        final g2 = await repository.getGameForRoom(room.id);
        // Next must cycle back to host-1 (skipping guest-1)
        expect(g2.currentTurnUserId, equals('host-1'));
      }
    });

    test('3. Waiting room kickPlayer removes participant and updates membership atomically', () async {
      final room = await repository.createRoom(
        name: 'Waiting Lounge',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      final guestRepo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: MockAuthRepository(guestUser1),
        profileRepository: profileRepo,
      );
      await guestRepo.joinRoomByCode(room.code);

      var players = await repository.getRoomPlayers(room.id);
      expect(players.length, equals(2));

      // Host kicks guest-1
      await repository.kickPlayer(roomId: room.id, userId: 'guest-1');

      players = await repository.getRoomPlayers(room.id);
      expect(players.length, equals(1));
      expect(players.any((p) => p.userId == 'guest-1'), isFalse);
    });

    test('4. Waiting room closeRoom by host sets status closed and cleans up participants', () async {
      final room = await repository.createRoom(
        name: 'Closure Room',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      final guestRepo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: MockAuthRepository(guestUser1),
        profileRepository: profileRepo,
      );
      await guestRepo.joinRoomByCode(room.code);

      // Host closes the room
      await repository.closeRoom(room.id);

      final closedRoom = await repository.getRoom(room.id);
      expect(closedRoom!.status, equals(RoomStatus.closed));

      final remainingPlayers = await repository.getRoomPlayers(room.id);
      expect(remainingPlayers.isEmpty, isTrue);
    });

    test('5. MultiplayerLobbyNotifier detects removal and sets wasRemovedByHost flag', () async {
      final room = await repository.createRoom(
        name: 'Kick Detection',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      final guestRepo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authRepoGuest1,
        profileRepository: profileRepo,
      );
      await guestRepo.joinRoomByCode(room.code);

      final notifier = MultiplayerLobbyNotifier(
        roomId: room.id,
        repository: guestRepo,
        authRepo: authRepoGuest1,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.wasRemovedByHost, isFalse);

      // Host removes guest-1
      await repository.kickPlayer(roomId: room.id, userId: 'guest-1');

      // Allow realtime stream event propagation
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.wasRemovedByHost, isTrue);
      notifier.dispose();
    });

    test('6. MultiplayerLobbyNotifier detects room closure and sets wasClosedByHost flag', () async {
      final room = await repository.createRoom(
        name: 'Close Detection',
        maxPlayers: 4,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      final guestRepo = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authRepoGuest1,
        profileRepository: profileRepo,
      );
      await guestRepo.joinRoomByCode(room.code);

      final notifier = MultiplayerLobbyNotifier(
        roomId: room.id,
        repository: guestRepo,
        authRepo: authRepoGuest1,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.wasClosedByHost, isFalse);

      // Host closes room
      await repository.closeRoom(room.id);

      // Allow realtime stream event propagation
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.wasClosedByHost, isTrue);
      notifier.dispose();
    });

    testWidgets('7. ProfileScreen renders without Recent Matches section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(profileRepo),
            currentProfileProvider.overrideWith((ref) => hostUser),
            careerStatsProvider('host-1').overrideWith(
              (ref) => Stream.value(const PlayerCareerStats(
                totalMatches: 5,
                wins: 3,
                losses: 2,
              )),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Recent Matches UI header must NOT exist
      expect(find.text('RECENT MATCHES'), findsNothing);
      expect(find.text('Recent Matches'), findsNothing);

      // Performance & Lifetime Stats must exist
      expect(find.text('YOUR PERFORMANCE'), findsOneWidget);
      expect(find.text('TOTAL MATCHES'), findsOneWidget);
    });
  });
}
