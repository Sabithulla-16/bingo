import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/multiplayer/lobby/multiplayer_lobby_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MultiplayerLobbyScreen renders room code, slots and host start controls',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hostProfile = PlayerProfile(
        id: 'host_id',
        displayName: 'Captain Host',
        email: 'host@bingo.dev',
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
        name: 'Championship Lobby',
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
          child: MaterialApp(home: MultiplayerLobbyScreen(roomId: room.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Championship Lobby'), findsOneWidget);
      expect(find.text('ROOM CODE'), findsOneWidget);
      expect(find.text(room.code), findsOneWidget);
      expect(find.text('45s Prep'), findsOneWidget);
      expect(find.text('20s Turn'), findsOneWidget);
      expect(find.text('PARTICIPANTS (1/3)'), findsOneWidget);
      expect(find.text('Captain Host'), findsOneWidget);
    },
  );
}
