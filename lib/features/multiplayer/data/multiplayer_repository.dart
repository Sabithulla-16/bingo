import '../domain/multiplayer_game.dart';
import '../domain/room.dart';

abstract class MultiplayerRepository {
  /// Creates a new private room with generated 6-character code and registers host.
  Future<Room> createRoom({
    required String name,
    required int maxPlayers,
    required int prepTimeSeconds,
    required int turnTimeSeconds,
  });

  /// Joins an existing room using a 6-character room code.
  Future<Room> joinRoomByCode(String code);

  /// Retrieves room metadata by roomId.
  Future<Room?> getRoom(String roomId);

  /// Retrieves all participants currently seated in the room.
  Future<List<RoomPlayer>> getRoomPlayers(String roomId);

  /// Toggles the ready state of the current player.
  Future<void> toggleReady({
    required String roomId,
    required bool isReady,
  });

  /// Allows the host to kick a player from the room.
  Future<void> kickPlayer({
    required String roomId,
    required String userId,
  });

  /// Allows host to start the game when minimum players are ready.
  Future<void> startGame(String roomId);

  /// Leaves the room (or deletes room if host leaves).
  Future<void> leaveRoom(String roomId);

  /// Stream of room updates (status, settings) in realtime.
  Stream<Room> watchRoom(String roomId);

  /// Stream of participants updates (joins, leaves, ready toggles) in realtime.
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId);

  // --- GAMEPLAY SYNCHRONIZATION METHODS ---

  /// Retrieves the active game for a room (or creates prep phase game if just starting).
  Future<MultiplayerGame> getGameForRoom(String roomId);

  /// Realtime stream of the game entity (called numbers, turn, status).
  Stream<MultiplayerGame> watchGame(String gameId);

  /// Realtime stream of all players' states (lines claimed, confirmed status).
  Stream<List<MultiplayerPlayerState>> watchGamePlayers(String gameId);

  /// Submits the player's private 25-number board and marks them ready.
  Future<void> submitBoard({
    required String gameId,
    required List<int> numbers,
  });

  /// Calls an uncalled number on player's turn.
  Future<void> callNumber({
    required String gameId,
    required int number,
  });

  /// Claims a completed line and returns true if this claim won the match (5 lines).
  Future<bool> claimLine({
    required String gameId,
    required String lineType,
    required List<int> numbers,
  });

  /// Allows host to extend the preparation timer if some players are not ready.
  Future<void> extendPrepTime({
    required String gameId,
    int extensionSeconds = 30,
  });
}
