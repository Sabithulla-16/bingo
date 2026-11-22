import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/widgets/bingo_cell.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/multiplayer/gameplay/multiplayer_gameplay_screen.dart';
import 'package:bingo/features/multiplayer/presentation/multiplayer_game_notifier.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProfile p1;
  late PlayerProfile p2;
  late MockAuthRepository authHost;
  late MockProfileRepository profileHost;
  late MockAuthRepository authGuest;
  late MockProfileRepository profileGuest;
  late MultiplayerRepositoryImpl repo;

  setUp(() {
    p1 = PlayerProfile(
      id: 'user_host',
      displayName: 'Alice Host',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    p2 = PlayerProfile(
      id: 'user_guest',
      displayName: 'Bob Guest',
      email: 'bob@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    authHost = MockAuthRepository(p1);
    profileHost = MockProfileRepository(p1);
    authGuest = MockAuthRepository(p2);
    profileGuest = MockProfileRepository(p2);

    repo = MultiplayerRepositoryImpl(
      authRepository: authHost,
      profileRepository: profileHost,
    );
  });

  group('MATCH COMPLETION & POST-WIN RESTRICTIONS', () {
    test('1. Authoritative Backend Rejection: Defeated player cannot call numbers or claim lines after a win', () async {
      // 1. Setup Room and Start Game
      final room = await repo.createRoom(
        name: 'Championship Match',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);

      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final standardBoard = List.generate(25, (i) => i + 1);
      await repo.submitBoard(gameId: game.id, numbers: standardBoard);
      await repoGuest.submitBoard(gameId: game.id, numbers: standardBoard);

      // Verify game is in progress
      final activeGame = await repo.getGameForRoom(room.id);
      expect(activeGame.status, MultiplayerGameStatus.inProgress);
      expect(activeGame.winnerUserId, isNull);

      // 2. Call all numbers 1..25 to enable line claims
      for (int n = 1; n <= 25; n++) {
        // Alternating turn calls or simulating called numbers
        final g = await repo.getGameForRoom(room.id);
        if (g.currentTurnUserId == 'user_host') {
          await repo.callNumber(gameId: g.id, number: n);
        } else {
          await repoGuest.callNumber(gameId: g.id, number: n);
        }
      }

      final calledGame = await repo.getGameForRoom(room.id);
      expect(calledGame.calledNumbers.length, 25);

      // 3. Host claims 5 lines to trigger BINGO victory
      expect(await repo.claimLine(gameId: game.id, lineType: 'ROW_0', numbers: [1, 2, 3, 4, 5]), isFalse);
      expect(await repo.claimLine(gameId: game.id, lineType: 'ROW_1', numbers: [6, 7, 8, 9, 10]), isFalse);
      expect(await repo.claimLine(gameId: game.id, lineType: 'ROW_2', numbers: [11, 12, 13, 14, 15]), isFalse);
      expect(await repo.claimLine(gameId: game.id, lineType: 'ROW_3', numbers: [16, 17, 18, 19, 20]), isFalse);
      
      // 5th line -> BINGO WIN!
      final hasWon = await repo.claimLine(gameId: game.id, lineType: 'ROW_4', numbers: [21, 22, 23, 24, 25]);
      expect(hasWon, isTrue);

      // 4. Verify authoritative game completion status
      final completedGame = await repo.getGameForRoom(room.id);
      expect(completedGame.status, MultiplayerGameStatus.completed);
      expect(completedGame.winnerUserId, 'user_host');

      final completedRoom = await repo.getRoom(room.id);
      expect(completedRoom?.status, RoomStatus.completed);

      // 5. Post-completion actions on Defeated Guest MUST BE REJECTED with MATCH_ALREADY_COMPLETED
      expect(
        () => repoGuest.callNumber(gameId: game.id, number: 1),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      expect(
        () => repoGuest.claimLine(gameId: game.id, lineType: 'COL_0', numbers: [1, 6, 11, 16, 21]),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      // Turn timeout must also be rejected
      final timeoutResult = await repoGuest.handleTurnTimeout(gameId: game.id);
      expect(timeoutResult['success'], isFalse);
      expect(timeoutResult['reason'], 'MATCH_ALREADY_COMPLETED');

      // 6. Host (winner) also cannot perform further gameplay mutations
      expect(
        () => repo.callNumber(gameId: game.id, number: 2),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      expect(
        () => repo.claimLine(gameId: game.id, lineType: 'COL_1', numbers: [2, 7, 12, 17, 22]),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      // 7. Verify database remains unchanged after rejected attempts
      final finalPlayers = await repo.getGamePlayers(game.id);
      final guestState = finalPlayers.firstWhere((p) => p.userId == 'user_guest');
      expect(guestState.linesClaimed, 0);
      expect(guestState.claimedLineTypes, isEmpty);
      expect(guestState.isWinner, isFalse);
    });

    test('2. Realtime Synchronization: Defeated player state recognizes isMatchOver immediately', () async {
      final room = await repo.createRoom(
        name: 'Sync Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);
      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final standardBoard = List.generate(25, (i) => i + 1);
      await repo.submitBoard(gameId: game.id, numbers: standardBoard);
      await repoGuest.submitBoard(gameId: game.id, numbers: standardBoard);

      // Initialize Guest Notifier
      final guestNotifier = MultiplayerGameNotifier(
        roomId: room.id,
        repository: repo,
        authRepo: authGuest,
        initialBoard: BingoBoard(standardBoard),
      );

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 50));
      expect(guestNotifier.state.isMatchOver, isFalse);

      // Host claims 5 lines and wins
      await repo.claimLine(gameId: game.id, lineType: 'ROW_0', numbers: [1, 2, 3, 4, 5]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_1', numbers: [6, 7, 8, 9, 10]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_2', numbers: [11, 12, 13, 14, 15]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_3', numbers: [16, 17, 18, 19, 20]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_4', numbers: [21, 22, 23, 24, 25]);

      // Wait for guest stream to receive update
      await Future.delayed(const Duration(milliseconds: 50));

      expect(guestNotifier.state.isMatchOver, isTrue);
      expect(guestNotifier.state.game?.status, MultiplayerGameStatus.completed);
      expect(guestNotifier.state.room?.status, RoomStatus.completed);

      guestNotifier.dispose();
    });

    testWidgets('3. UI Test: Defeated player gameplay controls are disabled and auto-navigation triggers', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final room = await repo.createRoom(
        name: 'UI Test Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);
      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final standardBoard = List.generate(25, (i) => i + 1);
      await repo.submitBoard(gameId: game.id, numbers: standardBoard);
      await repoGuest.submitBoard(gameId: game.id, numbers: standardBoard);

      // Router setup to verify automatic redirection to result screen
      String currentRoute = '/gameplay';
      final router = GoRouter(
        initialLocation: '/gameplay',
        routes: [
          GoRoute(
            path: '/gameplay',
            builder: (context, state) => MultiplayerGameplayScreen(roomId: room.id),
          ),
          GoRoute(
            path: '/multiplayer/room/:roomId/result',
            builder: (context, state) {
              currentRoute = state.uri.toString();
              return const Scaffold(body: Text('MULTIPLAYER_RESULT_SCREEN'));
            },
          ),
        ],
      );

      // Mount Guest Gameplay Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiplayerRepositoryProvider.overrideWithValue(repo),
            authRepositoryProvider.overrideWithValue(authGuest),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify guest sees active match initially
      expect(find.byType(BingoCell), findsNWidgets(25));

      // Host claims 5 lines and wins
      await repo.claimLine(gameId: game.id, lineType: 'ROW_0', numbers: [1, 2, 3, 4, 5]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_1', numbers: [6, 7, 8, 9, 10]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_2', numbers: [11, 12, 13, 14, 15]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_3', numbers: [16, 17, 18, 19, 20]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_4', numbers: [21, 22, 23, 24, 25]);

      // Pump widgets to process Realtime stream updates and navigation
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Verify automatic navigation was triggered and reached Result screen
      expect(find.text('MULTIPLAYER_RESULT_SCREEN'), findsOneWidget);
      expect(currentRoute, contains('/result'));
    });

    testWidgets('4. Reconnection Guard: Joining completed room redirects immediately to result screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final room = await repo.createRoom(
        name: 'Reconnection Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);
      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final standardBoard = List.generate(25, (i) => i + 1);
      await repo.submitBoard(gameId: game.id, numbers: standardBoard);
      await repoGuest.submitBoard(gameId: game.id, numbers: standardBoard);

      // Win the match before guest opens the screen
      await repo.claimLine(gameId: game.id, lineType: 'ROW_0', numbers: [1, 2, 3, 4, 5]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_1', numbers: [6, 7, 8, 9, 10]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_2', numbers: [11, 12, 13, 14, 15]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_3', numbers: [16, 17, 18, 19, 20]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_4', numbers: [21, 22, 23, 24, 25]);

      String currentRoute = '/gameplay';
      final router = GoRouter(
        initialLocation: '/gameplay',
        routes: [
          GoRoute(
            path: '/gameplay',
            builder: (context, state) => MultiplayerGameplayScreen(roomId: room.id),
          ),
          GoRoute(
            path: '/multiplayer/room/:roomId/result',
            builder: (context, state) {
              currentRoute = state.uri.toString();
              return const Scaffold(body: Text('MULTIPLAYER_RESULT_SCREEN'));
            },
          ),
        ],
      );

      // Mount Guest Screen on already completed match
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiplayerRepositoryProvider.overrideWithValue(repo),
            authRepositoryProvider.overrideWithValue(authGuest),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Automatically transitions to result screen upon mount
      expect(find.text('MULTIPLAYER_RESULT_SCREEN'), findsOneWidget);
      expect(currentRoute, contains('/result'));
    });

    test('5. Concurrent Action Race Condition: Winning claim finalizes match; late concurrent requests fail atomically', () async {
      final room = await repo.createRoom(
        name: 'Concurrency Race Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final repoGuest = MultiplayerRepositoryImpl(
        authRepository: authGuest,
        profileRepository: profileGuest,
      );
      await repoGuest.joinRoomByCode(room.code);
      await repoGuest.toggleReady(roomId: room.id, isReady: true);
      await repo.startGame(room.id);
      final game = await repo.getGameForRoom(room.id);

      final standardBoard = List.generate(25, (i) => i + 1);
      await repo.submitBoard(gameId: game.id, numbers: standardBoard);
      await repoGuest.submitBoard(gameId: game.id, numbers: standardBoard);

      // Pre-claim 4 lines for Host
      await repo.claimLine(gameId: game.id, lineType: 'ROW_0', numbers: [1, 2, 3, 4, 5]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_1', numbers: [6, 7, 8, 9, 10]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_2', numbers: [11, 12, 13, 14, 15]);
      await repo.claimLine(gameId: game.id, lineType: 'ROW_3', numbers: [16, 17, 18, 19, 20]);

      // Host claims 5th line to win
      final winResult = await repo.claimLine(
        gameId: game.id,
        lineType: 'ROW_4',
        numbers: [21, 22, 23, 24, 25],
      );
      expect(winResult, isTrue);

      // Simultaneous in-flight action from guest must be rejected
      expect(
        () => repoGuest.callNumber(gameId: game.id, number: 12),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      expect(
        () => repoGuest.claimLine(gameId: game.id, lineType: 'COL_0', numbers: [1, 6, 11, 16, 21]),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      final postGame = await repo.getGameForRoom(room.id);
      expect(postGame.status, MultiplayerGameStatus.completed);
      expect(postGame.winnerUserId, 'user_host');
    });
  });
}
