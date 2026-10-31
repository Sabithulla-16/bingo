import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/create_room/create_room_screen.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_provider.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CreateRoomScreen renders form fields and timer options', (
    WidgetTester tester,
  ) async {
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          profileRepositoryProvider.overrideWithValue(mockProfile),
          currentProfileProvider.overrideWithValue(hostProfile),
          multiplayerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CreateRoomScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Room Settings'), findsOneWidget);
    expect(find.text('Configure Your Room'), findsOneWidget);
    expect(find.text('ROOM NAME'), findsOneWidget);
    expect(find.text('MAX PLAYERS'), findsOneWidget);
    expect(find.text('2 Players'), findsOneWidget);
    expect(find.text('3 Players'), findsOneWidget);
    expect(find.text('4 Players'), findsOneWidget);
    expect(find.text('BOARD PREPARATION TIME'), findsOneWidget);
    expect(find.text('TURN TIME LIMIT'), findsOneWidget);
    expect(find.text('CREATE ROOM & INVITE'), findsOneWidget);

    // Tap 2 Players
    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();
  });
}
