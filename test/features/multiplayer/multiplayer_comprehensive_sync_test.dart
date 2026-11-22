import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bingo/core/services/network_connectivity_manager.dart';
import 'package:bingo/core/widgets/connection_status_banner.dart';
import 'package:bingo/features/achievements/data/achievements_repository.dart';
import 'package:bingo/features/achievements/domain/achievement.dart';
import 'package:bingo/features/earn_chips/data/rewards_repository.dart';
import 'package:bingo/features/earn_chips/domain/earn_chips_models.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/store/data/store_repository.dart';
import 'package:bingo/features/store/domain/store_item.dart';

import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 1-11 Comprehensive Multiplayer Gameplay & Sync Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final host = PlayerProfile(
      id: 'host_player_1',
      displayName: 'Host Alice',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final guest = PlayerProfile(
      id: 'challenger_player_2',
      displayName: 'Challenger Bob',
      email: 'bob@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthRepository(host);
      mockProfile = MockProfileRepository(host);
      mockProfile.setProfile(guest);

      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('1. Two-Client Match Setup: Host and Guest prepare private boards and enter match', () async {
      // Host creates room
      final room = await repository.createRoom(
        name: 'Friday Bingo Club',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );
      expect(room.status, equals(RoomStatus.waiting));

      // Guest joins
      mockAuth.currentProfile = guest;
      await repository.joinRoomByCode(room.code);

      final game = await repository.getGameForRoom(room.id);
      expect(game.status, equals(MultiplayerGameStatus.preparing));

      // Host prepares a distinct 25-number board
      mockAuth.currentProfile = host;
      final hostBoard = List<int>.generate(25, (i) => i + 1);
      await repository.submitBoard(gameId: game.id, numbers: hostBoard);

      // Verify host private board is recorded and visible to host
      final hostPrivate = await repository.getPlayerBoard(gameId: game.id, userId: host.id);
      expect(hostPrivate, equals(hostBoard));

      // Guest prepares a reversed 25-number board
      mockAuth.currentProfile = guest;
      final guestBoard = List<int>.generate(25, (i) => 25 - i);
      await repository.submitBoard(gameId: game.id, numbers: guestBoard);

      final guestPrivate = await repository.getPlayerBoard(gameId: game.id, userId: guest.id);
      expect(guestPrivate, equals(guestBoard));
      expect(hostPrivate, isNot(equals(guestPrivate))); // Strict isolation

      // Both confirmed -> Game enters inProgress
      final activeGame = await repository.getGameForRoom(room.id);
      expect(activeGame.status, equals(MultiplayerGameStatus.inProgress));
      expect(activeGame.currentTurnUserId, equals(host.id));
    });

    test('2. Turn Synchronisation & Post-Game Result Freeze: 5-line win completes match atomically', () async {
      final room = await repository.createRoom(
        name: 'Championship Match',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      mockAuth.currentProfile = guest;
      await repository.joinRoomByCode(room.code);
      final game = await repository.getGameForRoom(room.id);

      final hostBoard = List<int>.generate(25, (i) => i + 1);
      final guestBoard = List<int>.generate(25, (i) => 25 - i);

      mockAuth.currentProfile = host;
      await repository.submitBoard(gameId: game.id, numbers: hostBoard);
      mockAuth.currentProfile = guest;
      await repository.submitBoard(gameId: game.id, numbers: guestBoard);

      // Number call
      mockAuth.currentProfile = host;
      await repository.callNumber(gameId: game.id, number: 1);

      var gameAfterCall = await repository.getGameForRoom(room.id);
      expect(gameAfterCall.calledNumbers, contains(1));
      expect(gameAfterCall.currentTurnUserId, equals(guest.id));

      // Guest claims non-winning lines
      mockAuth.currentProfile = guest;
      for (int i = 0; i < 4; i++) {
        final won = await repository.claimLine(
          gameId: game.id,
          lineType: 'Row $i',
          numbers: guestBoard.sublist(i * 5, (i + 1) * 5),
        );
        expect(won, isFalse);
      }

      // 5th line claim triggers BINGO victory
      final victory = await repository.claimLine(
        gameId: game.id,
        lineType: 'Row 4',
        numbers: guestBoard.sublist(20, 25),
      );
      expect(victory, isTrue);

      final completedGame = await repository.getGameForRoom(room.id);
      expect(completedGame.status, equals(MultiplayerGameStatus.completed));
      expect(completedGame.winnerUserId, equals(guest.id));

      // Lockout verification: subsequent call or claim must be rejected
      mockAuth.currentProfile = host;
      expect(
        () => repository.callNumber(gameId: game.id, number: 2),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );

      expect(
        () => repository.claimLine(
          gameId: game.id,
          lineType: 'Row 0',
          numbers: hostBoard.sublist(0, 5),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MATCH_ALREADY_COMPLETED'),
        )),
      );
    });

    test('3. Idempotent finishRound: multiple clients concluding match do not duplicate records', () async {
      final room = await repository.createRoom(
        name: 'Idempotency Room',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      mockAuth.currentProfile = guest;
      await repository.joinRoomByCode(room.code);
      final game = await repository.getGameForRoom(room.id);

      final outcomes = [
        {'user_id': guest.id, 'display_name': 'Bob', 'is_winner': true, 'lines_claimed_count': 5},
        {'user_id': host.id, 'display_name': 'Alice', 'is_winner': false, 'lines_claimed_count': 3},
      ];

      // First client completes
      await repository.finishRound(
        gameId: game.id,
        roomId: room.id,
        winnerId: guest.id,
        winnerName: 'Bob',
        totalCalls: 18,
        playerOutcomes: outcomes,
        roundNumber: 1,
      );

      // Second client opens result screen simultaneously
      await repository.finishRound(
        gameId: game.id,
        roomId: room.id,
        winnerId: guest.id,
        winnerName: 'Bob',
        totalCalls: 18,
        playerOutcomes: outcomes,
        roundNumber: 1,
      );

      final history = await repository.getRoomMatchHistory(room.id);
      expect(history.length, equals(1)); // Exactly 1 record, no duplication!

      final leaderboard = await repository.getRoomLeaderboard(room.id);
      final bobStanding = leaderboard.firstWhere((s) => s['user_id'] == guest.id);
      expect(bobStanding['rounds_won'], equals(1));
      expect(bobStanding['rounds_played'], equals(1));
    });

    test('4. Store Ownership & Equipment States: NOT OWNED -> OWNED -> EQUIPPED cycle', () async {
      final storeRepo = StoreRepositoryImpl(
        authRepo: mockAuth,
        profileRepo: mockProfile,
      );

      // Initial catalog: default items 1, 5, 10 are equipped, others are available
      final items = await storeRepo.getItems();
      final item2 = items.firstWhere((i) => i.id == 2); // Lavender Dream (100 chips)
      expect(item2.status, equals(StoreItemStatus.available));

      // Purchase Lavender Dream
      await storeRepo.purchaseItem(2);
      final itemsAfterBuy = await storeRepo.getItems();
      final boughtItem2 = itemsAfterBuy.firstWhere((i) => i.id == 2);
      expect(boughtItem2.status, equals(StoreItemStatus.owned));

      // Equip Lavender Dream
      await storeRepo.equipItem(2);
      final itemsAfterEquip = await storeRepo.getItems();
      final equippedItem2 = itemsAfterEquip.firstWhere((i) => i.id == 2);
      expect(equippedItem2.status, equals(StoreItemStatus.equipped));

      // Previous theme (item 1) transitioned back to owned
      final oldItem1 = itemsAfterEquip.firstWhere((i) => i.id == 1);
      expect(oldItem1.status, equals(StoreItemStatus.owned));
    });

    test('5. Genuine Multiplayer Reward Tracking: Starts at 0, increments on verified play, claims once', () async {
      final rewardsRepo = RewardsRepositoryImpl(
        authRepo: mockAuth,
        profileRepo: mockProfile,
      );

      // Initial tasks for fresh player: zero mock counts!
      final tasks = await rewardsRepo.getTasks();
      final roomChamp = tasks.firstWhere((t) => t.id == 'room_champion');
      expect(roomChamp.current, equals(0));
      expect(roomChamp.status, equals(RewardTaskStatus.inProgress));

      // Record verified wins
      await rewardsRepo.recordMatchCompleted(isWinner: true, isMultiplayer: true);
      await rewardsRepo.recordMatchCompleted(isWinner: true, isMultiplayer: true);
      await rewardsRepo.recordMatchCompleted(isWinner: true, isMultiplayer: true);

      final tasksAfterWins = await rewardsRepo.getTasks();
      final readyChamp = tasksAfterWins.firstWhere((t) => t.id == 'room_champion');
      expect(readyChamp.current, equals(3));
      expect(readyChamp.status, equals(RewardTaskStatus.readyToClaim));

      // Claim reward: Credits chips
      final initialChips = (await mockProfile.getProfile(host.id))!.chips;
      final rewardAmount = await rewardsRepo.claimTask('room_champion');
      expect(rewardAmount, equals(100));

      final profileAfterClaim = await mockProfile.getProfile(host.id);
      expect(profileAfterClaim!.chips, equals(initialChips + 100));

      // Duplicate claim must throw
      expect(
        () => rewardsRepo.claimTask('room_champion'),
        throwsA(isA<StateError>()),
      );
    });

    test('6. Event-Driven Achievement Tracking: Unlocks based on career stats', () async {
      final achRepo = AchievementsRepositoryImpl(
        authRepo: mockAuth,
        profileRepo: mockProfile,
      );

      final initialAchs = await achRepo.getAchievements();
      final streakAch = initialAchs.firstWhere((a) => a.id == 'card-winning-streak');
      expect(streakAch.status, equals(AchievementStatus.locked));
      expect(streakAch.current, equals(0));

      // Update from genuine 3-game win streak stats
      final stats = const PlayerCareerStats(
        totalMatches: 3,
        wins: 3,
        currentStreak: 3,
        bestStreak: 3,
      );
      await achRepo.evaluateFromStats(stats, isMultiplayer: true, isVictory: true);

      final updatedAchs = await achRepo.getAchievements();
      final readyStreak = updatedAchs.firstWhere((a) => a.id == 'card-winning-streak');
      expect(readyStreak.status, equals(AchievementStatus.ready));
      expect(readyStreak.current, equals(3));

      // Claim achievement
      final reward = await achRepo.claimAchievement('card-winning-streak');
      expect(reward, equals(200));

      final claimedAchs = await achRepo.getAchievements();
      final claimedStreak = claimedAchs.firstWhere((a) => a.id == 'card-winning-streak');
      expect(claimedStreak.status, equals(AchievementStatus.claimed));
    });

    testWidgets('7. Background Network Monitoring: Banners are muted for checking & online', (tester) async {
      final notifier = NetworkConnectivityNotifier();
      notifier.setStatus(NetworkStatus.checking);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkStatusProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ConnectionStatusBanner()),
          ),
        ),
      );

      // While checking, no visible banner is displayed
      expect(find.text('Checking Connection...'), findsNothing);
      expect(find.byType(ConnectionStatusBanner), findsOneWidget);

      // But when offline, alert banner is displayed
      notifier.setStatus(NetworkStatus.offline);
      await tester.pump();
      expect(find.text("You're Offline"), findsOneWidget);
    });
  });
}
