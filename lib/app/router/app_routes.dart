/// Centralized route constants for all 16 screens.
class AppRoutes {
  const AppRoutes._();

  // Root & Auth
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String home = '/home';

  // Single Player
  static const String singlePlayerDifficulty = '/single-player/difficulty';
  static const String singlePlayerBoardPrep =
      '/single-player/board-preparation';
  static const String singlePlayerGame = '/single-player/game/:gameId';
  static const String singlePlayerResult = '/single-player/result/:gameId';

  // Multiplayer
  static const String multiplayerMenu = '/multiplayer';
  static const String createRoom = '/multiplayer/create-room';
  static const String joinRoom = '/multiplayer/join-room';
  static const String roomLobby = '/multiplayer/room/:roomId/lobby';
  static const String roomBoardPrep =
      '/multiplayer/room/:roomId/board-preparation';
  static const String roomGame = '/multiplayer/room/:roomId/game';
  static const String roomResult = '/multiplayer/room/:roomId/result';
  static const String roomStatistics = '/multiplayer/room/:roomId/statistics';

  // Profile
  static const String profile = '/profile';

  // Helper generators for parameterized paths
  static String singlePlayerGamePath(String gameId) =>
      '/single-player/game/$gameId';
  static String singlePlayerResultPath(String gameId) =>
      '/single-player/result/$gameId';
  static String roomLobbyPath(String roomId) =>
      '/multiplayer/room/$roomId/lobby';
  static String multiplayerLobbyPath(String roomId) => roomLobbyPath(roomId);
  static String roomBoardPrepPath(String roomId) =>
      '/multiplayer/room/$roomId/board-preparation';
  static String multiplayerBoardPrepPath(String roomId) =>
      roomBoardPrepPath(roomId);
  static String roomGamePath(String roomId) => '/multiplayer/room/$roomId/game';
  static String roomResultPath(String roomId) =>
      '/multiplayer/room/$roomId/result';
  static String roomStatisticsPath(String roomId) =>
      '/multiplayer/room/$roomId/statistics';
}
