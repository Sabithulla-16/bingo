import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/board_preparation/multiplayer_board_prep_screen.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MultiplayerBoardPrepScreen renders timer, readiness, swap, and confirm controls',
    (WidgetTester tester) async {
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
        name: 'Friday BINGO Club',
        maxPlayers: 3,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            profileRepositoryProvider.overrideWithValue(mockProfile),
            currentProfileProvider.overrideWithValue(hostProfile),
            multiplayerRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(home: MultiplayerBoardPrepScreen(roomId: room.id)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BINGO'), findsWidgets);
      expect(find.text('BOARD PREPARATION'), findsOneWidget);
      expect(find.text('FRIDAY BINGO CLUB'), findsOneWidget);
      expect(find.text('Arrange your board'), findsOneWidget);
      expect(find.text('TIME REMAINING'), findsOneWidget);
      expect(find.text('SYNCED'), findsOneWidget);
      expect(find.text('PLAYER READINESS'), findsOneWidget);
      expect(find.text('Tap two to swap'), findsOneWidget);
      expect(find.text('SHUFFLE BOARD'), findsOneWidget);
      expect(find.text('25 / 25 NUMBERS PLACED'), findsOneWidget);
      expect(find.text('CONFIRM BOARD'), findsOneWidget);

      // Tap Confirm Board
      await tester.tap(find.text('CONFIRM BOARD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BOARD CONFIRMED!'), findsOneWidget);
      expect(find.text('BOARD LOCKED & CONFIRMED'), findsOneWidget);
    },
  );
}
