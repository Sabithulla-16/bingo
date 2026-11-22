import '../domain/multiplayer_game.dart';
import '../domain/quick_match.dart';
import '../domain/quick_match_rematch.dart';
import '../domain/room.dart';
import '../domain/room_lookup_result.dart';

abstract class MultiplayerRepository {
  /// Whether the repository is actively connected to Supabase backend.
  bool get isOnline;

  /// Creates a new private room with generated 6-character code and registers host.
  Future<Room> createRoom({
    required String name,
    required int maxPlayers,
    required int prepTimeSeconds,
    required int turnTimeSeconds,
  });

  /// Joins an existing room using a 6-character room code.
  Future<Room> joinRoomByCode(String code);

  /// Performs authoritative lookup of room status by code without exposing private board data.
  Future<RoomLookupResult> lookupRoomByCode(String code);

  /// Retrieves room metadata by roomId.
  Future<Room?> getRoom(String roomId);

  /// Retrieves all participants currently seated in the room.
  Future<List<RoomPlayer>> getRoomPlayers(String roomId);

  /// Toggles the ready state of the current player.
  Future<void> toggleReady({required String roomId, required bool isReady});

  /// Allows the host to kick a player from the room.
  Future<void> kickPlayer({required String roomId, required String userId});

  /// Allows host to start the game when minimum players are ready.
  Future<void> startGame(String roomId);

  /// Leaves the room (or transfers host / marks closed if host leaves).
  Future<void> leaveRoom(String roomId);

  /// Explicitly closes a room, setting status to CLOSED and recording closed_at.
  Future<void> closeRoom(String roomId);

  /// Stream of room updates (status, settings) in realtime.
  Stream<Room> watchRoom(String roomId);

  /// Stream of participants updates (joins, leaves, ready toggles) in realtime.
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId);

  // --- GAMEPLAY SYNCHRONIZATION METHODS ---

  /// Retrieves the active game for a room (or creates prep phase game if just starting).
  Future<MultiplayerGame> getGameForRoom(String roomId);

  /// Retrieves the current snapshot of all active game player states.
  Future<List<MultiplayerPlayerState>> getGamePlayers(String gameId);

  /// Realtime stream of the game entity (called numbers, turn, status).
  Stream<MultiplayerGame> watchGame(String gameId);

  /// Realtime stream of all players' states (lines claimed, confirmed status).
  Stream<List<MultiplayerPlayerState>> watchGamePlayers(String gameId);

  /// Submits the player's private 25-number board and marks them ready.
  Future<void> submitBoard({
    required String gameId,
    required List<int> numbers,
  });

  /// Retrieves the player's private confirmed 25-number board for this game.
  Future<List<int>?> getPlayerBoard({
    required String gameId,
    required String userId,
  });

  /// Calls an uncalled number on player's turn.
  Future<void> callNumber({required String gameId, required int number});

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

  /// Handles preparation countdown timeout (auto-fills unready boards or forfeits).
  Future<void> handlePrepTimeout({
    required String gameId,
    bool autoFill = true,
  });

  /// Authoritatively handles automatic turn timeout when player fails to call a number.
  Future<Map<String, dynamic>> handleTurnTimeout({
    required String gameId,
    String? currentTurnUserId,
  });

  /// Authoritatively forfeits the match for the calling player.
  /// If 2 players: awards victory to remaining player immediately.
  /// If > 2 players: marks player as forfeited and continues game with remaining players.
  Future<Map<String, dynamic>> forfeitMatch({
    required String gameId,
    required String roomId,
  });

  /// Fetches recent rooms the authenticated user has previously joined or hosted.
  Future<List<Map<String, dynamic>>> getRecentRooms({int limit = 5});

  /// Subscribes to realtime match history updates for the room.
  Stream<List<Map<String, dynamic>>> watchRoomMatchHistory(String roomId);

  // --- RESULTS, LEADERBOARD, AND MULTI-ROUND METHODS ---

  /// Concludes a round, logs outcomes to history, and updates player statistics.
  Future<void> finishRound({
    required String gameId,
    required String roomId,
    required String? winnerId,
    required String winnerName,
    required int totalCalls,
    required List<Map<String, dynamic>> playerOutcomes,
    int? roundNumber,
  });

  /// Retrieves chronological or reverse-chronological match history records for a room.
  Future<List<Map<String, dynamic>>> getRoomMatchHistory(String roomId);

  /// Computes cumulative session standings with tie-breaker resolution for a room.
  Future<List<Map<String, dynamic>>> getRoomLeaderboard(String roomId);

  /// Advances room and game to the next round, resetting player boards and timers.
  Future<void> startNextRound({
    required String gameId,
    required String roomId,
    required String hostId,
  });

  /// Allows the host to remove players who haven't confirmed their boards upon timer expiration.
  Future<void> removeUnreadyPlayers({
    required String roomId,
    required String gameId,
  });

  /// Returns all players to the room lobby after a completed match.
  Future<void> returnToLobby({
    required String roomId,
    required String hostId,
  });

  // --- QUICK MATCH 1v1 MATCHMAKING METHODS ---

  /// Enters the authoritative matchmaking queue or pairs immediately with waiting opponent.
  Future<Map<String, dynamic>> enterMatchmaking({String region = 'auto'});

  /// Atomically cancels active matchmaking queue entry before match commitment.
  Future<Map<String, dynamic>> cancelMatchmaking();

  /// Watches player's own matchmaking queue record in realtime.
  Stream<MatchmakingQueueEntry?> watchMatchmakingQueue(String userId);

  /// Retrieves quick match details by match ID.
  Future<QuickMatch?> getQuickMatch(String matchId);

  /// Watches quick match record updates in realtime.
  Stream<QuickMatch?> watchQuickMatch(String matchId);

  /// Transitions quick match from COUNTDOWN to BOARD_PREPARATION authoritatively.
  Future<Map<String, dynamic>> transitionToBoardPrep(String matchId);

  /// Checks for caller's active quick match (reconnection / session restore).
  Future<QuickMatch?> getActiveQuickMatch();

  /// Retrieves quick match by room ID.
  Future<QuickMatch?> getQuickMatchByRoomId(String roomId);

  /// Retrieves comprehensive Quick Match result data for the result screen.
  Future<QuickMatchResultData?> getQuickMatchResult(String matchId);

  /// Requests a bilateral rematch for a completed quick match.
  Future<Map<String, dynamic>> requestQuickMatchRematch(String previousMatchId);

  /// Accepts or declines a pending rematch request.
  Future<Map<String, dynamic>> respondQuickMatchRematch(String requestId, bool accept);

  /// Cancels a pending rematch request.
  Future<Map<String, dynamic>> cancelQuickMatchRematch(String requestId);

  /// Retrieves active pending rematch request (if any).
  Future<QuickMatchRematchRequest?> getPendingRematchRequest({String? matchId});

  /// Watches a specific rematch request in realtime.
  Stream<QuickMatchRematchRequest?> watchRematchRequest(String requestId);

  /// Watches any incoming/outgoing rematch requests for a user in realtime.
  Stream<QuickMatchRematchRequest?> watchUserRematchRequests(String userId);
}
