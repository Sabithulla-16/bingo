import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/multiplayer_game.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Milestone 7: Room Leaderboard, Tie-Breakers, & Match History Tests', () {
    late MockAuthRepository authRepo;
    late MockProfileRepository profileRepo;
    late MultiplayerRepositoryImpl repository;

    setUp(() {
      final valtry = PlayerProfile(
        id: 'user-valtry',
        displayName: 'Valtry',
        email: 'valtry@bingo.test',
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      authRepo = MockAuthRepository(valtry);
      profileRepo = MockProfileRepository(valtry);

      repository = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authRepo,
        profileRepository: profileRepo,
      );
    });

    test(
      'getRoomLeaderboard accurately calculates wins, win rate, and streak across 5 sequential rounds',
      () async {
        const roomId = 'room-alpha';
        const gameId = 'game-alpha';

        // Simulate Round 1: Valtry Won
        await repository.finishRound(
          gameId: gameId,
          roomId: roomId,
          winnerId: 'user-valtry',
          winnerName: 'Valtry',
          totalCalls: 22,
          playerOutcomes: [
            {
              'user_id': 'user-valtry',
              'display_name': 'Valtry',
              'is_winner': true,
              'is_host': true,
              'lines_claimed_count': 5,
            },
            {
              'user_id': 'user-alex',
              'display_name': 'Alex',
              'is_winner': false,
              'is_host': false,
              'lines_claimed_count': 4,
            },
            {
              'user_id': 'user-maya',
              'display_name': 'Maya',
              'is_winner': false,
              'is_host': false,
              'lines_claimed_count': 2,
            },
          ],
        );

        // Simulate Round 2: Alex Won
        await repository.finishRound(
          gameId: gameId,
          roomId: roomId,
          winnerId: 'user-alex',
          winnerName: 'Alex',
          totalCalls: 16,
          playerOutcomes: [
            {
              'user_id': 'user-alex',
              'display_name': 'Alex',
              'is_winner': true,
              'lines_claimed_count': 5,
            },
            {
              'user_id': 'user-valtry',
              'display_name': 'Valtry',
              'is_winner': false,
              'lines_claimed_count': 3,
            },
            {
              'user_id': 'user-maya',
              'display_name': 'Maya',
              'is_winner': false,
              'lines_claimed_count': 3,
            },
          ],
        );

        // Simulate Round 3: Maya Won
        await repository.finishRound(
          gameId: gameId,
          roomId: roomId,
          winnerId: 'user-maya',
          winnerName: 'Maya',
          totalCalls: 19,
          playerOutcomes: [
            {
              'user_id': 'user-maya',
              'display_name': 'Maya',
              'is_winner': true,
              'lines_claimed_count': 5,
            },
            {
              'user_id': 'user-alex',
              'display_name': 'Alex',
              'is_winner': false,
              'lines_claimed_count': 4,
            },
            {
              'user_id': 'user-valtry',
              'display_name': 'Valtry',
              'is_winner': false,
              'lines_claimed_count': 2,
            },
          ],
        );

        // Simulate Round 4: Alex Won
        await repository.finishRound(
          gameId: gameId,
          roomId: roomId,
          winnerId: 'user-alex',
          winnerName: 'Alex',
          totalCalls: 21,
          playerOutcomes: [
            {
              'user_id': 'user-alex',
              'display_name': 'Alex',
              'is_winner': true,
              'lines_claimed_count': 5,
            },
            {
              'user_id': 'user-valtry',
              'display_name': 'Valtry',
              'is_winner': false,
              'lines_claimed_count': 3,
            },
            {
              'user_id': 'user-maya',
              'display_name': 'Maya',
              'is_winner': false,
              'lines_claimed_count': 2,
            },
          ],
        );

        // Simulate Round 5: Alex Won
        await repository.finishRound(
          gameId: gameId,
          roomId: roomId,
          winnerId: 'user-alex',
          winnerName: 'Alex',
          totalCalls: 18,
          playerOutcomes: [
            {
              'user_id': 'user-alex',
              'display_name': 'Alex',
              'is_winner': true,
              'lines_claimed_count': 5,
            },
            {
              'user_id': 'user-valtry',
              'display_name': 'Valtry',
              'is_winner': false,
              'lines_claimed_count': 4,
            },
            {
              'user_id': 'user-maya',
              'display_name': 'Maya',
              'is_winner': false,
              'lines_claimed_count': 3,
            },
          ],
        );

        // Retrieve cumulative leaderboard
        final leaderboard = await repository.getRoomLeaderboard(roomId);
        expect(leaderboard.length, 3);

        // Alex: 3 wins out of 5 -> 60% win rate, Best streak 2W, Rank 1
        final alex = leaderboard.firstWhere((p) => p['user_id'] == 'user-alex');
        expect(alex['rank'], 1);
        expect(alex['rounds_played'], 5);
        expect(alex['rounds_won'], 3);
        expect(alex['losses'], 2);
        expect(alex['win_rate'], closeTo(60.0, 0.1));
        expect(alex['current_streak'], 2);
        expect(alex['best_streak'], 2);

        // Valtry: 1 win out of 5 -> 20% win rate, Best streak 1W
        final valtry = leaderboard.firstWhere(
          (p) => p['user_id'] == 'user-valtry',
        );
        expect(valtry['rounds_won'], 1);
        expect(valtry['losses'], 4);
        expect(valtry['win_rate'], closeTo(20.0, 0.1));
        expect(valtry['best_streak'], 1);

        // Maya: 1 win out of 5 -> 20% win rate, Best streak 1W
        final maya = leaderboard.firstWhere((p) => p['user_id'] == 'user-maya');
        expect(maya['rounds_won'], 1);
        expect(maya['losses'], 4);
        expect(maya['win_rate'], closeTo(20.0, 0.1));
        expect(maya['best_streak'], 1);

        // Strict Tie-Breaker Invariant: Both Valtry and Maya share Rank #2
        expect(valtry['rank'], 2);
        expect(maya['rank'], 2);

        // Verify match history reverses from R5 down to R1
        final history = await repository.getRoomMatchHistory(roomId);
        expect(history.length, 5);
        expect(history[0]['round_number'], 5);
        expect(history[1]['round_number'], 4);
        expect(history[2]['round_number'], 3);
        expect(history[3]['round_number'], 2);
        expect(history[4]['round_number'], 1);
      },
    );

    test(
      'startNextRound increments round count and resets player boards and timers',
      () async {
        final room = await repository.createRoom(
          name: 'Championship Room',
          maxPlayers: 2,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        final game = await repository.getGameForRoom(room.id);
        expect(game.roundNumber, 1);
        expect(game.status, MultiplayerGameStatus.preparing);

        // Advance to next round
        await repository.startNextRound(
          gameId: game.id,
          roomId: room.id,
          hostId: 'user-valtry',
        );

        final nextGame = await repository.getGameForRoom(room.id);
        expect(nextGame.roundNumber, 2);
        expect(nextGame.status, MultiplayerGameStatus.preparing);
        expect(nextGame.calledNumbers, isEmpty);
        expect(nextGame.winnerId, isNull);
      },
    );
  });
}
