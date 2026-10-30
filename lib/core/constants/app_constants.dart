/// Central application constants and game constraints.
class AppConstants {
  const AppConstants._();

  // Grid dimensions
  static const int boardDimension = 5;
  static const int totalBoardCells = 25;
  static const int minNumber = 1;
  static const int maxNumber = 25;

  // Letters
  static const List<String> bingoLetters = ['B', 'I', 'N', 'G', 'O'];
  static const int linesRequiredToWin = 5;
  static const int totalPossibleWinningLines = 12;

  // Multiplayer Room limits
  static const int minRoomPlayers = 2;
  static const int maxRoomPlayers = 4;
  static const int roomCodeLength = 6;

  // Default Timers (in seconds)
  static const int defaultPrepTimeSeconds = 45;
  static const int defaultTurnTimeSeconds = 20;

  // Tagline
  static const String appTagline = 'Pick • Mark • Strike • Win';
}
