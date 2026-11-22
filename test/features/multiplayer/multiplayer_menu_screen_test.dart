import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/services/connectivity_service.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/multiplayer/menu/multiplayer_menu_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'MultiplayerMenuScreen renders host card, join card, and rules for online registered user',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = PlayerProfile(
        id: 'reg_user_123',
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
            connectivityServiceProvider.overrideWithValue(
              ConnectivityService(() async => true),
            ),
            authRepositoryProvider.overrideWithValue(mockAuth),
            currentProfileProvider.overrideWithValue(profile),
          ],
          child: const MaterialApp(home: MultiplayerMenuScreen()),
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
    },
  );

  testWidgets(
    'MultiplayerMenuScreen renders guest restriction view when user is guest',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final guestProfile = PlayerProfile(
        id: 'guest_12345678',
        displayName: 'Guest Player',
        email: 'guest@bingo.app',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockAuth = MockAuthRepository(guestProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityServiceProvider.overrideWithValue(
              ConnectivityService(() async => true),
            ),
            authRepositoryProvider.overrideWithValue(mockAuth),
            currentProfileProvider.overrideWithValue(guestProfile),
          ],
          child: const MaterialApp(home: MultiplayerMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('Play Multiplayer with Friends'), findsOneWidget);
      expect(
        find.text(
          'Multiplayer rooms require an authenticated BINGO account so your match history, chips, and stats are saved safely.',
        ),
        findsOneWidget,
      );
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('NOT NOW'), findsOneWidget);
    },
  );

  testWidgets(
    'MultiplayerMenuScreen renders offline view when device is offline',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = PlayerProfile(
        id: 'reg_user_123',
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
            connectivityServiceProvider.overrideWithValue(
              ConnectivityService(() async => false),
            ),
            authRepositoryProvider.overrideWithValue(mockAuth),
            currentProfileProvider.overrideWithValue(profile),
          ],
          child: const MaterialApp(home: MultiplayerMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're Offline"), findsOneWidget);
      expect(
        find.text(
          'Multiplayer requires an active internet connection to connect with other players in realtime.',
        ),
        findsOneWidget,
      );
      expect(find.text('TRY AGAIN'), findsOneWidget);
      expect(find.text('GO BACK'), findsOneWidget);
    },
  );
}
