import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/result/multiplayer_result_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MultiplayerResultScreen renders header, hero banner, player cards, and leaderboard preview',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = PlayerProfile(
        id: 'user-valtry',
        displayName: 'Valtry',
        email: 'valtry@bingo.test',
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final authRepo = MockAuthRepository(profile);
      final profileRepo = MockProfileRepository(profile);

      final repository = MultiplayerRepositoryImpl(
        supabaseClient: null,
        authRepository: authRepo,
        profileRepository: profileRepo,
      );

      // Create room and start game
      final room = await repository.createRoom(
        name: 'Friday BINGO Club',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );
      final game = await repository.getGameForRoom(room.id);

      // Conclude round with Valtry as Winner
      await repository.finishRound(
        gameId: game.id,
        roomId: room.id,
        winnerId: 'user-valtry',
        winnerName: 'Valtry',
        totalCalls: 18,
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
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            currentProfileProvider.overrideWithValue(profile),
            multiplayerRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(home: MultiplayerResultScreen(roomId: room.id)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and BINGO logo
      expect(find.text('BINGO'), findsOneWidget);
      expect(find.textContaining('ROOM:'), findsWidgets);

      // Verify room context banner
      expect(find.text('FRIDAY BINGO CLUB'), findsOneWidget);
      expect(find.textContaining('ROUND 01 COMPLETED'), findsOneWidget);

      // Verify hero banner
      expect(find.text('VICTORY!'), findsOneWidget);
      expect(find.textContaining('Finished on Call #18'), findsOneWidget);

      // Verify final match results section
      expect(find.text('FINAL MATCH RESULTS'), findsOneWidget);
      expect(find.text('Valtry'), findsWidgets);
      expect(find.text('WINNER 🏆'), findsWidgets);

      // Verify match overview bento grid
      expect(find.text('MATCH OVERVIEW'), findsOneWidget);
      expect(find.text('NUMBERS CALLED'), findsOneWidget);

      // Verify room leaderboard preview
      expect(find.text('ROOM LEADERBOARD'), findsOneWidget);

      // Verify host action controls
      expect(find.text('START NEXT ROUND'), findsOneWidget);
      expect(find.text('VIEW DETAILED ROOM STATS'), findsOneWidget);
    },
  );
}
