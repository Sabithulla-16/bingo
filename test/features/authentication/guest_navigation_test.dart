import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/app/router/app_routes.dart';
import 'package:bingo/app/router/route_guards.dart';
import 'package:bingo/core/widgets/primary_button.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/authentication/presentation/auth_screen.dart';
import 'package:bingo/features/home/presentation/home_screen.dart';
import 'package:bingo/features/multiplayer/menu/multiplayer_menu_screen.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/single_player/difficulty/single_player_difficulty_screen.dart';
import '../multiplayer/multiplayer_repository_test.dart';

class TestAuthStateNotifier extends AuthStateNotifier {
  TestAuthStateNotifier(
    super.authRepository,
    super.profileRepository, {
    AppAuthState initialState = const AuthInitial(),
  }) {
    state = initialState;
  }

  void setCustomState(AppAuthState newState) {
    state = newState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final guestProfile = PlayerProfile(
    id: 'guest_12345',
    displayName: 'Guest Player',
    email: 'guest@bingo.app',
    chips: 500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final authProfile = PlayerProfile(
    id: 'user_registered_99',
    displayName: 'Pro Player',
    email: 'pro@bingo.app',
    chips: 1000,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Part 2 - RouteGuards.authRedirect Integration Tests', () {
    GoRouter createTestRouter(AppAuthState authState, {String initialLocation = AppRoutes.home}) {
      return GoRouter(
        initialLocation: initialLocation,
        redirect: (context, state) => RouteGuards.authRedirect(context, state, authState),
        routes: [
          GoRoute(path: AppRoutes.splash, builder: (c, s) => const Scaffold(body: Text('Splash'))),
          GoRoute(path: AppRoutes.auth, builder: (c, s) => const Scaffold(body: Text('Auth'))),
          GoRoute(path: AppRoutes.home, builder: (c, s) => const Scaffold(body: Text('Home'))),
          GoRoute(path: AppRoutes.multiplayerMenu, builder: (c, s) => const Scaffold(body: Text('Multiplayer'))),
        ],
      );
    }

    testWidgets('AuthGuest is ALLOWED to visit AppRoutes.auth without being redirected to Home', (
      WidgetTester tester,
    ) async {
      final router = createTestRouter(AuthGuest(guestProfile), initialLocation: AppRoutes.home);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      // Navigate to Auth
      router.go('${AppRoutes.auth}?mode=signIn');
      await tester.pumpAndSettle();

      // Verified: stays on Auth, not redirected to Home!
      expect(find.text('Auth'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.auth);
    });

    testWidgets('Authenticated user on AppRoutes.auth with valid redirect returns redirect target', (
      WidgetTester tester,
    ) async {
      final router = createTestRouter(
        Authenticated(authProfile),
        initialLocation: '${AppRoutes.auth}?mode=signIn&redirect=${Uri.encodeComponent(AppRoutes.multiplayerMenu)}',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verified: redirected to Multiplayer!
      expect(find.text('Multiplayer'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.multiplayerMenu);
    });

    testWidgets('Authenticated user on AppRoutes.auth without redirect redirects to Home', (
      WidgetTester tester,
    ) async {
      final router = createTestRouter(Authenticated(authProfile), initialLocation: AppRoutes.auth);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verified: redirected to Home!
      expect(find.text('Home'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.home);
    });

    testWidgets('Authenticated user on AppRoutes.auth with invalid redirect falls back to Home', (
      WidgetTester tester,
    ) async {
      final router = createTestRouter(
        Authenticated(authProfile),
        initialLocation: '${AppRoutes.auth}?redirect=https://external-phish.com',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.home);
    });

    testWidgets('Unauthenticated user is redirected to AppRoutes.auth', (
      WidgetTester tester,
    ) async {
      final router = createTestRouter(const Unauthenticated(), initialLocation: AppRoutes.home);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Auth'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.auth);
    });
  });

  group('Part 3 - End-to-End Regression Tests (A - F)', () {
    GoRouter createGuestRouter({
      required AppAuthState currentAuthState,
      String initialLocation = AppRoutes.home,
    }) {
      return GoRouter(
        initialLocation: initialLocation,
        redirect: (context, state) =>
            RouteGuards.authRedirect(context, state, currentAuthState),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.auth,
            builder: (context, state) {
              final modeStr = state.uri.queryParameters['mode'];
              final initialMode = modeStr == 'signIn'
                  ? AuthMode.signIn
                  : modeStr == 'forgot'
                  ? AuthMode.forgotPassword
                  : AuthMode.register;
              final redirectUrl =
                  state.uri.queryParameters['redirect'] ?? (state.extra as String?);
              return AuthScreen(
                initialMode: initialMode,
                redirectUrl: redirectUrl,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.multiplayerMenu,
            builder: (context, state) => const MultiplayerMenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.singlePlayerDifficulty,
            builder: (context, state) => const SinglePlayerDifficultyScreen(),
          ),
        ],
      );
    }

    Widget buildApp({
      required GoRouter router,
      required PlayerProfile profile,
      required AppAuthState authState,
    }) {
      final mockAuth = MockAuthRepository(profile);
      final mockProfile = MockProfileRepository(profile);

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          profileRepositoryProvider.overrideWithValue(mockProfile),
          currentProfileProvider.overrideWithValue(profile),
          authStateProvider.overrideWith(
            (ref) => TestAuthStateNotifier(mockAuth, mockProfile, initialState: authState),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('Test A: Guest selects Login from Multiplayer -> Login screen opens (not Home)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createGuestRouter(
        currentAuthState: AuthGuest(guestProfile),
        initialLocation: AppRoutes.home,
      );

      await tester.pumpWidget(
        buildApp(
          router: router,
          profile: guestProfile,
          authState: AuthGuest(guestProfile),
        ),
      );
      await tester.pumpAndSettle();

      // Home Screen visible
      expect(find.text('PLAY MULTIPLAYER'), findsOneWidget);

      // Navigate to Multiplayer
      await tester.tap(find.text('PLAY MULTIPLAYER'));
      await tester.pumpAndSettle();

      // Multiplayer restriction view is visible
      expect(find.text('ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('Play Multiplayer with Friends'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);

      // Select Login / Sign In
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      // VERIFY: Login Screen opens (not Home!)
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.auth);
      expect(router.state.uri.queryParameters['mode'], 'signIn');
      expect(router.state.uri.queryParameters['redirect'], AppRoutes.multiplayerMenu);
    });

    testWidgets('Test B: Guest selects Sign Up from Multiplayer -> Registration screen opens', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createGuestRouter(
        currentAuthState: AuthGuest(guestProfile),
        initialLocation: AppRoutes.multiplayerMenu,
      );

      await tester.pumpWidget(
        buildApp(
          router: router,
          profile: guestProfile,
          authState: AuthGuest(guestProfile),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);

      // Select Sign Up
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      // VERIFY: Registration Screen opens
      expect(find.text("Let's get you started!"), findsOneWidget);
      expect(find.text('YOUR NAME'), findsOneWidget);
      expect(router.state.matchedLocation, AppRoutes.auth);
      expect(router.state.uri.queryParameters['mode'], 'register');
      expect(router.state.uri.queryParameters['redirect'], AppRoutes.multiplayerMenu);
    });

    testWidgets('Test C: Guest authenticates successfully -> Restores intended destination (Multiplayer)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockAuthRepository(authProfile);
      final mockProfile = MockProfileRepository(authProfile);

      final router = GoRouter(
        initialLocation: '${AppRoutes.auth}?mode=signIn&redirect=${Uri.encodeComponent(AppRoutes.multiplayerMenu)}',
        routes: [
          GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.auth,
            builder: (context, state) {
              final redirectUrl = state.uri.queryParameters['redirect'];
              return AuthScreen(
                initialMode: AuthMode.signIn,
                redirectUrl: redirectUrl,
              );
            },
          ),
          GoRoute(path: AppRoutes.multiplayerMenu, builder: (c, s) => const MultiplayerMenuScreen()),
        ],
      );

      final testNotifier = TestAuthStateNotifier(mockAuth, mockProfile, initialState: AuthGuest(guestProfile));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            profileRepositoryProvider.overrideWithValue(mockProfile),
            currentProfileProvider.overrideWithValue(authProfile),
            authStateProvider.overrideWith((ref) => testNotifier),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back!'), findsOneWidget);

      // Enter email and password
      await tester.enterText(find.widgetWithText(TextField, 'Enter your email'), 'test@bingo.app');
      await tester.enterText(find.widgetWithText(TextField, 'Enter your password'), 'password123');
      await tester.pumpAndSettle();

      // Tap Sign In button
      final signInButton = find.widgetWithText(PrimaryButton, 'SIGN IN');
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // VERIFY: Navigates to intended destination: MultiplayerMenuScreen!
      expect(router.state.matchedLocation, AppRoutes.multiplayerMenu);
      expect(find.text('CREATE PRIVATE ROOM'), findsOneWidget);
      expect(find.text('Join with Code'), findsOneWidget);
    });

    testWidgets('Test D: Back Navigation from Auth returns to Multiplayer without navigation loops', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createGuestRouter(
        currentAuthState: AuthGuest(guestProfile),
        initialLocation: AppRoutes.multiplayerMenu,
      );

      await tester.pumpWidget(
        buildApp(
          router: router,
          profile: guestProfile,
          authState: AuthGuest(guestProfile),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In to open Auth
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back!'), findsOneWidget);

      // Tap Back button on Auth
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // VERIFY: Returns to Multiplayer restriction view, not Home and no loops
      expect(find.text('ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('Play Multiplayer with Friends'), findsOneWidget);
    });

    testWidgets('Test E: Existing authenticated user opens Multiplayer with normal access', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createGuestRouter(
        currentAuthState: Authenticated(authProfile),
        initialLocation: AppRoutes.home,
      );

      await tester.pumpWidget(
        buildApp(
          router: router,
          profile: authProfile,
          authState: Authenticated(authProfile),
        ),
      );
      await tester.pumpAndSettle();

      // Home screen -> tap Play Multiplayer
      await tester.tap(find.text('PLAY MULTIPLAYER'));
      await tester.pumpAndSettle();

      // VERIFY: Authenticated user reaches multiplayer lobby menu directly
      expect(find.text('CREATE PRIVATE ROOM'), findsOneWidget);
      expect(find.text('Join with Code'), findsOneWidget);
      expect(find.text('ACCOUNT REQUIRED'), findsNothing);
    });

    testWidgets('Test F: Guest single-player access remains functional', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createGuestRouter(
        currentAuthState: AuthGuest(guestProfile),
        initialLocation: AppRoutes.home,
      );

      await tester.pumpWidget(
        buildApp(
          router: router,
          profile: guestProfile,
          authState: AuthGuest(guestProfile),
        ),
      );
      await tester.pumpAndSettle();

      // Home Screen -> tap Play Single Player
      expect(find.text('PLAY SINGLE PLAYER'), findsOneWidget);
      await tester.tap(find.text('PLAY SINGLE PLAYER'));
      await tester.pumpAndSettle();

      // VERIFY: Reaches difficulty screen
      expect(find.text('Select Difficulty'), findsOneWidget);
      expect(find.text('EASY'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('HARD'), findsOneWidget);
    });
  });
}
