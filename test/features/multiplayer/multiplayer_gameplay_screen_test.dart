import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/gameplay/multiplayer_gameplay_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MultiplayerGameplayScreen renders HUD, turn banner, board, and called numbers rail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final hostProfile = PlayerProfile(
      id: 'host_p1',
      displayName: 'Captain Alice',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockAuth = MockAuthRepository(hostProfile);
    final mockProfile = MockProfileRepository(hostProfile);
    final repository = MultiplayerRepositoryImpl(
      authRepository: mockAuth,
      profileRepository: mockProfile,
    );

    final room = await repository.createRoom(
      name: 'Championship Match',
      maxPlayers: 2,
      prepTimeSeconds: 45,
      turnTimeSeconds: 20,
    );

    // Initial setup: game started with Alice as first caller
    final game = await repository.getGameForRoom(room.id);
    await repository.submitBoard(
      gameId: game.id,
      numbers: BingoBoard.quickShuffle().numbers,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          profileRepositoryProvider.overrideWithValue(mockProfile),
          currentProfileProvider.overrideWithValue(hostProfile),
          multiplayerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: MultiplayerGameplayScreen(roomId: room.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BINGO'), findsWidgets);
    expect(find.text('CHAMPIONSHIP MATCH'), findsOneWidget);
    expect(find.text('LIVE MATCH'), findsOneWidget);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('Players In Room (1)'), findsOneWidget);
    expect(find.text('Private Boards'), findsOneWidget);
    expect(find.text('Your Board'), findsOneWidget);
    expect(find.text('5×5 Standard'), findsOneWidget);
    expect(find.text('Called Numbers'), findsOneWidget);
  });
}
