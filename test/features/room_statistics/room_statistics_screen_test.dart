import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/room_statistics/presentation/room_statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../multiplayer/multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'RoomStatisticsScreen renders segmented tabs, bento metrics, leaderboard, and toggles history',
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

      final room = await repository.createRoom(
        name: 'Weekend BINGO',
        maxPlayers: 2,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );
      final game = await repository.getGameForRoom(room.id);

      // Finish round 1
      await repository.finishRound(
        gameId: game.id,
        roomId: room.id,
        winnerId: 'user-valtry',
        winnerName: 'Valtry',
        totalCalls: 20,
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
            'lines_claimed_count': 3,
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
          child: MaterialApp(home: RoomStatisticsScreen(roomId: room.id)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify screen narrative header
      expect(find.text('ROOM STATISTICS'), findsOneWidget);
      expect(find.text('Friends & rankings'), findsOneWidget);
      expect(find.text('LEADERBOARD'), findsOneWidget);
      expect(find.text('MATCH HISTORY'), findsOneWidget);

      // Verify bento cards
      expect(find.text('ROUNDS'), findsOneWidget);
      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('LEADER'), findsOneWidget);

      // Verify overall standings section
      expect(find.text('Overall Standings'), findsOneWidget);
      expect(find.text('Valtry'), findsWidgets);

      // Tap MATCH HISTORY tab
      await tester.tap(find.text('MATCH HISTORY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify match archive view
      expect(find.text('Match Archive'), findsOneWidget);
      expect(find.textContaining('ROUND 01'), findsOneWidget);
      expect(find.text('BACK TO ROOM LOBBY'), findsOneWidget);
    },
  );
}
