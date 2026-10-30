import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/app/router/app_routes.dart';

void main() {
  group('AppRoutes Constants & Generator Tests', () {
    test('verifies static constant paths for base routes', () {
      expect(AppRoutes.splash, '/splash');
      expect(AppRoutes.auth, '/auth');
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.singlePlayerDifficulty, '/single-player/difficulty');
      expect(
        AppRoutes.singlePlayerBoardPrep,
        '/single-player/board-preparation',
      );
      expect(AppRoutes.multiplayerMenu, '/multiplayer');
      expect(AppRoutes.createRoom, '/multiplayer/create-room');
      expect(AppRoutes.joinRoom, '/multiplayer/join-room');
      expect(AppRoutes.profile, '/profile');
    });

    test('verifies parameter path generators produce correct URIs', () {
      expect(
        AppRoutes.singlePlayerGamePath('game_99'),
        '/single-player/game/game_99',
      );
      expect(
        AppRoutes.singlePlayerResultPath('game_99'),
        '/single-player/result/game_99',
      );
      expect(
        AppRoutes.roomLobbyPath('BG1234'),
        '/multiplayer/room/BG1234/lobby',
      );
      expect(
        AppRoutes.roomBoardPrepPath('BG1234'),
        '/multiplayer/room/BG1234/board-preparation',
      );
      expect(AppRoutes.roomGamePath('BG1234'), '/multiplayer/room/BG1234/game');
      expect(
        AppRoutes.roomResultPath('BG1234'),
        '/multiplayer/room/BG1234/result',
      );
      expect(
        AppRoutes.roomStatisticsPath('BG1234'),
        '/multiplayer/room/BG1234/statistics',
      );
    });
  });
}
