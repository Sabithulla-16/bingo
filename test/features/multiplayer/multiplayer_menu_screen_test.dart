import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/menu/multiplayer_menu_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MultiplayerMenuScreen renders host card, join card, and rules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final profile = PlayerProfile(
      id: 'test_user',
      displayName: 'Alice Gamer',
      email: 'alice@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 750,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockAuth = MockAuthRepository(profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          currentProfileProvider.overrideWithValue(profile),
        ],
        child: const MaterialApp(
          home: MultiplayerMenuScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Multiplayer'), findsOneWidget);
    expect(find.text('Alice Gamer'), findsOneWidget);
    expect(find.text('Play With Friends'), findsOneWidget);
    expect(find.text('Host Private Room'), findsOneWidget);
    expect(find.text('CREATE PRIVATE ROOM'), findsOneWidget);
    expect(find.text('Join with Code'), findsOneWidget);
    expect(find.text('ENTER ROOM CODE'), findsOneWidget);
    expect(find.text('HOW MULTIPLAYER WORKS'), findsOneWidget);
  });
}
