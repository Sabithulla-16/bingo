import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/app/router/app_routes.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/home/presentation/home_screen.dart';
import 'package:bingo/features/multiplayer/create_room/create_room_screen.dart';
import 'package:bingo/features/multiplayer/join_room/join_room_screen.dart';
import 'package:bingo/features/multiplayer/menu/multiplayer_menu_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final profile = PlayerProfile(
    id: 'test_user',
    displayName: 'Test Gamer',
    email: 'test@bingo.dev',
    avatarColorHex: '#FC695C',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final mockAuth = MockAuthRepository(profile);
  final mockProfile = MockProfileRepository(profile);

  GoRouter createTestRouter({String initialLocation = AppRoutes.home}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.multiplayerMenu,
          builder: (context, state) => const MultiplayerMenuScreen(),
          routes: [
            GoRoute(
              path: 'create-room',
              builder: (context, state) => const CreateRoomScreen(),
            ),
            GoRoute(
              path: 'join-room',
              builder: (context, state) => const JoinRoomScreen(),
            ),
          ],
        ),
      ],
    );
  }

  Widget createTestApp(GoRouter router) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        profileRepositoryProvider.overrideWithValue(mockProfile),
        currentProfileProvider.overrideWithValue(profile),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Multiplayer Navigation & Back Arrow Tests', () {
    testWidgets(
      'Multiplayer back arrow is visible initially and navigates back to Home',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final router = createTestRouter();
        await tester.pumpWidget(createTestApp(router));
        await tester.pumpAndSettle();

        // 1. On Home screen, tap "Play Multiplayer"
        expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);
        await tester.tap(find.text('PLAY MULTIPLAYER'));
        await tester.pumpAndSettle();

        // 2. On Multiplayer screen, back arrow must be present
        expect(find.text('Multiplayer'), findsOneWidget);
        final backArrow = find.byTooltip('Back');
        expect(backArrow, findsOneWidget);

        // 3. Tap back arrow -> returns to Home screen
        await tester.tap(backArrow);
        await tester.pumpAndSettle();

        expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);
        expect(find.text('Single Player'), findsOneWidget);
      },
    );

    testWidgets(
      'Multiplayer back arrow remains consistently visible after exiting Create Room',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final router = createTestRouter();
        await tester.pumpWidget(createTestApp(router));
        await tester.pumpAndSettle();

        // 1. Home -> Multiplayer
        await tester.tap(find.text('PLAY MULTIPLAYER'));
        await tester.pumpAndSettle();
        expect(find.text('Multiplayer'), findsOneWidget);

        // 2. Multiplayer -> Create Room
        await tester.tap(find.text('CREATE PRIVATE ROOM'));
        await tester.pumpAndSettle();
        expect(find.text('Room Settings'), findsOneWidget);

        // 3. Exit Create Room via its back button
        final createRoomBack = find.byTooltip('Back to Multiplayer');
        expect(createRoomBack, findsOneWidget);
        await tester.tap(createRoomBack);
        await tester.pumpAndSettle();

        // 4. Verify user is on Multiplayer and back arrow IS VISIBLE
        expect(find.text('Multiplayer'), findsOneWidget);
        final backArrow = find.byTooltip('Back');
        expect(backArrow, findsOneWidget);

        // 5. Press back arrow -> successfully navigates to Home
        await tester.tap(backArrow);
        await tester.pumpAndSettle();

        expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);
      },
    );

    testWidgets(
      'Multiplayer back arrow remains consistently visible after exiting Join Room',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final router = createTestRouter();
        await tester.pumpWidget(createTestApp(router));
        await tester.pumpAndSettle();

        // 1. Home -> Multiplayer
        await tester.tap(find.text('PLAY MULTIPLAYER'));
        await tester.pumpAndSettle();

        // 2. Multiplayer -> Join Room
        await tester.tap(find.text('ENTER ROOM CODE'));
        await tester.pumpAndSettle();
        expect(find.text('Join Room'), findsOneWidget);

        // 3. Exit Join Room via its back button
        final joinRoomBack = find.byTooltip('Back to Multiplayer');
        expect(joinRoomBack, findsOneWidget);
        await tester.tap(joinRoomBack);
        await tester.pumpAndSettle();

        // 4. Verify back arrow is still present
        expect(find.text('Multiplayer'), findsOneWidget);
        final backArrow = find.byTooltip('Back');
        expect(backArrow, findsOneWidget);

        // 5. Tap back arrow -> navigates to Home
        await tester.tap(backArrow);
        await tester.pumpAndSettle();
        expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);
      },
    );

    testWidgets(
      'Repeated back-and-forth navigation does not lose back arrow or corrupt state',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final router = createTestRouter();
        await tester.pumpWidget(createTestApp(router));
        await tester.pumpAndSettle();

        for (int i = 0; i < 3; i++) {
          // Open Multiplayer
          await tester.tap(find.text('PLAY MULTIPLAYER'));
          await tester.pumpAndSettle();

          // Open Create Room
          await tester.tap(find.text('CREATE PRIVATE ROOM'));
          await tester.pumpAndSettle();

          // Exit Create Room
          await tester.tap(find.byTooltip('Back to Multiplayer'));
          await tester.pumpAndSettle();

          // Check back button exists
          expect(find.byTooltip('Back'), findsOneWidget);

          // Open Join Room
          await tester.tap(find.text('ENTER ROOM CODE'));
          await tester.pumpAndSettle();

          // Exit Join Room
          await tester.tap(find.byTooltip('Back to Multiplayer'));
          await tester.pumpAndSettle();

          // Check back button exists
          expect(find.byTooltip('Back'), findsOneWidget);

          // Back to Home
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);
        }
      },
    );
  });
}
