import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/supabase/supabase_provider.dart';
import '../../features/authentication/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/multiplayer/board_preparation/multiplayer_board_prep_screen.dart';
import '../../features/multiplayer/create_room/create_room_screen.dart';
import '../../features/multiplayer/gameplay/multiplayer_gameplay_screen.dart';
import '../../features/multiplayer/join_room/join_room_screen.dart';
import '../../features/multiplayer/lobby/multiplayer_lobby_screen.dart';
import '../../features/multiplayer/menu/multiplayer_menu_screen.dart';
import '../../features/multiplayer/result/multiplayer_result_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/room_statistics/presentation/room_statistics_screen.dart';
import '../../features/single_player/board_preparation/single_player_board_prep_screen.dart';
import '../../features/single_player/difficulty/single_player_difficulty_screen.dart';
import '../../features/single_player/gameplay/single_player_gameplay_screen.dart';
import '../../features/single_player/result/single_player_result_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';
import 'route_guards.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) =>
        RouteGuards.authRedirect(context, state, authState),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      // Single Player Routes
      GoRoute(
        path: AppRoutes.singlePlayerDifficulty,
        builder: (context, state) => const SinglePlayerDifficultyScreen(),
      ),
      GoRoute(
        path: AppRoutes.singlePlayerBoardPrep,
        builder: (context, state) => const SinglePlayerBoardPrepScreen(),
      ),
      GoRoute(
        path: AppRoutes.singlePlayerGame,
        builder: (context, state) {
          final gameId = state.pathParameters['gameId'] ?? 'sp_1';
          return SinglePlayerGameplayScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: AppRoutes.singlePlayerResult,
        builder: (context, state) {
          final gameId = state.pathParameters['gameId'] ?? 'sp_1';
          return SinglePlayerResultScreen(gameId: gameId);
        },
      ),

      // Multiplayer Routes
      GoRoute(
        path: AppRoutes.multiplayerMenu,
        builder: (context, state) => const MultiplayerMenuScreen(),
      ),
      GoRoute(
        path: AppRoutes.createRoom,
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinRoom,
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinRoomScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) {
          final code = state.pathParameters['code'];
          return JoinRoomScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: AppRoutes.roomLobby,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? 'ROOM1';
          return MultiplayerLobbyScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.roomBoardPrep,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? 'ROOM1';
          return MultiplayerBoardPrepScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.roomGame,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? 'ROOM1';
          return MultiplayerGameplayScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.roomResult,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? 'ROOM1';
          return MultiplayerResultScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.roomStatistics,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? 'ROOM1';
          return RoomStatisticsScreen(roomId: roomId);
        },
      ),

      // Profile Route
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
