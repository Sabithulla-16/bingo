import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository hostAuth;
  late MockProfileRepository hostProfileRepo;
  late MultiplayerRepositoryImpl hostRepo;

  late MockAuthRepository guestAuth;
  late MockProfileRepository guestProfileRepo;
  late MultiplayerRepositoryImpl guestRepo;

  final aliceProfile = PlayerProfile(
    id: 'user_alice',
    displayName: 'Alice',
    email: 'alice@bingo.dev',
    avatarColorHex: '#FF6B5E',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final bobProfile = PlayerProfile(
    id: 'user_bob',
    displayName: 'Bob',
    email: 'bob@bingo.dev',
    avatarColorHex: '#20243A',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    MultiplayerRepositoryImpl.resetStaticStoresForTesting();

    hostAuth = MockAuthRepository(aliceProfile);
    hostProfileRepo = MockProfileRepository(aliceProfile);
    hostRepo = MultiplayerRepositoryImpl(
      authRepository: hostAuth,
      profileRepository: hostProfileRepo,
    );

    guestAuth = MockAuthRepository(bobProfile);
    guestProfileRepo = MockProfileRepository(bobProfile);
    guestRepo = MultiplayerRepositoryImpl(
      authRepository: guestAuth,
      profileRepository: guestProfileRepo,
    );
  });

  group('Board Preparation & Atomic Game Start Pipeline Tests', () {
    test('1. Board Validation: Rejects invalid length or duplicate numbers', () async {
      final room = await hostRepo.createRoom(
        name: 'Prep Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      final game = await hostRepo.getGameForRoom(room.id);

      // Invalid length (less than 25)
      expect(
        () => hostRepo.submitBoard(
          gameId: game.id,
          numbers: [1, 2, 3, 4, 5],
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Invalid: 25 numbers but has duplicate number 1
      final duplicateList = List.generate(25, (i) => i == 24 ? 1 : i + 1);
      expect(
        () => hostRepo.submitBoard(
          gameId: game.id,
          numbers: duplicateList,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Valid: exactly numbers 1..25
      final validList = BingoBoard.quickShuffle().toList();
      expect(validList.length, 25);
      expect(validList.toSet().length, 25);
      await expectLater(
        hostRepo.submitBoard(gameId: game.id, numbers: validList),
        completes,
      );
    });

    test('2. Condition A: All players ready early triggers immediate match start', () async {
      // 1. Create Room and join
      final room = await hostRepo.createRoom(
        name: 'Early Ready Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await guestRepo.joinRoomByCode(room.code);
      await hostRepo.toggleReady(roomId: room.id, isReady: true);
      await guestRepo.toggleReady(roomId: room.id, isReady: true);

      // Host starts game from lobby -> transitions to preparing
      await hostRepo.startGame(room.id);

      final game = await hostRepo.getGameForRoom(room.id);
      expect(game.status, MultiplayerGameStatus.preparing);

      final refreshedRoom = await hostRepo.getRoom(room.id);
      expect(refreshedRoom?.status, RoomStatus.preparing);

      // 2. Alice confirms valid board
      final aliceBoard = BingoBoard.quickShuffle().toList();
      await hostRepo.submitBoard(gameId: game.id, numbers: aliceBoard);

      // Check game still preparing because Bob hasn't confirmed
      final gameAfterAlice = await hostRepo.getGameForRoom(room.id);
      expect(gameAfterAlice.status, MultiplayerGameStatus.preparing);

      // 3. Bob confirms valid board
      final bobBoard = BingoBoard.quickShuffle().toList();
      await guestRepo.submitBoard(gameId: game.id, numbers: bobBoard);

      // 4. Condition A fulfilled: match automatically and atomically starts!
      final activeGame = await hostRepo.getGameForRoom(room.id);
      expect(activeGame.status, MultiplayerGameStatus.inProgress);
      expect(activeGame.currentTurnUserId, isNotNull);
      expect(['user_alice', 'user_bob'], contains(activeGame.currentTurnUserId));

      final activeRoom = await hostRepo.getRoom(room.id);
      expect(activeRoom?.status, RoomStatus.inProgress);
    });

    test('3. Condition B: Timer expiration with Auto-Fill starts match for unready players', () async {
      final room = await hostRepo.createRoom(
        name: 'Auto-Fill Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await guestRepo.joinRoomByCode(room.code);
      await hostRepo.toggleReady(roomId: room.id, isReady: true);
      await guestRepo.toggleReady(roomId: room.id, isReady: true);

      await hostRepo.startGame(room.id);
      final game = await hostRepo.getGameForRoom(room.id);

      // Alice confirms, Bob does NOT confirm
      final aliceBoard = BingoBoard.quickShuffle().toList();
      await hostRepo.submitBoard(gameId: game.id, numbers: aliceBoard);

      expect((await hostRepo.getGameForRoom(room.id)).status, MultiplayerGameStatus.preparing);

      // Timer expires -> handlePrepTimeout(autoFill: true)
      await hostRepo.handlePrepTimeout(gameId: game.id, autoFill: true);

      // Game is started with auto-filled valid board for Bob
      final activeGame = await hostRepo.getGameForRoom(room.id);
      expect(activeGame.status, MultiplayerGameStatus.inProgress);

      final activeRoom = await hostRepo.getRoom(room.id);
      expect(activeRoom?.status, RoomStatus.inProgress);
    });

    test('4. Idempotency: Multiple concurrent confirmations execute cleanly without duplicate starts', () async {
      final room = await hostRepo.createRoom(
        name: 'Concurrent Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await guestRepo.joinRoomByCode(room.code);
      await hostRepo.toggleReady(roomId: room.id, isReady: true);
      await guestRepo.toggleReady(roomId: room.id, isReady: true);

      await hostRepo.startGame(room.id);
      final game = await hostRepo.getGameForRoom(room.id);

      // Alice and Bob submit simultaneously alongside timeout trigger
      final aliceBoard = BingoBoard.quickShuffle().toList();
      final bobBoard = BingoBoard.quickShuffle().toList();

      await Future.wait([
        hostRepo.submitBoard(gameId: game.id, numbers: aliceBoard),
        guestRepo.submitBoard(gameId: game.id, numbers: bobBoard),
        hostRepo.handlePrepTimeout(gameId: game.id, autoFill: true),
      ]);

      final activeGame = await hostRepo.getGameForRoom(room.id);
      expect(activeGame.status, MultiplayerGameStatus.inProgress);

      final activeRoom = await hostRepo.getRoom(room.id);
      expect(activeRoom?.status, RoomStatus.inProgress);
    });
  });
}
