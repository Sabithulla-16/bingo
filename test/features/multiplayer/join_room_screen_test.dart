import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/join_room/join_room_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'JoinRoomScreen renders 6-box input, recent rooms and validates code',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final guestProfile = PlayerProfile(
        id: 'guest_id',
        displayName: 'Guest Player',
        email: 'guest@bingo.dev',
        avatarColorHex: '#20243A',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockAuth = MockAuthRepository(guestProfile);
      final mockProfile = MockProfileRepository(guestProfile);
      final repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );

      // Create an existing room to join
      final room = await repository.createRoom(
        name: 'Open Game',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            profileRepositoryProvider.overrideWithValue(mockProfile),
            currentProfileProvider.overrideWithValue(guestProfile),
            multiplayerRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: JoinRoomScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join Room'), findsOneWidget);
      expect(find.text('Enter Room Code'), findsOneWidget);
      expect(find.text('RECENT ROOMS'), findsOneWidget);

      // Enter valid 6-char code
      await tester.enterText(find.byType(TextField), room.code);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('JoinRoomScreen prefills code from deep link initialCode', (
    WidgetTester tester,
  ) async {
    final guestProfile = PlayerProfile(
      id: 'guest_id',
      displayName: 'Guest Player',
      email: 'guest@bingo.dev',
      avatarColorHex: '#20243A',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockAuth = MockAuthRepository(guestProfile);
    final mockProfile = MockProfileRepository(guestProfile);
    final repository = MultiplayerRepositoryImpl(
      authRepository: mockAuth,
      profileRepository: mockProfile,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          profileRepositoryProvider.overrideWithValue(mockProfile),
          currentProfileProvider.overrideWithValue(guestProfile),
          multiplayerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: JoinRoomScreen(initialCode: 'DEEP99')),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, equals('DEEP99'));
  });
}
