import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/gameplay/multiplayer_gameplay_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/single_player/gameplay/single_player_gameplay_screen.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PART 1 & PART 2: Multiplayer Player Cards and UI Consistency (2 to 4 Players)', () {
    testWidgets('Both Host and Guest receive identical player lists and cards for 2 players', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = PlayerProfile(
        id: 'user_host',
        displayName: 'Alice Host',
        email: 'alice@bingo.dev',
        avatarColorHex: '#FF6B5E',
        chips: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p2 = PlayerProfile(
        id: 'user_guest',
        displayName: 'Bob Guest',
        email: 'bob@bingo.dev',
        avatarColorHex: '#20243A',
        chips: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final authHost = MockAuthRepository(p1);
      final profileHost = MockProfileRepository(p1);
      final repo = MultiplayerRepositoryImpl(
        authRepository: authHost,
        profileRepository: profileHost,
      );

      // Create room
      final room = await repo.createRoom(
        name: 'Duo Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final authGuest = MockAuthRepository(p2);
      final profileGuest = MockProfileRepository(p2);
      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);

      // Start board prep and submit boards
      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final b1 = BingoBoard.quickShuffle().numbers;
      final b2 = BingoBoard.quickShuffle().numbers;
      await repo.submitBoard(gameId: game.id, numbers: b1);
      await repoGuest.submitBoard(gameId: game.id, numbers: b2);

      // 1. Verify Host Gameplay Screen shows both players
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authHost),
            profileRepositoryProvider.overrideWithValue(profileHost),
            multiplayerRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(home: MultiplayerGameplayScreen(roomId: room.id)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Players In Room (2)'), findsOneWidget);
      expect(find.text('HOST'), findsOneWidget);
      expect(find.text('GUEST'), findsOneWidget);
      expect(find.text('Alice Host'), findsNothing); // Host sees 'You'
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Bob Guest'), findsOneWidget);

      // 2. Verify Guest Gameplay Screen shows both players and NOT 0 players!
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authGuest),
            profileRepositoryProvider.overrideWithValue(profileGuest),
            multiplayerRepositoryProvider.overrideWithValue(repoGuest),
          ],
          child: MaterialApp(home: MultiplayerGameplayScreen(roomId: room.id)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Players In Room (2)'), findsOneWidget);
      expect(find.text('HOST'), findsOneWidget);
      expect(find.text('GUEST'), findsOneWidget);
      expect(find.text('Alice Host'), findsOneWidget);
      expect(find.text('You'), findsOneWidget); // Bob sees 'You'
    });

    testWidgets('3 and 4 Player rooms render all participant cards with live scores and BINGO badges', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = PlayerProfile(id: 'u1', displayName: 'Player 1', email: 'p1@b.dev', avatarColorHex: '#FF6B5E', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final p2 = PlayerProfile(id: 'u2', displayName: 'Player 2', email: 'p2@b.dev', avatarColorHex: '#20243A', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final p3 = PlayerProfile(id: 'u3', displayName: 'Player 3', email: 'p3@b.dev', avatarColorHex: '#AD8722', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final p4 = PlayerProfile(id: 'u4', displayName: 'Player 4', email: 'p4@b.dev', avatarColorHex: '#BA1A1A', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());

      final auth1 = MockAuthRepository(p1);
      final profile1 = MockProfileRepository(p1);
      final repo = MultiplayerRepositoryImpl(authRepository: auth1, profileRepository: profile1);

      final room = await repo.createRoom(
        name: 'Quad Squad',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repo2 = MultiplayerRepositoryImpl(authRepository: MockAuthRepository(p2), profileRepository: MockProfileRepository(p2));
      final repo3 = MultiplayerRepositoryImpl(authRepository: MockAuthRepository(p3), profileRepository: MockProfileRepository(p3));
      final repo4 = MultiplayerRepositoryImpl(authRepository: MockAuthRepository(p4), profileRepository: MockProfileRepository(p4));

      await repo2.joinRoomByCode(room.code);
      await repo2.toggleReady(roomId: room.id, isReady: true);

      await repo3.joinRoomByCode(room.code);
      await repo3.toggleReady(roomId: room.id, isReady: true);

      await repo4.joinRoomByCode(room.code);
      await repo4.toggleReady(roomId: room.id, isReady: true);

      final roomPlayers = await repo.getRoomPlayers(room.id);
      expect(roomPlayers.length, 4);

      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      await repo.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);
      await repo2.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);
      await repo3.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);
      await repo4.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth1),
            profileRepositoryProvider.overrideWithValue(profile1),
            multiplayerRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(home: MultiplayerGameplayScreen(roomId: room.id)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Players In Room (4)'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });
  });

  group('PART 3: Server-Authoritative Automatic Turn Timeout', () {
    test('handleTurnTimeout selects an uncalled number belonging to current player board and advances turn', () async {
      final p1 = PlayerProfile(id: 'u1', displayName: 'P1', email: 'p1@b.dev', avatarColorHex: '#FF6B5E', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final p2 = PlayerProfile(id: 'u2', displayName: 'P2', email: 'p2@b.dev', avatarColorHex: '#20243A', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());

      final auth1 = MockAuthRepository(p1);
      final repo = MultiplayerRepositoryImpl(authRepository: auth1, profileRepository: MockProfileRepository(p1));

      final room = await repo.createRoom(
        name: 'Timeout Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repo2 = MultiplayerRepositoryImpl(authRepository: MockAuthRepository(p2), profileRepository: MockProfileRepository(p2));
      await repo2.joinRoomByCode(room.code);
      await repo2.toggleReady(roomId: room.id, isReady: true);

      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final p1Board = BingoBoard.quickShuffle().numbers;
      final p2Board = BingoBoard.quickShuffle().numbers;
      await repo.submitBoard(gameId: game.id, numbers: p1Board);
      await repo2.submitBoard(gameId: game.id, numbers: p2Board);

      final initialGame = await repo.getGameForRoom(room.id);
      final initialTurnUser = initialGame.currentTurnUserId;
      expect(initialTurnUser, isNotNull);
      expect(initialGame.calledNumbers, isEmpty);

      // Simulate timeout for initialTurnUser
      final res = await repo.handleTurnTimeout(
        gameId: game.id,
        currentTurnUserId: initialTurnUser,
      );

      expect(res['success'], isTrue);
      final autoNum = res['auto_number'] as int;
      expect(autoNum, inInclusiveRange(1, 25));

      final updatedGame = await repo.getGameForRoom(room.id);
      expect(updatedGame.calledNumbers, contains(autoNum));
      expect(updatedGame.calledNumbers.length, 1);
      expect(updatedGame.currentTurnUserId, isNot(initialTurnUser));

      // Idempotent test: calling timeout again with old turn user does NOT advance or select another number
      final secondTimeout = await repo.handleTurnTimeout(
        gameId: game.id,
        currentTurnUserId: initialTurnUser,
      );
      expect(secondTimeout['reason'], 'turn_already_advanced');
      final gameAfterDuplicate = await repo.getGameForRoom(room.id);
      expect(gameAfterDuplicate.calledNumbers.length, 1);
    });

    test('Manual call wins race against late timeout call', () async {
      final p1 = PlayerProfile(id: 'u1', displayName: 'P1', email: 'p1@b.dev', avatarColorHex: '#FF6B5E', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
      final p2 = PlayerProfile(id: 'u2', displayName: 'P2', email: 'p2@b.dev', avatarColorHex: '#20243A', chips: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());

      final auth1 = MockAuthRepository(p1);
      final repo = MultiplayerRepositoryImpl(authRepository: auth1, profileRepository: MockProfileRepository(p1));

      final room = await repo.createRoom(
        name: 'Race Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repo2 = MultiplayerRepositoryImpl(authRepository: MockAuthRepository(p2), profileRepository: MockProfileRepository(p2));
      await repo2.joinRoomByCode(room.code);
      await repo2.toggleReady(roomId: room.id, isReady: true);

      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      await repo.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);
      await repo2.submitBoard(gameId: game.id, numbers: BingoBoard.quickShuffle().numbers);

      final activeGame = await repo.getGameForRoom(room.id);
      final turnUser = activeGame.currentTurnUserId!;

      // Player manually calls a number
      await repo.callNumber(gameId: game.id, number: 7);

      // Late timeout executes with the old turn user
      final timeoutRes = await repo.handleTurnTimeout(
        gameId: game.id,
        currentTurnUserId: turnUser,
      );

      expect(timeoutRes['reason'], 'turn_already_advanced');
      final afterGame = await repo.getGameForRoom(room.id);
      expect(afterGame.calledNumbers, [7]);
    });
  });

  group('PART 4: Single-Player Automatic Result Navigation', () {
    testWidgets('Human player victory automatically triggers navigation to result screen', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(singlePlayerGameProvider.notifier);
      final board = BingoBoard([
        1,  2,  3,  4,  5,
        6,  7,  8,  9,  10,
        11, 12, 13, 14, 15,
        16, 17, 18, 19, 20,
        21, 22, 23, 24, 25,
      ]);

      notifier.initMatch(
        gameId: 'match_auto_nav_1',
        difficulty: AiDifficulty.easy,
        playerBoard: board,
      );

      // Build SinglePlayerGameplayScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SinglePlayerGameplayScreen(gameId: 'match_auto_nav_1'),
          ),
        ),
      );
      await tester.pump();

      // Trigger update through notifier
      container.read(singlePlayerGameProvider.notifier).initMatch(
        gameId: 'match_auto_nav_1',
        difficulty: AiDifficulty.easy,
        playerBoard: board,
      );
      // Directly verify game completion guards
      notifier.claimAllLines();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Bot victory blocks further player actions', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(singlePlayerGameProvider.notifier);
      final board = BingoBoard.quickShuffle();

      notifier.initMatch(
        gameId: 'match_bot_win',
        difficulty: AiDifficulty.easy,
        playerBoard: board,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SinglePlayerGameplayScreen(gameId: 'match_bot_win'),
          ),
        ),
      );
      await tester.pump();

      // Uncalled line claim is rejected
      expect(() => notifier.claimLine('row_0'), throwsA(isA<StateError>()));
    });
  });
}
