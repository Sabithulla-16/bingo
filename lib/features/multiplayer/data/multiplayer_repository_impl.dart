import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
import '../../../core/game_engine/bingo_board.dart';
import '../../../core/game_engine/winning_line.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/multiplayer_game.dart';
import '../domain/quick_match.dart';
import '../domain/quick_match_rematch.dart';
import '../domain/room.dart';
import '../domain/room_lookup_result.dart';
import 'multiplayer_repository.dart';

class MultiplayerRepositoryImpl implements MultiplayerRepository {
  final SupabaseClient? _supabaseClient;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  // In-memory fallback stores for offline mode & multi-client testing
  static final Map<String, Room> _localRooms = {};
  static final Map<String, List<RoomPlayer>> _localPlayers = {};
  static final Map<String, StreamController<Room>> _roomControllers = {};
  static final Map<String, StreamController<List<RoomPlayer>>>
  _playersControllers = {};
  static final Map<String, StreamController<List<Map<String, dynamic>>>>
  _historyControllers = {};
  static final Map<String, RealtimeChannel> _roomChannels = {};
  static final Map<String, RealtimeChannel> _gameChannels = {};

  static final Map<String, MultiplayerGame> _localGames = {};
  static final Map<String, List<MultiplayerPlayerState>> _localGamePlayers = {};
  static final Map<String, StreamController<MultiplayerGame>> _gameControllers =
      {};
  static final Map<String, StreamController<List<MultiplayerPlayerState>>>
  _gamePlayersControllers = {};
  static final Map<String, List<Map<String, dynamic>>> _localRoomHistory = {};
  static final Map<String, MatchmakingQueueEntry> _localQueue = {};
  static final Map<String, QuickMatch> _localQuickMatches = {};
  static final Map<String, StreamController<MatchmakingQueueEntry?>>
  _queueControllers = {};
  static final Map<String, StreamController<QuickMatch?>>
  _quickMatchControllers = {};
  static final Map<String, RealtimeChannel> _queueChannels = {};
  static final Map<String, RealtimeChannel> _quickMatchChannels = {};
  static final Map<String, QuickMatchRematchRequest> _localRematchRequests = {};
  static final Map<String, StreamController<QuickMatchRematchRequest?>>
  _rematchControllers = {};
  static final Map<String, StreamController<QuickMatchRematchRequest?>>
  _userRematchControllers = {};
  static final Map<String, RealtimeChannel> _rematchChannels = {};

  @visibleForTesting
  Map<String, MultiplayerGame> get localGamesForTesting => _localGames;

  @visibleForTesting
  Map<String, List<MultiplayerPlayerState>> get localGamePlayersForTesting =>
      _localGamePlayers;

  @visibleForTesting
  static void resetStaticStoresForTesting() {
    _localRooms.clear();
    _localPlayers.clear();
    _roomControllers.clear();
    _playersControllers.clear();
    _historyControllers.clear();
    _roomChannels.clear();
    _gameChannels.clear();
    _localGames.clear();
    _localGamePlayers.clear();
    _gameControllers.clear();
    _gamePlayersControllers.clear();
    _localRoomHistory.clear();
    _localQueue.clear();
    _localQuickMatches.clear();
    _queueControllers.clear();
    _quickMatchControllers.clear();
    _queueChannels.clear();
    _quickMatchChannels.clear();
  }

  MultiplayerRepositoryImpl({
    SupabaseClient? supabaseClient,
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
  }) : _supabaseClient = supabaseClient,
       _authRepository = authRepository,
       _profileRepository = profileRepository;

  @override
  bool get isOnline => _isOnline;

  bool get _isOnline =>
      _supabaseClient != null && _supabaseClient.auth.currentUser != null;

  String _generateRoomCode() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing 0/O, 1/I
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<PlayerProfile?> _getCurrentProfile() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return null;
    return _profileRepository.getProfile(userId);
  }

  @override
  Future<Room> createRoom({
    required String name,
    required int maxPlayers,
    required int prepTimeSeconds,
    required int turnTimeSeconds,
  }) async {
    final currentProfile = await _getCurrentProfile();
    if (_authRepository.isGuest || currentProfile?.isGuest == true) {
      throw StateError(
        'Guest users cannot access multiplayer. Please create an account or sign in.',
      );
    }

    final userId =
        currentProfile?.id ??
        _authRepository.currentUserId ??
        'host_${DateTime.now().millisecondsSinceEpoch}';
    final userName = currentProfile?.displayName ?? 'Host Player';
    final userAvatar = currentProfile?.avatarColorHex ?? '#FF6B5E';

    final roomId = const Uuid().v4();
    final code = _generateRoomCode();

    final room = Room(
      id: roomId,
      code: code,
      name: name.trim().isEmpty ? 'Bingo Room' : name.trim(),
      hostId: userId,
      maxPlayers: maxPlayers,
      prepTimeSeconds: prepTimeSeconds,
      turnTimeSeconds: turnTimeSeconds,
      status: RoomStatus.waiting,
      createdAt: DateTime.now(),
    );

    final hostPlayer = RoomPlayer(
      id: const Uuid().v4(),
      roomId: roomId,
      userId: userId,
      displayName: userName,
      avatarColorHex: userAvatar,
      isHost: true,
      isReady: true, // Host is ready by default
      seatIndex: 0,
      joinedAt: DateTime.now(),
    );

    if (_isOnline) {
      try {
        final insertedRoom = await _supabaseClient!
            .from('rooms')
            .insert(room.toMap())
            .select()
            .single();

        await _supabaseClient.from('room_players').insert(hostPlayer.toDbMap());
        final created = Room.fromMap(insertedRoom);
        _saveRecentRoom(created.code);
        return created;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'createRoom_supabase');
        // Fallback to local
      }
    }

    _localRooms[roomId] = room;
    _localPlayers[roomId] = [hostPlayer];
    _emitRoomUpdate(roomId);
    _emitPlayersUpdate(roomId);
    _saveRecentRoom(room.code);

    return room;
  }

  @override
  Future<RoomLookupResult> lookupRoomByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    Room? targetRoom;
    int playerCount = 0;
    String? hostDisplayName;

    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('rooms')
            .select('*, room_players(*)')
            .eq('code', cleanCode)
            .maybeSingle();

        if (res != null) {
          targetRoom = Room.fromMap(res);
          final playersList = res['room_players'] as List? ?? [];
          playerCount = playersList.length;
          for (final p in playersList) {
            if (p['is_host'] == true || p['user_id'] == targetRoom.hostId) {
              hostDisplayName = p['display_name'] as String?;
              break;
            }
          }
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'lookupRoomByCode_supabase');
      }
    }

    Room? localMatch;
    for (final r in _localRooms.values) {
      if (r.code == cleanCode) {
        localMatch = r;
        break;
      }
    }
    targetRoom ??= localMatch;

    if (targetRoom == null) {
      return RoomLookupResult.notFound(cleanCode);
    }

    if (playerCount == 0) {
      final localP = _localPlayers[targetRoom.id] ?? [];
      playerCount = localP.length;
      RoomPlayer? host;
      for (final p in localP) {
        if (p.isHost) {
          host = p;
          break;
        }
      }
      host ??= localP.isNotEmpty ? localP.first : null;
      hostDisplayName ??= host?.displayName;
    }

    return RoomLookupResult.fromRoom(
      room: targetRoom,
      playerCount: playerCount,
      hostDisplayName: hostDisplayName,
    );
  }

  @override
  Future<Room> joinRoomByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final currentProfile = await _getCurrentProfile();
    if (_authRepository.isGuest || currentProfile?.isGuest == true) {
      throw StateError(
        'Guest users cannot access multiplayer. Please create an account or sign in.',
      );
    }

    // Authoritative lookup & rule check
    final lookup = await lookupRoomByCode(cleanCode);
    if (!lookup.canJoin) {
      throw StateError(lookup.userMessage);
    }

    final userId =
        currentProfile?.id ??
        _authRepository.currentUserId ??
        'host_${DateTime.now().millisecondsSinceEpoch}';
    final userName = currentProfile?.displayName ?? 'Player';
    final userAvatar = currentProfile?.avatarColorHex ?? '#20243A';

    Room? targetRoom;

    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('rooms')
            .select()
            .eq('code', cleanCode)
            .maybeSingle();

        if (res != null) {
          targetRoom = Room.fromMap(res);
        }
      } catch (_) {
        // Fallback to local
      }
    }

    targetRoom ??= _localRooms.values.firstWhere(
      (r) => r.code == cleanCode,
      orElse: () => throw StateError('Room with code "$cleanCode" not found.'),
    );

    if (!targetRoom.isWaiting) {
      throw StateError('This game has already started.');
    }

    // Check capacity
    final currentPlayers = await getRoomPlayers(targetRoom.id);
    if (currentPlayers.length >= targetRoom.maxPlayers) {
      throw StateError(
        'Room is full (${targetRoom.maxPlayers}/${targetRoom.maxPlayers} players).',
      );
    }

    // Check if player already joined
    final existing = currentPlayers.where((p) => p.userId == userId);
    if (existing.isNotEmpty) {
      return targetRoom;
    }

    // Determine seat index
    final occupiedSeats = currentPlayers.map((p) => p.seatIndex).toSet();
    int nextSeat = 0;
    for (int i = 0; i < targetRoom.maxPlayers; i++) {
      if (!occupiedSeats.contains(i)) {
        nextSeat = i;
        break;
      }
    }

    final newPlayer = RoomPlayer(
      id: const Uuid().v4(),
      roomId: targetRoom.id,
      userId: userId,
      displayName: userName,
      avatarColorHex: userAvatar,
      isHost: false,
      isReady: false,
      seatIndex: nextSeat,
      joinedAt: DateTime.now(),
    );

    if (_isOnline) {
      try {
        await _supabaseClient!.from('room_players').insert(newPlayer.toDbMap());
        _saveRecentRoom(targetRoom.code);
        return targetRoom;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'joinRoom_supabase');
        // Fallback to local
      }
    }

    _localPlayers.putIfAbsent(targetRoom.id, () => []);
    _localPlayers[targetRoom.id]!.add(newPlayer);
    _emitPlayersUpdate(targetRoom.id);
    _saveRecentRoom(targetRoom.code);

    return targetRoom;
  }

  @override
  Future<Room?> getRoom(String roomId) async {
    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('rooms')
            .select()
            .eq('id', roomId)
            .maybeSingle();
        if (res != null) {
          return Room.fromMap(res);
        }
      } catch (_) {}
    }
    return _localRooms[roomId];
  }

  @override
  Future<List<RoomPlayer>> getRoomPlayers(String roomId) async {
    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('room_players')
            .select('*, profiles(display_name, avatar_color_hex)')
            .eq('room_id', roomId)
            .order('seat_index');

        final list = (res as List)
            .map((item) => RoomPlayer.fromMap(item as Map<String, dynamic>))
            .toList();
        return list;
      } catch (_) {}
    }
    return List<RoomPlayer>.from(_localPlayers[roomId] ?? []);
  }

  @override
  Future<void> toggleReady({
    required String roomId,
    required bool isReady,
  }) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      throw StateError('Cannot toggle ready: not authenticated');
    }

    if (_isOnline) {
      try {
        await _supabaseClient!
            .from('room_players')
            .update({'is_ready': isReady})
            .eq('room_id', roomId)
            .eq('user_id', userId);
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'toggleReady_supabase');
        rethrow;
      }
    }

    final players = _localPlayers[roomId];
    if (players != null) {
      final index = players.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        players[index] = players[index].copyWith(isReady: isReady);
        _emitPlayersUpdate(roomId);
      }
    }
  }

  @override
  Future<void> kickPlayer({
    required String roomId,
    required String userId,
  }) async {
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_kick_player',
          params: {'p_room_id': roomId, 'p_user_id': userId},
        );
      } catch (_) {
        try {
          await _supabaseClient!
              .from('room_players')
              .delete()
              .eq('room_id', roomId)
              .eq('user_id', userId);
        } catch (_) {}
      }
    }

    final players = _localPlayers[roomId];
    if (players != null) {
      players.removeWhere((p) => p.userId == userId);
      _emitPlayersUpdate(roomId);
    }
  }

  @override
  Future<void> startGame(String roomId) async {
    final room = await getRoom(roomId);
    if (room == null) throw StateError('Room not found');
    if (!room.isWaiting) throw StateError('Room is not waiting');

    final players = await getRoomPlayers(roomId);
    if (players.length < 2) {
      throw StateError('At least 2 players are required to start a game.');
    }

    final notReady = players.where((p) => !p.isReady).toList();
    if (notReady.isNotEmpty) {
      final names = notReady.map((p) => p.displayName).join(', ');
      throw StateError('Cannot start: Waiting for $names to toggle Ready.');
    }

    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_start_board_prep',
          params: {'p_room_id': roomId},
        );
      } catch (e, st) {
        try {
          await _supabaseClient!.rpc(
            'rpc_start_game',
            params: {'p_room_id': roomId},
          );
        } catch (_) {
          ErrorLogger.logUnhandled(e, st, source: 'startGame_supabase');
          try {
            await _supabaseClient!
                .from('rooms')
                .update({'status': 'preparing'})
                .eq('id', roomId);
          } catch (_) {}
        }
      }
    }

    final currentRoom = _localRooms[roomId] ?? room;
    _localRooms[roomId] = currentRoom.copyWith(status: RoomStatus.preparing);
    _emitRoomUpdate(roomId);

    // Create / seed game state locally for instant availability
    final prepSec = room.prepTimeSeconds;
    final gameId =
        _localGames.values.where((g) => g.roomId == roomId).firstOrNull?.id ??
        const Uuid().v4();
    final game = MultiplayerGame(
      id: gameId,
      roomId: roomId,
      status: MultiplayerGameStatus.preparing,
      prepDeadline: DateTime.now().add(Duration(seconds: prepSec)),
      roundNumber: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localGames[gameId] = game;
    _localGamePlayers[gameId] = players
        .map(
          (rp) => MultiplayerPlayerState(
            userId: rp.userId,
            displayName: rp.displayName,
            avatarColorHex: rp.avatarColorHex,
            isHost: rp.isHost,
            seatIndex: rp.seatIndex,
            isBoardConfirmed: false,
            linesClaimed: 0,
          ),
        )
        .toList();
    _emitGameUpdate(gameId);
    _emitGamePlayersUpdate(gameId);
  }

  @override
  Future<void> closeRoom(String roomId) async {
    final now = DateTime.now();
    _unsubscribeFromRoomRealtime(roomId);
    final game = _localGames.values
        .where((g) => g.roomId == roomId)
        .firstOrNull;
    if (game != null) _unsubscribeFromGameRealtime(game.id);
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_close_waiting_room',
          params: {'p_room_id': roomId},
        );
      } catch (_) {
        try {
          await _supabaseClient!.rpc(
            'rpc_close_room',
            params: {'p_room_id': roomId},
          );
        } catch (_) {
          try {
            await _supabaseClient!
                .from('rooms')
                .update({'status': 'closed', 'closed_at': now.toIso8601String()})
                .eq('id', roomId);
            await _supabaseClient
                .from('room_players')
                .delete()
                .eq('room_id', roomId);
          } catch (e, st) {
            ErrorLogger.logUnhandled(e, st, source: 'closeRoom_supabase');
          }
        }
      }
    }

    final currentRoom = _localRooms[roomId] ?? await getRoom(roomId);
    if (currentRoom != null) {
      final updated = currentRoom.copyWith(
        status: RoomStatus.closed,
        closedAt: now,
      );
      _localRooms[roomId] = updated;
      _emitRoomUpdate(roomId);
    }
    _localPlayers[roomId]?.clear();
    _emitPlayersUpdate(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return;

    final room = await getRoom(roomId);
    if (room == null) return;

    final players = await getRoomPlayers(roomId);
    final isHost = players.any((p) => p.userId == userId && p.isHost);
    final otherPlayers = players.where((p) => p.userId != userId).toList();

    _unsubscribeFromRoomRealtime(roomId);
    final game = _localGames.values
        .where((g) => g.roomId == roomId)
        .firstOrNull;
    if (game != null) _unsubscribeFromGameRealtime(game.id);

    if (isHost) {
      // If room was in waiting mode or no other players remain -> Close room authoritatively
      if (room.isWaiting || otherPlayers.isEmpty) {
        await closeRoom(roomId);
        if (_isOnline) {
          try {
            await _supabaseClient!
                .from('room_players')
                .delete()
                .eq('room_id', roomId)
                .eq('user_id', userId);
          } catch (_) {}
        }
        _localPlayers[roomId]?.removeWhere((p) => p.userId == userId);
        _emitPlayersUpdate(roomId);
        return;
      } else {
        // Host exits an active game with other participants -> transfer host role
        final newHost = otherPlayers.first;
        final client = _supabaseClient;
        if (_isOnline && client != null) {
          try {
            await client
                .from('rooms')
                .update({'host_id': newHost.userId})
                .eq('id', roomId);

            await client
                .from('room_players')
                .update({'is_host': true})
                .eq('room_id', roomId)
                .eq('user_id', newHost.userId);

            await client
                .from('room_players')
                .delete()
                .eq('room_id', roomId)
                .eq('user_id', userId);
          } catch (e, st) {
            ErrorLogger.logUnhandled(
              e,
              st,
              source: 'leaveRoom_hostTransfer_supabase',
            );
          }
        }

        final updatedRoom = room.copyWith(hostId: newHost.userId);
        _localRooms[roomId] = updatedRoom;
        final updatedPlayers = otherPlayers.map((p) {
          if (p.userId == newHost.userId) {
            return p.copyWith(isHost: true);
          }
          return p;
        }).toList();
        _localPlayers[roomId] = updatedPlayers;
        _emitRoomUpdate(roomId);
        _emitPlayersUpdate(roomId);
        return;
      }
    }

    // Non-host player leaves
    if (_isOnline) {
      try {
        await _supabaseClient!
            .from('room_players')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', userId);
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'leaveRoom_player_supabase');
      }
    }

    _localPlayers[roomId]?.removeWhere((p) => p.userId == userId);
    _emitPlayersUpdate(roomId);
  }

  void _subscribeToRoomRealtime(String roomId) {
    if (!_isOnline || _supabaseClient == null) return;
    if (_roomChannels.containsKey(roomId)) return;

    try {
      final channel = _supabaseClient.channel('room_lobby:$roomId');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: roomId,
        ),
        callback: (payload) async {
          try {
            final refreshedRoom = await getRoom(roomId);
            if (refreshedRoom != null) {
              _localRooms[roomId] = refreshedRoom;
              _emitRoomUpdate(roomId);

              if (refreshedRoom.status == RoomStatus.completed) {
                final activeGame = await getGameForRoom(roomId);
                _freezeGameCompleted(
                  activeGame.id,
                  winnerUserId: activeGame.winnerUserId,
                );
                await getGamePlayers(activeGame.id);
              }
            }
          } catch (e, st) {
            ErrorLogger.logUnhandled(e, st, source: 'realtime_room_change');
          }
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) async {
          try {
            final refreshedPlayers = await getRoomPlayers(roomId);
            _localPlayers[roomId] = refreshedPlayers;
            _emitPlayersUpdate(roomId);
          } catch (e, st) {
            ErrorLogger.logUnhandled(e, st, source: 'realtime_players_change');
          }
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_match_history',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) async {
          try {
            _emitRoomHistoryUpdate(roomId);
          } catch (e, st) {
            ErrorLogger.logUnhandled(e, st, source: 'realtime_history_change');
          }
        },
      );

      channel.subscribe();
      _roomChannels[roomId] = channel;
    } catch (e, st) {
      ErrorLogger.logUnhandled(e, st, source: 'subscribeToRoomRealtime');
    }
  }

  void _unsubscribeFromRoomRealtime(String roomId) {
    final channel = _roomChannels.remove(roomId);
    if (channel != null && _supabaseClient != null) {
      try {
        _supabaseClient.removeChannel(channel);
      } catch (_) {}
    }
  }

  @override
  Stream<Room> watchRoom(String roomId) {
    _subscribeToRoomRealtime(roomId);

    final controller = _roomControllers.putIfAbsent(
      roomId,
      () => StreamController<Room>.broadcast(),
    );

    // Initial emission
    getRoom(roomId).then((room) {
      if (room != null && !controller.isClosed) {
        _localRooms[roomId] = room;
        controller.add(room);
      }
    });

    return controller.stream;
  }

  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId) {
    _subscribeToRoomRealtime(roomId);

    final controller = _playersControllers.putIfAbsent(
      roomId,
      () => StreamController<List<RoomPlayer>>.broadcast(),
    );

    // Initial emission
    getRoomPlayers(roomId).then((players) {
      if (!controller.isClosed) {
        _localPlayers[roomId] = players;
        controller.add(players);
      }
    });

    return controller.stream;
  }

  void _emitRoomUpdate(String roomId) {
    final room = _localRooms[roomId];
    final controller = _roomControllers[roomId];
    if (room != null && controller != null && !controller.isClosed) {
      controller.add(room);
    }
  }

  void _emitPlayersUpdate(String roomId) {
    final players = _localPlayers[roomId];
    final controller = _playersControllers[roomId];
    if (players != null && controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(players));
    }
  }

  void _freezeGameCompleted(String gameId, {String? winnerUserId}) {
    final game = _localGames[gameId];
    if (game != null) {
      final updatedGame = game.copyWith(
        status: MultiplayerGameStatus.completed,
        winnerUserId: winnerUserId ?? game.winnerUserId,
        updatedAt: DateTime.now(),
      );
      _localGames[gameId] = updatedGame;
      _emitGameUpdate(gameId);

      final room = _localRooms[game.roomId];
      if (room != null && room.status != RoomStatus.completed) {
        _localRooms[game.roomId] = room.copyWith(status: RoomStatus.completed);
        _emitRoomUpdate(game.roomId);
      }
    }
    final qm = _localQuickMatches.values
        .where((m) => m.gameId == gameId)
        .firstOrNull;
    if (qm != null) {
      final updatedQm = qm.copyWith(status: QuickMatchStatus.completed);
      _localQuickMatches[qm.id] = updatedQm;
      _emitQuickMatchUpdate(qm.id, updatedQm);
      _localQueue.removeWhere((k, v) => v.matchId == qm.id);
    }
    _emitGamePlayersUpdate(gameId);
  }

  // --- GAMEPLAY SYNCHRONIZATION IMPLEMENTATION ---

  @override
  Future<MultiplayerGame> getGameForRoom(String roomId) async {
    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('games')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          return MultiplayerGame.fromJson(res);
        }
      } catch (_) {}
    }

    // In-memory fallback
    var game = _localGames.values.where((g) => g.roomId == roomId).firstOrNull;
    if (game == null) {
      final room = await getRoom(roomId);
      final prepSec = room?.prepTimeSeconds ?? 45;
      final gameId = const Uuid().v4();

      game = MultiplayerGame(
        id: gameId,
        roomId: roomId,
        status: MultiplayerGameStatus.preparing,
        prepDeadline: DateTime.now().add(Duration(seconds: prepSec)),
        roundNumber: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _localGames[gameId] = game;

      // Seed player states from room players
      final roomPlayers = await getRoomPlayers(roomId);
      final states = roomPlayers.map((rp) {
        return MultiplayerPlayerState(
          userId: rp.userId,
          displayName: rp.displayName,
          avatarColorHex: rp.avatarColorHex,
          isHost: rp.isHost,
          seatIndex: rp.seatIndex,
          isBoardConfirmed: false,
          linesClaimed: 0,
        );
      }).toList();

      _localGamePlayers[gameId] = states;
      _emitGameUpdate(gameId);
      _emitGamePlayersUpdate(gameId);
    }

    return game;
  }

  void _subscribeToGameRealtime(String gameId) {
    if (!_isOnline || _supabaseClient == null) return;
    if (_gameChannels.containsKey(gameId)) return;

    try {
      final channel = _supabaseClient.channel('game_channel:$gameId');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'games',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: gameId,
        ),
        callback: (payload) async {
          try {
            final res = await _supabaseClient
                .from('games')
                .select()
                .eq('id', gameId)
                .maybeSingle();
            if (res != null) {
              final updatedGame = MultiplayerGame.fromJson(res);
              _localGames[gameId] = updatedGame;
              _emitGameUpdate(gameId);

              // Keep room in sync
              final room = _localRooms[updatedGame.roomId];
              if (updatedGame.status == MultiplayerGameStatus.completed ||
                  updatedGame.winnerUserId != null) {
                if (room != null && room.status != RoomStatus.completed) {
                  _localRooms[updatedGame.roomId] = room.copyWith(
                    status: RoomStatus.completed,
                  );
                  _emitRoomUpdate(updatedGame.roomId);
                }
                // Refresh all players immediately so final scores, lines, and winner flags are current
                await getGamePlayers(gameId);
              } else if (updatedGame.status == MultiplayerGameStatus.inProgress) {
                if (room != null && room.status != RoomStatus.inProgress) {
                  _localRooms[updatedGame.roomId] = room.copyWith(
                    status: RoomStatus.inProgress,
                  );
                  _emitRoomUpdate(updatedGame.roomId);
                }
              }
            }
          } catch (e, st) {
            ErrorLogger.logUnhandled(e, st, source: 'realtime_game_change');
          }
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_player_states',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'game_id',
          value: gameId,
        ),
        callback: (payload) async {
          try {
            final players = await getGamePlayers(gameId);
            final winningPlayer = players
                .where((p) => p.isWinner || p.linesClaimed >= 5)
                .firstOrNull;
            if (winningPlayer != null) {
              _freezeGameCompleted(gameId, winnerUserId: winningPlayer.userId);
            }
          } catch (e, st) {
            ErrorLogger.logUnhandled(
              e,
              st,
              source: 'realtime_game_player_states_change',
            );
          }
        },
      );

      channel.subscribe();
      _gameChannels[gameId] = channel;
    } catch (e, st) {
      ErrorLogger.logUnhandled(e, st, source: 'subscribeToGameRealtime');
    }
  }

  void _unsubscribeFromGameRealtime(String gameId) {
    final channel = _gameChannels.remove(gameId);
    if (channel != null && _supabaseClient != null) {
      try {
        _supabaseClient.removeChannel(channel);
      } catch (_) {}
    }
  }

  @override
  Future<List<MultiplayerPlayerState>> getGamePlayers(String gameId) async {
    if (_isOnline && _supabaseClient != null) {
      try {
        String? roomId = _localGames[gameId]?.roomId;
        if (roomId == null) {
          final gameRes = await _supabaseClient
              .from('games')
              .select('room_id')
              .eq('id', gameId)
              .maybeSingle();
          roomId = gameRes?['room_id'] as String?;
        }

        if (roomId != null) {
          // 1. Fetch authoritative room membership
          final roomPlayersRes = await _supabaseClient
              .from('room_players')
              .select('*, profiles(display_name, avatar_color_hex)')
              .eq('room_id', roomId)
              .order('seat_index');

          // 2. Fetch all player states for this game round
          final statesRes = await _supabaseClient
              .from('game_player_states')
              .select()
              .eq('game_id', gameId);

          final List<dynamic> statesList = statesRes as List;
          final roomPlayers = (roomPlayersRes as List)
              .map((item) => RoomPlayer.fromMap(item as Map<String, dynamic>))
              .toList();

          final List<MultiplayerPlayerState> combined = roomPlayers.map((rp) {
            final stateMap = statesList
                .where((s) => s['user_id'] == rp.userId)
                .firstOrNull;

            List<int> board = [];
            if (stateMap != null && stateMap['board_numbers'] != null) {
              board = (stateMap['board_numbers'] as List)
                  .map((n) => (n as num).toInt())
                  .toList();
            }

            List<String> claimedLines = [];
            if (stateMap != null &&
                (stateMap['claimed_line_types'] != null ||
                    stateMap['completed_lines'] != null)) {
              final raw =
                  stateMap['claimed_line_types'] ?? stateMap['completed_lines'];
              if (raw is List) {
                claimedLines = raw.map((e) => e.toString()).toList();
              }
            }

            final isConfirmed = stateMap != null &&
                (stateMap['board_confirmed'] == true ||
                    stateMap['is_board_confirmed'] == true);

            final linesCount = stateMap != null
                ? ((stateMap['lines_claimed'] as num?)?.toInt() ??
                    (stateMap['lines_claimed_count'] as num?)?.toInt() ??
                    0)
                : 0;

            final isWinner = stateMap != null && stateMap['is_winner'] == true;
            final isForfeited =
                stateMap != null && stateMap['is_forfeited'] == true;

            return MultiplayerPlayerState(
              userId: rp.userId,
              displayName: rp.displayName,
              avatarColorHex: rp.avatarColorHex,
              isHost: rp.isHost,
              seatIndex: rp.seatIndex,
              boardNumbers: board,
              isBoardConfirmed: isConfirmed,
              linesClaimed: linesCount,
              claimedLineTypes: claimedLines,
              isWinner: isWinner,
              isForfeited: isForfeited,
            );
          }).toList();

          // Preserve historical participants whose active room membership was removed (e.g. forfeited players)
          final presentUserIds = roomPlayers.map((rp) => rp.userId).toSet();
          for (final rawState in statesList) {
            final uid = rawState['user_id'] as String?;
            if (uid != null && !presentUserIds.contains(uid)) {
              String dName = 'Player';
              String avatarHex = '#FC695C';
              try {
                final pRes = await _supabaseClient
                    .from('profiles')
                    .select('display_name, avatar_color_hex')
                    .eq('id', uid)
                    .maybeSingle();
                if (pRes != null) {
                  dName = pRes['display_name'] as String? ?? 'Player';
                  avatarHex = pRes['avatar_color_hex'] as String? ?? '#FC695C';
                }
              } catch (_) {}

              List<int> board = [];
              if (rawState['board_numbers'] != null) {
                board = (rawState['board_numbers'] as List)
                    .map((n) => (n as num).toInt())
                    .toList();
              }

              List<String> claimedLines = [];
              final raw =
                  rawState['claimed_line_types'] ?? rawState['completed_lines'];
              if (raw is List) {
                claimedLines = raw.map((e) => e.toString()).toList();
              }

              final linesCount =
                  (rawState['lines_claimed'] as num?)?.toInt() ??
                  (rawState['lines_claimed_count'] as num?)?.toInt() ??
                  0;

              combined.add(
                MultiplayerPlayerState(
                  userId: uid,
                  displayName: dName,
                  avatarColorHex: avatarHex,
                  isHost: false,
                  seatIndex: 99,
                  boardNumbers: board,
                  isBoardConfirmed: true,
                  linesClaimed: linesCount,
                  claimedLineTypes: claimedLines,
                  isWinner: rawState['is_winner'] == true,
                  isForfeited: rawState['is_forfeited'] == true,
                ),
              );
            }
          }

          _localGamePlayers[gameId] = combined;
          _emitGamePlayersUpdate(gameId);
          return combined;
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getGamePlayers_supabase');
      }
    }

    return List<MultiplayerPlayerState>.from(_localGamePlayers[gameId] ?? []);
  }

  @override
  Stream<MultiplayerGame> watchGame(String gameId) {
    _subscribeToGameRealtime(gameId);

    final controller = _gameControllers.putIfAbsent(
      gameId,
      () => StreamController<MultiplayerGame>.broadcast(),
    );

    final local = _localGames[gameId];
    if (local != null && !controller.isClosed) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(local);
      });
    }

    return controller.stream;
  }

  @override
  Stream<List<MultiplayerPlayerState>> watchGamePlayers(String gameId) {
    _subscribeToGameRealtime(gameId);

    final controller = _gamePlayersControllers.putIfAbsent(
      gameId,
      () => StreamController<List<MultiplayerPlayerState>>.broadcast(),
    );

    final local = _localGamePlayers[gameId];
    if (local != null && !controller.isClosed) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(List.unmodifiable(local));
      });
    }

    // Always fetch authoritative snapshot asynchronously to guarantee synchronization
    getGamePlayers(gameId).then((players) {
      if (!controller.isClosed) controller.add(List.unmodifiable(players));
    }).catchError((_) {});

    return controller.stream;
  }

  @override
  Future<void> submitBoard({
    required String gameId,
    required List<int> numbers,
  }) async {
    if (numbers.length != 25) {
      throw ArgumentError('Board must contain exactly 25 numbers');
    }
    final unique = numbers.toSet();
    if (unique.length != 25 || numbers.any((n) => n < 1 || n > 25)) {
      throw ArgumentError(
        'Board must contain numbers 1-25 exactly once without duplicates',
      );
    }

    final userId = _authRepository.currentUserId ?? 'current_user';

    // Optimistic local update
    final players = _localGamePlayers[gameId];
    if (players != null) {
      final index = players.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        players[index] = players[index].copyWith(
          boardNumbers: List.unmodifiable(numbers),
          isBoardConfirmed: true,
        );
      } else {
        players.add(
          MultiplayerPlayerState(
            userId: userId,
            displayName: 'Player',
            avatarColorHex: '#FF6B5E',
            boardNumbers: List.unmodifiable(numbers),
            isBoardConfirmed: true,
          ),
        );
      }
      _emitGamePlayersUpdate(gameId);
    }

    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_submit_board',
          params: {'p_game_id': gameId, 'p_board': numbers},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'submitBoard_supabase');
      }
    }

    // Condition A: Check if all players confirmed
    final currentPlayers = _localGamePlayers[gameId];
    if (currentPlayers != null) {
      final allConfirmed = currentPlayers.every((p) => p.isBoardConfirmed);
      if (allConfirmed && currentPlayers.length >= 2) {
        final game = _localGames[gameId];
        if (game != null) {
          final room = _localRooms[game.roomId];
          final turnSec = room?.turnTimeSeconds ?? 20;
          final hostId = room?.hostId ?? currentPlayers.first.userId;

          _localGames[gameId] = game.copyWith(
            status: MultiplayerGameStatus.inProgress,
            currentTurnUserId: hostId,
            turnDeadline: DateTime.now().add(Duration(seconds: turnSec)),
            updatedAt: DateTime.now(),
          );
          _emitGameUpdate(gameId);

          if (room != null) {
            _localRooms[game.roomId] = room.copyWith(
              status: RoomStatus.inProgress,
            );
            _emitRoomUpdate(game.roomId);
          }
        }
      }
    }
  }

  @override
  Future<List<int>?> getPlayerBoard({
    required String gameId,
    required String userId,
  }) async {
    // 1. Check local game players cache
    final players = _localGamePlayers[gameId];
    final player = players?.where((p) => p.userId == userId).firstOrNull;
    if (player != null && player.boardNumbers.length == 25) {
      return player.boardNumbers;
    }

    // 2. Query Supabase game_player_states for current player's private board
    if (_isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient
            .from('game_player_states')
            .select('board_numbers')
            .eq('game_id', gameId)
            .eq('user_id', userId)
            .maybeSingle();

        if (res != null && res['board_numbers'] != null) {
          final list = (res['board_numbers'] as List)
              .map((e) => (e as num).toInt())
              .toList();
          if (list.length == 25) return list;
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getPlayerBoard_supabase');
      }
    }
    return null;
  }

  @override
  Future<void> callNumber({required String gameId, required int number}) async {
    final cachedGame = _localGames[gameId];
    if (cachedGame != null &&
        (cachedGame.status == MultiplayerGameStatus.completed ||
            cachedGame.winnerUserId != null)) {
      throw StateError('MATCH_ALREADY_COMPLETED');
    }

    if (_isOnline && _supabaseClient != null) {
      try {
        await _supabaseClient.rpc(
          'rpc_call_number',
          params: {'p_game_id': gameId, 'p_number': number},
        );
        return;
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('MATCH_ALREADY_COMPLETED') ||
            errStr.contains('already completed')) {
          _freezeGameCompleted(gameId);
          throw StateError('MATCH_ALREADY_COMPLETED');
        }
        rethrow;
      }
    }

    // In-memory fallback
    final game = _localGames[gameId];
    if (game == null) throw StateError('Game not found');
    if (game.status == MultiplayerGameStatus.completed ||
        game.winnerUserId != null) {
      throw StateError('MATCH_ALREADY_COMPLETED');
    }
    if (game.status != MultiplayerGameStatus.inProgress) {
      throw StateError('Game is not in progress');
    }
    if (game.isNumberCalled(number)) {
      throw StateError('Number $number has already been called');
    }

    final players = _localGamePlayers[gameId] ?? [];
    if (players.isEmpty) return;

    // Filter candidate active players: strictly non-forfeited!
    final activePlayers = players.where((p) => !p.isForfeited).toList();
    final candidatePlayers = activePlayers.isNotEmpty ? activePlayers : players;

    // Advance turn to next player in seatIndex order
    final currentIndex = candidatePlayers.indexWhere(
      (p) => p.userId == game.currentTurnUserId,
    );
    final nextIndex = (currentIndex + 1) % candidatePlayers.length;
    final nextUserId = candidatePlayers[nextIndex].userId;

    final room = _localRooms[game.roomId];
    final turnSec = room?.turnTimeSeconds ?? 20;

    final updatedCalled = [...game.calledNumbers, number];
    _localGames[gameId] = game.copyWith(
      calledNumbers: updatedCalled,
      currentTurnUserId: nextUserId,
      turnDeadline: DateTime.now().add(Duration(seconds: turnSec)),
      updatedAt: DateTime.now(),
    );

    _emitGameUpdate(gameId);
  }

  @override
  Future<bool> claimLine({
    required String gameId,
    required String lineType,
    required List<int> numbers,
  }) async {
    final userId = _authRepository.currentUserId ?? 'current_user';

    // Immediate authoritative freeze check: Reject if game is already completed or has a winner
    final cachedGame = _localGames[gameId];
    if (cachedGame != null &&
        (cachedGame.status == MultiplayerGameStatus.completed ||
            cachedGame.winnerUserId != null)) {
      throw StateError('MATCH_ALREADY_COMPLETED');
    }

    if (_isOnline && _supabaseClient != null) {
      try {
        final result = await _supabaseClient.rpc(
          'rpc_claim_line',
          params: {
            'p_game_id': gameId,
            'p_line_type': lineType,
            'p_numbers': numbers,
          },
        );
        final hasWon = result as bool? ?? false;
        if (hasWon) {
          _freezeGameCompleted(gameId, winnerUserId: userId);
        }
        return hasWon;
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('MATCH_ALREADY_COMPLETED') ||
            errStr.contains('already completed')) {
          _freezeGameCompleted(gameId);
          throw StateError('MATCH_ALREADY_COMPLETED');
        }
        rethrow;
      }
    }

    // In-memory fallback
    final game = _localGames[gameId];
    final players = _localGamePlayers[gameId];
    if (game == null || players == null) throw StateError('Game not found');
    if (game.status == MultiplayerGameStatus.completed ||
        game.winnerUserId != null) {
      throw StateError('MATCH_ALREADY_COMPLETED');
    }
    if (game.status != MultiplayerGameStatus.inProgress) {
      throw StateError('Game is not in progress');
    }

    final index = players.indexWhere((p) => p.userId == userId);
    if (index == -1) throw StateError('Player not in game');

    final p = players[index];
    final resolvedLine = WinningLine.findLine(lineType);
    final normalizedId = resolvedLine?.id ?? lineType.toLowerCase().trim();

    final alreadyClaimed = p.claimedLineTypes.any((c) {
      final match = WinningLine.findLine(c);
      return (match != null && resolvedLine != null && match.id == resolvedLine.id) ||
          c.toLowerCase().trim() == normalizedId ||
          c == lineType;
    });
    if (alreadyClaimed) return false;

    if (p.linesClaimed >= 5) {
      return false;
    }

    final newLines = p.linesClaimed + 1;
    final isWinner = newLines >= 5;

    players[index] = p.copyWith(
      linesClaimed: newLines,
      claimedLineTypes: [...p.claimedLineTypes, lineType],
      isWinner: isWinner,
    );

    if (isWinner) {
      _freezeGameCompleted(gameId, winnerUserId: userId);
    } else {
      _emitGamePlayersUpdate(gameId);
    }

    return isWinner;
  }

  @override
  Future<void> extendPrepTime({
    required String gameId,
    int extensionSeconds = 30,
  }) async {
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_extend_prep_timer',
          params: {'p_game_id': gameId, 'p_seconds': extensionSeconds},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'extendPrepTime_supabase');
      }
    }

    final game = _localGames[gameId];
    if (game != null) {
      _localGames[gameId] = game.copyWith(
        prepDeadline: game.prepDeadline.add(
          Duration(seconds: extensionSeconds),
        ),
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);
    }
  }

  @override
  Future<void> handlePrepTimeout({
    required String gameId,
    bool autoFill = true,
  }) async {
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_handle_prep_timeout',
          params: {'p_game_id': gameId, 'p_auto_fill': autoFill},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'handlePrepTimeout_supabase');
      }
    }

    final game = _localGames[gameId];
    if (game == null) return;
    if (game.status == MultiplayerGameStatus.inProgress) return;

    final players = _localGamePlayers[gameId] ?? [];
    if (autoFill) {
      for (int i = 0; i < players.length; i++) {
        if (!players[i].isBoardConfirmed) {
          players[i] = players[i].copyWith(
            isBoardConfirmed: true,
            boardNumbers: BingoBoard.quickShuffle().toList(),
          );
        }
      }
      _localGamePlayers[gameId] = players;
      _emitGamePlayersUpdate(gameId);
    }

    final confirmed = players.where((p) => p.isBoardConfirmed).length;
    if (confirmed >= 2) {
      final room = _localRooms[game.roomId];
      final turnSec = room?.turnTimeSeconds ?? 20;
      final hostId = room?.hostId ?? players.first.userId;

      _localGames[gameId] = game.copyWith(
        status: MultiplayerGameStatus.inProgress,
        currentTurnUserId: hostId,
        turnDeadline: DateTime.now().add(Duration(seconds: turnSec)),
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);

      if (room != null) {
        _localRooms[game.roomId] = room.copyWith(status: RoomStatus.inProgress);
        _emitRoomUpdate(game.roomId);
      }
    } else {
      final room = _localRooms[game.roomId];
      if (room != null) {
        _localRooms[game.roomId] = room.copyWith(status: RoomStatus.waiting);
        _emitRoomUpdate(game.roomId);
      }
      _localGames[gameId] = game.copyWith(
        status: MultiplayerGameStatus.cancelled,
      );
      _emitGameUpdate(gameId);
    }
  }

  @override
  Future<Map<String, dynamic>> handleTurnTimeout({
    required String gameId,
    String? currentTurnUserId,
  }) async {
    final cachedGame = _localGames[gameId];
    if (cachedGame != null &&
        (cachedGame.status == MultiplayerGameStatus.completed ||
            cachedGame.winnerUserId != null)) {
      return {
        'success': false,
        'reason': 'MATCH_ALREADY_COMPLETED',
        'error': 'MATCH_ALREADY_COMPLETED',
      };
    }

    if (_isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_handle_turn_timeout',
          params: {
            'p_game_id': gameId,
            'p_turn_user_id': currentTurnUserId,
          },
        );
        if (res is Map<String, dynamic>) {
          if (res['reason'] == 'MATCH_ALREADY_COMPLETED' ||
              res['error'] == 'MATCH_ALREADY_COMPLETED') {
            _freezeGameCompleted(gameId);
          }
          return res;
        }
      } catch (e, st) {
        final errStr = e.toString();
        if (errStr.contains('MATCH_ALREADY_COMPLETED') ||
            errStr.contains('already completed')) {
          _freezeGameCompleted(gameId);
          return {
            'success': false,
            'reason': 'MATCH_ALREADY_COMPLETED',
            'error': 'MATCH_ALREADY_COMPLETED',
          };
        }
        ErrorLogger.logUnhandled(e, st, source: 'handleTurnTimeout_supabase');
      }
    }

    // Local in-memory fallback
    final game = _localGames[gameId];
    if (game == null) {
      return {'success': false, 'reason': 'game_not_found'};
    }
    if (game.status == MultiplayerGameStatus.completed ||
        game.winnerUserId != null) {
      return {
        'success': false,
        'reason': 'MATCH_ALREADY_COMPLETED',
        'error': 'MATCH_ALREADY_COMPLETED',
      };
    }
    if (game.status != MultiplayerGameStatus.inProgress) {
      return {'success': false, 'reason': 'game_not_in_progress'};
    }

    if (currentTurnUserId != null &&
        game.currentTurnUserId != currentTurnUserId) {
      return {'success': true, 'reason': 'turn_already_advanced'};
    }

    final players = _localGamePlayers[gameId] ?? [];
    if (players.isEmpty) {
      return {'success': false, 'reason': 'no_players'};
    }

    final currentTurnUser = game.currentTurnUserId ?? players.first.userId;
    final currentPlayer =
        players.where((p) => p.userId == currentTurnUser).firstOrNull;

    // Filter candidate uncalled numbers from player's board (or 1..25)
    List<int> candidateNumbers = [];
    if (currentPlayer != null && currentPlayer.boardNumbers.length == 25) {
      candidateNumbers = currentPlayer.boardNumbers
          .where((n) => !game.calledNumbers.contains(n))
          .toList();
    }
    if (candidateNumbers.isEmpty) {
      candidateNumbers = List.generate(25, (i) => i + 1)
          .where((n) => !game.calledNumbers.contains(n))
          .toList();
    }

    if (candidateNumbers.isEmpty) {
      return {'success': false, 'reason': 'all_numbers_called'};
    }

    // Pick random uncalled number
    candidateNumbers.shuffle(Random());
    final autoNumber = candidateNumbers.first;

    // Advance turn in seat order strictly among active non-forfeited players!
    final activePlayers = players.where((p) => !p.isForfeited).toList();
    final candidatePlayers = activePlayers.isNotEmpty ? activePlayers : players;

    final sortedPlayers = List<MultiplayerPlayerState>.from(candidatePlayers)
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

    final currentIndex =
        sortedPlayers.indexWhere((p) => p.userId == currentTurnUser);
    final nextIndex = (currentIndex + 1) % sortedPlayers.length;
    final nextTurnUser = sortedPlayers[nextIndex].userId;

    final room = _localRooms[game.roomId];
    final turnSec = room?.turnTimeSeconds ?? 20;

    final updatedGame = game.copyWith(
      calledNumbers: [...game.calledNumbers, autoNumber],
      currentTurnUserId: nextTurnUser,
      turnDeadline: DateTime.now().add(Duration(seconds: turnSec)),
      updatedAt: DateTime.now(),
    );

    _localGames[gameId] = updatedGame;
    _emitGameUpdate(gameId);

    return {
      'success': true,
      'auto_number': autoNumber,
      'timed_out_user_id': currentTurnUser,
      'next_turn_user_id': nextTurnUser,
    };
  }

  @override
  Future<void> finishRound({
    required String gameId,
    required String roomId,
    required String? winnerId,
    required String winnerName,
    required int totalCalls,
    required List<Map<String, dynamic>> playerOutcomes,
    int? roundNumber,
  }) async {
    final game = _localGames[gameId];
    final round =
        roundNumber ??
        game?.roundNumber ??
        ((_localRoomHistory[roomId]?.length ?? 0) + 1);

    final existingHistory = _localRoomHistory[roomId] ?? [];
    // Idempotency check: Do not re-record or duplicate stats if this round was already recorded
    if (existingHistory.any((h) => h['game_id'] == gameId && h['round_number'] == round)) {
      return;
    }

    final historyRecord = <String, dynamic>{
      'id': Uuid().v4(),
      'game_id': gameId,
      'room_id': roomId,
      'round_number': round,
      'winner_id': winnerId,
      'winner_name': winnerName,
      'total_calls': totalCalls,
      'player_count': playerOutcomes.length,
      'player_outcomes': playerOutcomes,
      'finished_at': DateTime.now().toIso8601String(),
    };

    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_finish_round',
          params: {
            'p_game_id': gameId,
            'p_room_id': roomId,
            'p_winner_id': winnerId,
            'p_winner_name': winnerName,
            'p_total_calls': totalCalls,
            'p_player_outcomes': playerOutcomes,
          },
        );
      } catch (_) {
        // Fall back to local store
      }
    }

    _localRoomHistory.putIfAbsent(roomId, () => []).add(historyRecord);
    _emitRoomHistoryUpdate(roomId);

    if (game != null) {
      _localGames[gameId] = game.copyWith(
        status: MultiplayerGameStatus.completed,
        winnerId: winnerId,
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRoomMatchHistory(String roomId) async {
    if (_isOnline) {
      try {
        final res = await _supabaseClient!
            .from('room_match_history')
            .select('*')
            .eq('room_id', roomId)
            .order('round_number', ascending: false);
        return List<Map<String, dynamic>>.from(res as List);
      } catch (_) {
        // Fall back to local store
      }
    }

    final list = _localRoomHistory[roomId] ?? [];
    final reversed = List<Map<String, dynamic>>.from(list);
    reversed.sort(
      (a, b) => (b['round_number'] as int? ?? 0).compareTo(
        a['round_number'] as int? ?? 0,
      ),
    );
    return reversed;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoomLeaderboard(String roomId) async {
    final history = await getRoomMatchHistory(roomId);
    final roomPlayers = await getRoomPlayers(roomId);
    final currentUid = _authRepository.currentUserId ?? '';

    // Chronological order for streak calculation
    final chronological = List<Map<String, dynamic>>.from(history)
      ..sort(
        (a, b) => (a['round_number'] as int? ?? 0).compareTo(
          b['round_number'] as int? ?? 0,
        ),
      );

    final Map<String, Map<String, dynamic>> playerStats = {};

    // Seed from current participants
    for (final p in roomPlayers) {
      playerStats[p.userId] = {
        'user_id': p.userId,
        'display_name': p.displayName,
        'avatar_color_hex': p.avatarColorHex,
        'is_host': p.isHost,
        'is_you': p.userId == currentUid,
        'rounds_played': 0,
        'rounds_won': 0,
        'draws': 0,
        'losses': 0,
        'win_rate': 0.0,
        'current_streak': 0,
        'best_streak': 0,
        'last_result': '',
        'won_rounds': <int>[],
      };
    }

    for (final round in chronological) {
      final roundNum = (round['round_number'] as num?)?.toInt() ?? 1;
      final winnerId =
          (round['winner_id'] ?? round['winner_user_id']) as String?;
      final winnerName =
          (round['winner_name'] ?? round['winner_display_name']) as String? ??
          'Winner';
      final rawOutcomes =
          (round['player_outcomes'] ?? round['outcomes']) as List<dynamic>?;

      List<dynamic> outcomes =
          (rawOutcomes != null && rawOutcomes.isNotEmpty) ? rawOutcomes : [];

      // Fallback: If outcomes is empty, synthesize outcomes from roomPlayers & winnerId
      // so statistics never show 0 rounds or 0 wins when match records exist!
      if (outcomes.isEmpty && roomPlayers.isNotEmpty) {
        outcomes = roomPlayers.map((rp) => {
          'user_id': rp.userId,
          'display_name': rp.displayName,
          'avatar_color_hex': rp.avatarColorHex,
          'is_host': rp.isHost,
          'is_winner': winnerId != null ? rp.userId == winnerId : false,
          'lines_claimed_count':
              (winnerId != null && rp.userId == winnerId) ? 5 : 0,
        }).toList();
      }

      for (final raw in outcomes) {
        final outcome = raw as Map<String, dynamic>;
        final uid = (outcome['user_id'] ?? outcome['id']) as String? ?? '';
        final linesClaimed =
            (outcome['lines_claimed_count'] as num?)?.toInt() ??
            (outcome['lines_claimed'] as num?)?.toInt() ??
            0;
        final isWinner =
            (winnerId != null && winnerId == uid) ||
            (outcome['is_winner'] as bool? ?? false) ||
            linesClaimed >= 5;

        final stat = playerStats.putIfAbsent(
          uid,
          () => {
            'user_id': uid,
            'display_name':
                (outcome['display_name'] ?? outcome['name']) as String? ??
                (isWinner ? winnerName : 'Player'),
            'avatar_color_hex':
                outcome['avatar_color_hex'] as String? ?? '#FC695C',
            'is_host': outcome['is_host'] as bool? ?? false,
            'is_you': uid == currentUid,
            'rounds_played': 0,
            'rounds_won': 0,
            'draws': 0,
            'losses': 0,
            'win_rate': 0.0,
            'current_streak': 0,
            'best_streak': 0,
            'last_result': '',
            'won_rounds': <int>[],
          },
        );

        stat['rounds_played'] = (stat['rounds_played'] as int) + 1;
        if (isWinner) {
          stat['rounds_won'] = (stat['rounds_won'] as int) + 1;
          (stat['won_rounds'] as List<int>).add(roundNum);
          final currStreak = (stat['current_streak'] as int) + 1;
          stat['current_streak'] = currStreak;
          final bestStreak = stat['best_streak'] as int;
          if (currStreak > bestStreak) stat['best_streak'] = currStreak;
          stat['last_result'] =
              'Winner R${roundNum.toString().padLeft(2, '0')} ⭐';
        } else {
          stat['losses'] = (stat['losses'] as int) + 1;
          stat['current_streak'] = 0;
          stat['last_result'] =
              'Defeat (R${roundNum.toString().padLeft(2, '0')})';
        }

        final played = stat['rounds_played'] as int;
        final won = stat['rounds_won'] as int;
        stat['win_rate'] = played > 0 ? ((won / played) * 100.0) : 0.0;
      }
    }

    final list = playerStats.values.toList();

    // Sort by wins desc, win rate desc, best streak desc
    list.sort((a, b) {
      final winComp = (b['rounds_won'] as int).compareTo(
        a['rounds_won'] as int,
      );
      if (winComp != 0) return winComp;
      final rateComp = (b['win_rate'] as double).compareTo(
        a['win_rate'] as double,
      );
      if (rateComp != 0) return rateComp;
      return (b['best_streak'] as int).compareTo(a['best_streak'] as int);
    });

    // Assign rank with tie-breaker sharing
    int currentRank = 1;
    for (int i = 0; i < list.length; i++) {
      if (i > 0) {
        final prev = list[i - 1];
        final curr = list[i];
        final isTied =
            curr['rounds_won'] == prev['rounds_won'] &&
            (curr['win_rate'] as double).toStringAsFixed(1) ==
                (prev['win_rate'] as double).toStringAsFixed(1) &&
            curr['best_streak'] == prev['best_streak'];
        if (!isTied) {
          currentRank = i + 1;
        }
      }
      list[i]['rank'] = currentRank;
    }

    return list;
  }

  @override
  Future<void> startNextRound({
    required String gameId,
    required String roomId,
    required String hostId,
  }) async {
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc(
          'rpc_start_next_round',
          params: {
            'p_game_id': gameId,
            'p_room_id': roomId,
            'p_host_id': hostId,
          },
        );
      } catch (_) {
        // Fall back to local store
      }
    }

    final game = _localGames[gameId];
    final room = _localRooms[roomId];
    final prepSeconds = room?.prepTimeSeconds ?? 45;

    if (game != null) {
      final nextRound = game.roundNumber + 1;
      _localGames[gameId] = game.copyWith(
        roundNumber: nextRound,
        status: MultiplayerGameStatus.preparing,
        prepDeadline: DateTime.now().add(Duration(seconds: prepSeconds)),
        calledNumbers: const [],
        winnerId: null,
        currentTurnUserId: null,
        turnDeadline: null,
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);
    }

    if (room != null) {
      _localRooms[roomId] = room.copyWith(
        status: RoomStatus.preparing,
      );
      _emitRoomUpdate(roomId);
    }

    final players = _localGamePlayers[gameId];
    if (players != null) {
      _localGamePlayers[gameId] = players
          .map<MultiplayerPlayerState>(
            (p) => p.copyWith(
              isBoardConfirmed: false,
              linesClaimed: 0,
              claimedLineTypes: const [],
              boardNumbers: const [],
              isWinner: false,
            ),
          )
          .toList();
      _emitGamePlayersUpdate(gameId);
    }
  }

  @override
  Future<void> removeUnreadyPlayers({
    required String roomId,
    required String gameId,
  }) async {
    final gamePlayers = _localGamePlayers[gameId] ?? [];
    final readyCount = gamePlayers.where((p) => p.isBoardConfirmed).length;
    if (readyCount < 2) {
      throw StateError('Cannot remove players. At least 2 ready players are required.');
    }

    if (_isOnline && _supabaseClient != null) {
      try {
        await _supabaseClient.rpc(
          'rpc_remove_unready_players',
          params: {'p_room_id': roomId, 'p_game_id': gameId},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'removeUnreadyPlayers_supabase');
      }
    }

    // Filter in-memory participants
    final updatedGamePlayers = gamePlayers.where((p) => p.isBoardConfirmed).toList();
    _localGamePlayers[gameId] = updatedGamePlayers;
    _emitGamePlayersUpdate(gameId);

    final roomPlayers = _localPlayers[roomId] ?? [];
    final readyUserIds = updatedGamePlayers.map((p) => p.userId).toSet();
    final updatedRoomPlayers = roomPlayers.where((p) => readyUserIds.contains(p.userId)).toList();
    _localPlayers[roomId] = updatedRoomPlayers;
    _emitPlayersUpdate(roomId);

    // If all remaining players are confirmed (and >= 2), advance game to inProgress immediately
    if (updatedGamePlayers.length >= 2 && updatedGamePlayers.every((p) => p.isBoardConfirmed)) {
      final currentGame = _localGames[gameId];
      if (currentGame != null && currentGame.status == MultiplayerGameStatus.preparing) {
        final hostUserId = _localRooms[roomId]?.hostId ?? updatedGamePlayers.first.userId;
        _localGames[gameId] = currentGame.copyWith(
          status: MultiplayerGameStatus.inProgress,
          currentTurnUserId: hostUserId,
          turnDeadline: DateTime.now().add(const Duration(seconds: 20)),
        );
        _emitGameUpdate(gameId);

        final room = _localRooms[roomId];
        if (room != null) {
          _localRooms[roomId] = room.copyWith(status: RoomStatus.inProgress);
          _emitRoomUpdate(roomId);
        }
      }
    }
  }

  @override
  Future<void> returnToLobby({
    required String roomId,
    required String hostId,
  }) async {
    if (_isOnline && _supabaseClient != null) {
      try {
        await _supabaseClient.rpc(
          'rpc_return_to_lobby',
          params: {'p_room_id': roomId, 'p_host_id': hostId},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'returnToLobby_supabase');
      }
    }

    final room = _localRooms[roomId];
    if (room != null) {
      _localRooms[roomId] = room.copyWith(status: RoomStatus.waiting);
      _emitRoomUpdate(roomId);
    }
  }

  void _emitGameUpdate(String gameId) {
    final game = _localGames[gameId];
    final controller = _gameControllers[gameId];
    if (game != null && controller != null && !controller.isClosed) {
      controller.add(game);
    }
  }

  void _emitGamePlayersUpdate(String gameId) {
    final players = _localGamePlayers[gameId];
    final controller = _gamePlayersControllers[gameId];
    if (players != null && controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(players));
    }
  }

  void _emitRoomHistoryUpdate(String roomId) {
    getRoomMatchHistory(roomId).then((history) {
      final controller = _historyControllers[roomId];
      if (controller != null && !controller.isClosed) {
        controller.add(List.unmodifiable(history));
      }
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRoomMatchHistory(String roomId) {
    _subscribeToRoomRealtime(roomId);

    final controller = _historyControllers.putIfAbsent(
      roomId,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );

    getRoomMatchHistory(roomId).then((history) {
      if (!controller.isClosed) controller.add(history);
    });

    return controller.stream;
  }

  final List<String> _inMemoryRecentRoomCodes = [];

  void _saveRecentRoom(String code) {
    _inMemoryRecentRoomCodes.remove(code);
    _inMemoryRecentRoomCodes.insert(0, code);
    if (_inMemoryRecentRoomCodes.length > 10) {
      _inMemoryRecentRoomCodes.removeRange(10, _inMemoryRecentRoomCodes.length);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentRooms({int limit = 5}) async {
    final userId = _authRepository.currentUserId;
    if (_isOnline && userId != null) {
      try {
        final res = await _supabaseClient!.rpc(
          'rpc_get_user_recent_rooms',
          params: {'p_limit': limit},
        );
        if (res is List && res.isNotEmpty) {
          return List<Map<String, dynamic>>.from(
            res.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getRecentRooms_supabase');
      }
    }

    // Local / Offline fallback:
    final List<Map<String, dynamic>> results = [];
    for (final code in _inMemoryRecentRoomCodes.take(limit)) {
      final local =
          _localRooms.values.where((r) => r.code == code).firstOrNull;
      if (local != null) {
        final count = (_localPlayers[local.id] ?? []).length;
        results.add({
          'id': local.id,
          'code': local.code,
          'name': local.name,
          'status': local.status.name,
          'max_players': local.maxPlayers,
          'participant_count': count,
          'updated_at': local.createdAt.toIso8601String(),
        });
      } else {
        results.add({
          'id': code,
          'code': code,
          'name': 'BINGO Room $code',
          'status': 'waiting',
          'max_players': 4,
          'participant_count': 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    return results;
  }

  @override
  Future<Map<String, dynamic>> forfeitMatch({
    required String gameId,
    required String roomId,
  }) async {
    final currentUid = _authRepository.currentUserId ?? '';
    if (currentUid.isEmpty) {
      throw StateError('Not authenticated');
    }

    if (_isOnline) {
      try {
        final res = await _supabaseClient!.rpc(
          'rpc_forfeit_match',
          params: {'p_game_id': gameId, 'p_room_id': roomId},
        );
        if (res is Map<String, dynamic>) {
          return res;
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'forfeitMatch_supabase');
        rethrow;
      }
    }

    // Local / Offline fallback logic:
    final game = _localGames[gameId];
    final room = _localRooms[roomId];
    final players = _localGamePlayers[gameId] ?? [];

    final updatedPlayers = players.map((p) {
      if (p.userId == currentUid) {
        return p.copyWith(isForfeited: true);
      }
      return p;
    }).toList();
    _localGamePlayers[gameId] = updatedPlayers;

    final activePlayers = updatedPlayers.where((p) => !p.isForfeited).toList();

    // Remove forfeited player from active room membership so seat becomes available
    final currentRoomPlayers = _localPlayers[roomId];
    if (currentRoomPlayers != null) {
      _localPlayers[roomId] = currentRoomPlayers
          .where((rp) => rp.userId != currentUid)
          .toList();
      _emitPlayersUpdate(roomId);
    }

    if (activePlayers.length <= 1) {
      final winner = activePlayers.isNotEmpty
          ? activePlayers.first
          : players.first;
      final winnerOutcome = {
        'user_id': winner.userId,
        'display_name': winner.displayName,
        'avatar_color_hex': winner.avatarColorHex,
        'is_winner': true,
        'lines_claimed_count': 5,
        'is_forfeited': false,
      };
      final forfeiterOutcome = {
        'user_id': currentUid,
        'display_name': players
            .firstWhere((p) => p.userId == currentUid, orElse: () => winner)
            .displayName,
        'is_winner': false,
        'lines_claimed_count': 0,
        'is_forfeited': true,
      };

      await finishRound(
        gameId: gameId,
        roomId: roomId,
        winnerId: winner.userId,
        winnerName: winner.displayName,
        totalCalls: game?.calledNumbers.length ?? 0,
        playerOutcomes: [winnerOutcome, forfeiterOutcome],
        roundNumber: game?.roundNumber ?? 1,
      );

      _freezeGameCompleted(gameId, winnerUserId: winner.userId);
      final qm = _localQuickMatches.values
          .where((m) => m.gameId == gameId)
          .firstOrNull;
      if (qm != null) {
        final updatedQm = qm.copyWith(status: QuickMatchStatus.forfeited);
        _localQuickMatches[qm.id] = updatedQm;
        _emitQuickMatchUpdate(qm.id, updatedQm);
        _localQueue.removeWhere((k, v) => v.matchId == qm.id);
      }
      return {
        'success': true,
        'match_completed': true,
        'status': 'completed',
        'winner_id': winner.userId,
        'winner_name': winner.displayName,
        'is_forfeit': true,
        'forfeit_by_id': currentUid,
      };
    } else {
      // 3 or 4 players - advance turn if it was current player's turn
      if (game != null && game.currentTurnUserId == currentUid) {
        final nextPlayer = activePlayers.first;
        final updatedGame = game.copyWith(
          currentTurnUserId: nextPlayer.userId,
          turnDeadline: DateTime.now().add(
            Duration(seconds: room?.turnTimeSeconds ?? 20),
          ),
          updatedAt: DateTime.now(),
        );
        _localGames[gameId] = updatedGame;
        _emitGameUpdate(gameId);
      }
      _emitGamePlayersUpdate(gameId);
      return {
        'success': true,
        'match_completed': false,
        'status': 'player_forfeited',
        'forfeited_user_id': currentUid,
        'active_players_count': activePlayers.length,
      };
    }
  }

  // ===========================================================================
  // QUICK MATCH 1v1 MATCHMAKING IMPLEMENTATION
  // ===========================================================================

  @override
  Future<Map<String, dynamic>> enterMatchmaking({String region = 'auto'}) async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) {
      throw StateError('Cannot enter matchmaking: User not authenticated');
    }

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_enter_matchmaking_queue',
          params: {'p_region': region},
        );
        if (res is Map) {
          final resMap = Map<String, dynamic>.from(res);
          return resMap;
        }
        return {'success': false, 'error': 'Unexpected matchmaking response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(
          e,
          st,
          source: 'rpc_enter_matchmaking_queue',
        );
        return {'success': false, 'error': e.toString()};
      }
    }

    // --- LOCAL FALLBACK MATCHMAKING ---
    // 1. Check if caller already has an active match
    final existingActive = _localQuickMatches.values
        .where(
          (m) =>
              (m.player1Id == currentUid || m.player2Id == currentUid) &&
              (m.status == QuickMatchStatus.countdown ||
                  m.status == QuickMatchStatus.boardPreparation ||
                  m.status == QuickMatchStatus.inProgress),
        )
        .firstOrNull;

    if (existingActive != null) {
      return {
        'success': true,
        'status': 'MATCHED',
        'match_id': existingActive.id,
        'room_id': existingActive.roomId,
        'room_code': existingActive.roomCode,
        'game_id': existingActive.gameId,
        'countdown_deadline': existingActive.countdownDeadline.toIso8601String(),
        'is_existing_match': true,
      };
    }

    // Check if an existing waiting opponent exists in _localQueue
    final existingOpponentEntry = _localQueue.values
        .where(
          (entry) =>
              entry.status == MatchmakingQueueStatus.searching &&
              entry.userId != currentUid,
        )
        .firstOrNull;

    if (existingOpponentEntry != null) {
      // Pair with waiting opponent!
      final matchId = const Uuid().v4();
      final roomId = const Uuid().v4();
      final gameId = const Uuid().v4();
      final roomCode = (100000 + Random().nextInt(900000)).toString();
      final deadline = DateTime.now().add(const Duration(seconds: 10));

      final callerProfile =
          await _profileRepository.getProfile(currentUid) ??
          PlayerProfile(
            id: currentUid,
            displayName: 'Player',
            email: 'player@bingo.app',
            avatarColorHex: '#20243A',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      final opponentProfile =
          await _profileRepository.getProfile(existingOpponentEntry.userId) ??
          PlayerProfile(
            id: existingOpponentEntry.userId,
            displayName: 'Opponent',
            email: 'opponent@bingo.app',
            avatarColorHex: '#FC695C',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      // Create local Room
      final room = Room(
        id: roomId,
        code: roomCode,
        name: 'Quick Match 1v1',
        hostId: existingOpponentEntry.userId,
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 20,
        status: RoomStatus.preparing,
        createdAt: DateTime.now(),
      );
      _localRooms[roomId] = room;

      // Create room players
      _localPlayers[roomId] = [
        RoomPlayer(
          id: const Uuid().v4(),
          roomId: roomId,
          userId: existingOpponentEntry.userId,
          displayName: opponentProfile.displayName,
          avatarColorHex: opponentProfile.avatarColorHex,
          isHost: true,
          isReady: false,
          seatIndex: 0,
          joinedAt: DateTime.now(),
        ),
        RoomPlayer(
          id: const Uuid().v4(),
          roomId: roomId,
          userId: currentUid,
          displayName: callerProfile.displayName,
          avatarColorHex: callerProfile.avatarColorHex,
          isHost: false,
          isReady: false,
          seatIndex: 1,
          joinedAt: DateTime.now(),
        ),
      ];

      // Create local game
      final game = MultiplayerGame(
        id: gameId,
        roomId: roomId,
        status: MultiplayerGameStatus.preparing,
        prepDeadline: deadline.add(const Duration(seconds: 30)),
        currentTurnUserId: existingOpponentEntry.userId,
        calledNumbers: const [],
        roundNumber: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _localGames[gameId] = game;

      _localGamePlayers[gameId] = [
        MultiplayerPlayerState(
          userId: existingOpponentEntry.userId,
          displayName: opponentProfile.displayName,
          avatarColorHex: opponentProfile.avatarColorHex,
          isHost: true,
          seatIndex: 0,
        ),
        MultiplayerPlayerState(
          userId: currentUid,
          displayName: callerProfile.displayName,
          avatarColorHex: callerProfile.avatarColorHex,
          isHost: false,
          seatIndex: 1,
        ),
      ];

      // Create QuickMatch
      final quickMatch = QuickMatch(
        id: matchId,
        roomId: roomId,
        roomCode: roomCode,
        gameId: gameId,
        player1Id: existingOpponentEntry.userId,
        player2Id: currentUid,
        status: QuickMatchStatus.countdown,
        countdownDeadline: deadline,
        opponent: QuickMatchOpponent(
          id: opponentProfile.id,
          displayName: opponentProfile.displayName,
          avatarColorHex: opponentProfile.avatarColorHex,
        ),
        player1: QuickMatchOpponent(
          id: opponentProfile.id,
          displayName: opponentProfile.displayName,
          avatarColorHex: opponentProfile.avatarColorHex,
        ),
        player2: QuickMatchOpponent(
          id: callerProfile.id,
          displayName: callerProfile.displayName,
          avatarColorHex: callerProfile.avatarColorHex,
        ),
      );
      _localQuickMatches[matchId] = quickMatch;

      // Update opponent queue entry
      final updatedOpponentEntry = MatchmakingQueueEntry(
        id: existingOpponentEntry.id,
        userId: existingOpponentEntry.userId,
        status: MatchmakingQueueStatus.matched,
        queuedAt: existingOpponentEntry.queuedAt,
        matchedAt: DateTime.now(),
        matchId: matchId,
        region: region,
      );
      _localQueue[existingOpponentEntry.userId] = updatedOpponentEntry;
      _emitQueueUpdate(existingOpponentEntry.userId, updatedOpponentEntry);

      // Caller queue entry
      final callerEntry = MatchmakingQueueEntry(
        id: const Uuid().v4(),
        userId: currentUid,
        status: MatchmakingQueueStatus.matched,
        queuedAt: DateTime.now(),
        matchedAt: DateTime.now(),
        matchId: matchId,
        region: region,
      );
      _localQueue[currentUid] = callerEntry;
      _emitQueueUpdate(currentUid, callerEntry);
      _emitQuickMatchUpdate(matchId, quickMatch);

      return {
        'success': true,
        'status': 'MATCHED',
        'match_id': matchId,
        'room_id': roomId,
        'room_code': roomCode,
        'game_id': gameId,
        'player1_id': existingOpponentEntry.userId,
        'player2_id': currentUid,
        'countdown_deadline': deadline.toIso8601String(),
        'opponent': {
          'id': opponentProfile.id,
          'display_name': opponentProfile.displayName,
          'avatar_color_hex': opponentProfile.avatarColorHex,
        },
      };
    } else {
      // Put caller in SEARCHING state
      final queueId = const Uuid().v4();
      final newEntry = MatchmakingQueueEntry(
        id: queueId,
        userId: currentUid,
        status: MatchmakingQueueStatus.searching,
        queuedAt: DateTime.now(),
        region: region,
      );
      _localQueue[currentUid] = newEntry;
      _emitQueueUpdate(currentUid, newEntry);

      return {
        'success': true,
        'status': 'SEARCHING',
        'queue_id': queueId,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc('rpc_cancel_matchmaking_queue');
        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected cancellation response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'rpc_cancel_matchmaking_queue');
        return {'success': false, 'error': e.toString()};
      }
    }

    final entry = _localQueue[currentUid];
    if (entry != null) {
      if (entry.status == MatchmakingQueueStatus.matched) {
        return {
          'success': false,
          'reason': 'ALREADY_MATCHED',
          'match_id': entry.matchId,
        };
      }
      final cancelled = MatchmakingQueueEntry(
        id: entry.id,
        userId: currentUid,
        status: MatchmakingQueueStatus.cancelled,
        queuedAt: entry.queuedAt,
        region: entry.region,
      );
      _localQueue[currentUid] = cancelled;
      _emitQueueUpdate(currentUid, cancelled);
    }
    return {'success': true, 'status': 'CANCELLED'};
  }

  @override
  Stream<MatchmakingQueueEntry?> watchMatchmakingQueue(String userId) {
    if (isOnline && _supabaseClient != null) {
      final channelName = 'public:matchmaking_queue:user_$userId';
      if (!_queueChannels.containsKey(channelName)) {
        final controller = StreamController<MatchmakingQueueEntry?>.broadcast();
        _queueControllers[userId] = controller;

        final channel = _supabaseClient.channel(channelName);
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'matchmaking_queue',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty && !controller.isClosed) {
                  controller.add(MatchmakingQueueEntry.fromJson(newRecord));
                }
              },
            )
            .subscribe();

        _queueChannels[channelName] = channel;
      }
      return _queueControllers[userId]?.stream ??
          Stream.value(_localQueue[userId]);
    }

    final controller = _queueControllers.putIfAbsent(
      userId,
      () => StreamController<MatchmakingQueueEntry?>.broadcast(),
    );
    if (_localQueue.containsKey(userId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(_localQueue[userId]);
        }
      });
    }
    return controller.stream;
  }

  @override
  Future<QuickMatch?> getQuickMatch(String matchId) async {
    final currentUid = _authRepository.currentUserId;
    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_get_quick_match_details',
          params: {'p_match_id': matchId},
        );
        if (res is Map && res['success'] == true) {
          return QuickMatch.fromJson(
            Map<String, dynamic>.from(res),
            currentUserId: currentUid,
          );
        }
        return null;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'rpc_get_quick_match_details');
        return null;
      }
    }
    final localMatch = _localQuickMatches[matchId];
    if (localMatch != null && currentUid != null) {
      return localMatch.forUser(currentUid);
    }
    return localMatch;
  }

  @override
  Stream<QuickMatch?> watchQuickMatch(String matchId) {
    if (isOnline && _supabaseClient != null) {
      final channelName = 'public:quick_matches:match_$matchId';
      if (!_quickMatchChannels.containsKey(channelName)) {
        final controller = StreamController<QuickMatch?>.broadcast();
        _quickMatchControllers[matchId] = controller;

        // Fetch initial
        getQuickMatch(matchId).then((qm) {
          if (qm != null && !controller.isClosed) {
            controller.add(qm);
          }
        }).catchError((_) {});

        final channel = _supabaseClient.channel(channelName);
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'quick_matches',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: matchId,
              ),
              callback: (payload) async {
                // Fetch full details upon change
                final qm = await getQuickMatch(matchId);
                if (qm != null && !controller.isClosed) {
                  controller.add(qm);
                }
              },
            )
            .subscribe();

        _quickMatchChannels[channelName] = channel;
      }
      return _quickMatchControllers[matchId]?.stream ??
          Stream.value(_localQuickMatches[matchId]);
    }

    final controller = _quickMatchControllers.putIfAbsent(
      matchId,
      () => StreamController<QuickMatch?>.broadcast(),
    );
    if (_localQuickMatches.containsKey(matchId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          final curUid = _authRepository.currentUserId ?? '';
          controller.add(_localQuickMatches[matchId]?.forUser(curUid));
        }
      });
    }
    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> transitionToBoardPrep(String matchId) async {
    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_transition_to_board_prep',
          params: {'p_match_id': matchId},
        );
        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected transition response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'rpc_transition_to_board_prep');
        return {'success': false, 'error': e.toString()};
      }
    }

    final qm = _localQuickMatches[matchId];
    if (qm != null) {
      final updated = QuickMatch(
        id: qm.id,
        roomId: qm.roomId,
        roomCode: qm.roomCode,
        gameId: qm.gameId,
        player1Id: qm.player1Id,
        player2Id: qm.player2Id,
        status: QuickMatchStatus.boardPreparation,
        countdownDeadline: qm.countdownDeadline,
        opponent: qm.opponent,
        player1: qm.player1,
        player2: qm.player2,
      );
      _localQuickMatches[matchId] = updated;
      _emitQuickMatchUpdate(matchId, updated);
      return {
        'success': true,
        'status': 'BOARD_PREPARATION',
        'room_id': qm.roomId,
        'game_id': qm.gameId,
      };
    }
    return {'success': false, 'error': 'Match not found'};
  }

  @override
  Future<QuickMatch?> getActiveQuickMatch() async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) return null;

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc('rpc_get_active_quick_match');
        if (res is Map && res['has_active_match'] == true) {
          return QuickMatch.fromJson(
            Map<String, dynamic>.from(res),
            currentUserId: currentUid,
          );
        }
        return null;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'rpc_get_active_quick_match');
        return null;
      }
    }

    final active = _localQuickMatches.values
        .where(
          (m) =>
              (m.player1Id == currentUid || m.player2Id == currentUid) &&
              (m.status == QuickMatchStatus.countdown ||
                  m.status == QuickMatchStatus.boardPreparation ||
                  m.status == QuickMatchStatus.inProgress),
        )
        .firstOrNull;

    return active?.forUser(currentUid);
  }

  void _emitQueueUpdate(String userId, MatchmakingQueueEntry entry) {
    if (_queueControllers.containsKey(userId) &&
        !_queueControllers[userId]!.isClosed) {
      _queueControllers[userId]!.add(entry);
    }
  }

  @visibleForTesting
  void emitQueueUpdateForTesting(String userId, MatchmakingQueueEntry entry) {
    _emitQueueUpdate(userId, entry);
  }

  void _emitQuickMatchUpdate(String matchId, QuickMatch qm) {
    if (_quickMatchControllers.containsKey(matchId) &&
        !_quickMatchControllers[matchId]!.isClosed) {
      _quickMatchControllers[matchId]!.add(qm);
    }
  }

  @override
  Future<QuickMatch?> getQuickMatchByRoomId(String roomId) async {
    final currentUid = _authRepository.currentUserId;
    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_get_quick_match_by_room',
          params: {'p_room_id': roomId},
        );
        if (res is Map && res['success'] == true && res['match_id'] != null) {
          return getQuickMatch(res['match_id'].toString());
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'rpc_get_quick_match_by_room');
        // Fallback to direct query on quick_matches
        try {
          final row = await _supabaseClient
              .from('quick_matches')
              .select('id')
              .eq('room_id', roomId)
              .maybeSingle();
          if (row != null && row['id'] != null) {
            return getQuickMatch(row['id'].toString());
          }
        } catch (_) {}
      }
    }

    final localMatch = _localQuickMatches.values
        .where((m) => m.roomId == roomId)
        .firstOrNull;
    if (localMatch != null && currentUid != null) {
      return localMatch.forUser(currentUid);
    }
    return localMatch;
  }

  @override
  Future<QuickMatchResultData?> getQuickMatchResult(String matchId) async {
    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_get_quick_match_details',
          params: {'p_match_id': matchId},
        );
        if (res is Map && res['success'] == true) {
          return QuickMatchResultData.fromJson(Map<String, dynamic>.from(res));
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st, source: 'getQuickMatchResult_supabase');
      }
    }

    // Local in-memory construction
    final qm = _localQuickMatches[matchId];
    if (qm != null) {
      final game = _localGames[qm.gameId];
      final players = _localGamePlayers[qm.gameId] ?? [];
      final p1State = players.where((p) => p.userId == qm.player1Id).firstOrNull;
      final p2State = players.where((p) => p.userId == qm.player2Id).firstOrNull;

      final p1 = QuickMatchParticipantResult(
        id: qm.player1Id,
        displayName: qm.player1?.displayName ?? 'Player 1',
        avatarColorHex: qm.player1?.avatarColorHex ?? '#20243A',
        linesClaimed: p1State?.linesClaimed ?? 0,
        claimedLineTypes: p1State?.claimedLineTypes ?? const [],
        isWinner: p1State?.isWinner ?? false,
        isForfeited: p1State?.isForfeited ?? false,
      );

      final p2 = QuickMatchParticipantResult(
        id: qm.player2Id,
        displayName: qm.player2?.displayName ?? 'Player 2',
        avatarColorHex: qm.player2?.avatarColorHex ?? '#FC695C',
        linesClaimed: p2State?.linesClaimed ?? 0,
        claimedLineTypes: p2State?.claimedLineTypes ?? const [],
        isWinner: p2State?.isWinner ?? false,
        isForfeited: p2State?.isForfeited ?? false,
      );

      return QuickMatchResultData(
        matchId: qm.id,
        roomId: qm.roomId,
        roomCode: qm.roomCode,
        gameId: qm.gameId,
        status: qm.status,
        winnerUserId: game?.winnerUserId,
        totalCalls: game?.calledNumbers.length ?? 0,
        durationSeconds: 90,
        calledNumbers: game?.calledNumbers ?? const [],
        player1: p1,
        player2: p2,
      );
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> requestQuickMatchRematch(
      String previousMatchId) async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_request_quick_match_rematch',
          params: {'p_previous_match_id': previousMatchId},
        );
        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st,
            source: 'rpc_request_quick_match_rematch');
        return {'success': false, 'error': e.toString()};
      }
    }

    // Local fallback
    final prev = _localQuickMatches[previousMatchId];
    if (prev == null) {
      return {'success': false, 'error': 'Match not found'};
    }
    final opponentId =
        prev.player1Id == currentUid ? prev.player2Id : prev.player1Id;
    final requestId = const Uuid().v4();
    final req = QuickMatchRematchRequest(
      id: requestId,
      previousMatchId: previousMatchId,
      requesterUserId: currentUid,
      opponentUserId: opponentId,
      status: QuickMatchRematchStatus.pending,
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      opponent: prev.opponent,
    );
    _localRematchRequests[requestId] = req;
    _emitRematchUpdate(requestId, req);
    return {
      'success': true,
      'request_id': requestId,
      'status': 'PENDING',
      'expires_at': req.expiresAt.toIso8601String(),
      'is_requester': true,
    };
  }

  @override
  Future<Map<String, dynamic>> respondQuickMatchRematch(
      String requestId, bool accept) async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_respond_quick_match_rematch',
          params: {
            'p_request_id': requestId,
            'p_accept': accept,
          },
        );
        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st,
            source: 'rpc_respond_quick_match_rematch');
        return {'success': false, 'error': e.toString()};
      }
    }

    // Local fallback
    final req = _localRematchRequests[requestId];
    if (req == null) {
      return {'success': false, 'error': 'Request not found'};
    }

    if (!accept) {
      final updated = QuickMatchRematchRequest(
        id: req.id,
        previousMatchId: req.previousMatchId,
        requesterUserId: req.requesterUserId,
        opponentUserId: req.opponentUserId,
        status: QuickMatchRematchStatus.declined,
        expiresAt: req.expiresAt,
        createdAt: req.createdAt,
        respondedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        opponent: req.opponent,
      );
      _localRematchRequests[requestId] = updated;
      _emitRematchUpdate(requestId, updated);
      return {'success': true, 'status': 'DECLINED'};
    }

    // Accept -> create new Quick Match
    final newMatchId = const Uuid().v4();
    final roomId = const Uuid().v4();
    final gameId = const Uuid().v4();
    final roomCode = (100000 + Random().nextInt(900000)).toString();
    final deadline = DateTime.now().add(const Duration(seconds: 10));

    final callerProfile = await _profileRepository.getProfile(currentUid);
    final opponentProfile =
        await _profileRepository.getProfile(req.requesterUserId);

    final room = Room(
      id: roomId,
      code: roomCode,
      name: 'Quick Match 1v1',
      hostId: req.requesterUserId,
      maxPlayers: 2,
      prepTimeSeconds: 30,
      turnTimeSeconds: 20,
      matchType: 'QUICK_MATCH',
      status: RoomStatus.preparing,
      createdAt: DateTime.now(),
    );
    _localRooms[roomId] = room;

    final game = MultiplayerGame(
      id: gameId,
      roomId: roomId,
      status: MultiplayerGameStatus.preparing,
      prepDeadline: deadline.add(const Duration(seconds: 30)),
      currentTurnUserId: req.requesterUserId,
      calledNumbers: const [],
      roundNumber: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localGames[gameId] = game;

    final newMatch = QuickMatch(
      id: newMatchId,
      roomId: roomId,
      roomCode: roomCode,
      gameId: gameId,
      player1Id: req.requesterUserId,
      player2Id: currentUid,
      status: QuickMatchStatus.countdown,
      countdownDeadline: deadline,
      opponent: QuickMatchOpponent(
        id: req.requesterUserId,
        displayName: opponentProfile?.displayName ?? 'Opponent',
        avatarColorHex: opponentProfile?.avatarColorHex ?? '#20243A',
      ),
      player1: QuickMatchOpponent(
        id: req.requesterUserId,
        displayName: opponentProfile?.displayName ?? 'Player 1',
        avatarColorHex: opponentProfile?.avatarColorHex ?? '#20243A',
      ),
      player2: QuickMatchOpponent(
        id: currentUid,
        displayName: callerProfile?.displayName ?? 'Player 2',
        avatarColorHex: callerProfile?.avatarColorHex ?? '#FC695C',
      ),
    );
    _localQuickMatches[newMatchId] = newMatch;

    final updated = QuickMatchRematchRequest(
      id: req.id,
      previousMatchId: req.previousMatchId,
      requesterUserId: req.requesterUserId,
      opponentUserId: req.opponentUserId,
      status: QuickMatchRematchStatus.accepted,
      newMatchId: newMatchId,
      expiresAt: req.expiresAt,
      createdAt: req.createdAt,
      respondedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      opponent: req.opponent,
    );
    _localRematchRequests[requestId] = updated;
    _emitRematchUpdate(requestId, updated);

    return {
      'success': true,
      'status': 'ACCEPTED',
      'request_id': requestId,
      'new_match_id': newMatchId,
      'room_id': roomId,
      'room_code': roomCode,
      'game_id': gameId,
      'countdown_deadline': deadline.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> cancelQuickMatchRematch(String requestId) async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_cancel_quick_match_rematch',
          params: {'p_request_id': requestId},
        );
        if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {'success': false, 'error': 'Unexpected response from server'};
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st,
            source: 'rpc_cancel_quick_match_rematch');
        return {'success': false, 'error': e.toString()};
      }
    }

    final req = _localRematchRequests[requestId];
    if (req != null && req.isPending) {
      final updated = QuickMatchRematchRequest(
        id: req.id,
        previousMatchId: req.previousMatchId,
        requesterUserId: req.requesterUserId,
        opponentUserId: req.opponentUserId,
        status: QuickMatchRematchStatus.cancelled,
        expiresAt: req.expiresAt,
        createdAt: req.createdAt,
        updatedAt: DateTime.now(),
        opponent: req.opponent,
      );
      _localRematchRequests[requestId] = updated;
      _emitRematchUpdate(requestId, updated);
    }
    return {'success': true, 'status': 'CANCELLED'};
  }

  @override
  Future<QuickMatchRematchRequest?> getPendingRematchRequest(
      {String? matchId}) async {
    final currentUid = _authRepository.currentUserId;
    if (currentUid == null) return null;

    if (isOnline && _supabaseClient != null) {
      try {
        final res = await _supabaseClient.rpc(
          'rpc_get_pending_rematch_request',
          params: {'p_match_id': matchId},
        );
        if (res is Map && res['has_pending_request'] == true) {
          return QuickMatchRematchRequest.fromJson(
            Map<String, dynamic>.from(res),
            currentUserId: currentUid,
          );
        }
        return null;
      } catch (e, st) {
        ErrorLogger.logUnhandled(e, st,
            source: 'rpc_get_pending_rematch_request');
        return null;
      }
    }

    final req = _localRematchRequests.values
        .where((r) =>
            (matchId == null || r.previousMatchId == matchId) &&
            (r.requesterUserId == currentUid || r.opponentUserId == currentUid) &&
            (r.status == QuickMatchRematchStatus.pending ||
                r.status == QuickMatchRematchStatus.accepted) &&
            !r.isExpired)
        .firstOrNull;

    return req;
  }

  @override
  Stream<QuickMatchRematchRequest?> watchRematchRequest(String requestId) {
    if (isOnline && _supabaseClient != null) {
      final channelName = 'public:quick_match_rematch_requests:$requestId';
      if (!_rematchChannels.containsKey(channelName)) {
        final controller =
            StreamController<QuickMatchRematchRequest?>.broadcast();
        _rematchControllers[requestId] = controller;

        // Initial fetch
        _supabaseClient
            .from('quick_match_rematch_requests')
            .select()
            .eq('id', requestId)
            .maybeSingle()
            .then((data) {
          if (data != null && !controller.isClosed) {
            controller.add(QuickMatchRematchRequest.fromJson(
              data,
              currentUserId: _authRepository.currentUserId,
            ));
          }
        }).catchError((_) {});

        final channel = _supabaseClient.channel(channelName);
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'quick_match_rematch_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: requestId,
              ),
              callback: (payload) {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty && !controller.isClosed) {
                  controller.add(QuickMatchRematchRequest.fromJson(
                    newRecord,
                    currentUserId: _authRepository.currentUserId,
                  ));
                }
              },
            )
            .subscribe();

        _rematchChannels[channelName] = channel;
      }
      return _rematchControllers[requestId]?.stream ??
          Stream.value(_localRematchRequests[requestId]);
    }

    final controller = _rematchControllers.putIfAbsent(
      requestId,
      () => StreamController<QuickMatchRematchRequest?>.broadcast(),
    );
    if (_localRematchRequests.containsKey(requestId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(_localRematchRequests[requestId]);
        }
      });
    }
    return controller.stream;
  }

  @override
  Stream<QuickMatchRematchRequest?> watchUserRematchRequests(String userId) {
    if (isOnline && _supabaseClient != null) {
      final channelName = 'public:quick_match_rematch_requests:user_$userId';
      if (!_rematchChannels.containsKey(channelName)) {
        final controller =
            StreamController<QuickMatchRematchRequest?>.broadcast();
        _userRematchControllers[userId] = controller;

        // Initial fetch
        getPendingRematchRequest().then((req) {
          if (req != null && !controller.isClosed) {
            controller.add(req);
          }
        }).catchError((_) {});

        final channel = _supabaseClient.channel(channelName);
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'quick_match_rematch_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'opponent_user_id',
                value: userId,
              ),
              callback: (payload) async {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty && !controller.isClosed) {
                  controller.add(QuickMatchRematchRequest.fromJson(
                    newRecord,
                    currentUserId: userId,
                  ));
                }
              },
            )
            .subscribe();

        _rematchChannels[channelName] = channel;
      }
      return _userRematchControllers[userId]?.stream ??
          Stream.value(_localRematchRequests.values
              .where((r) => r.opponentUserId == userId && r.isPending)
              .firstOrNull);
    }

    final controller = _userRematchControllers.putIfAbsent(
      userId,
      () => StreamController<QuickMatchRematchRequest?>.broadcast(),
    );
    return controller.stream;
  }

  void _emitRematchUpdate(String requestId, QuickMatchRematchRequest req) {
    if (_rematchControllers.containsKey(requestId) &&
        !_rematchControllers[requestId]!.isClosed) {
      _rematchControllers[requestId]!.add(req);
    }
    if (_userRematchControllers.containsKey(req.opponentUserId) &&
        !_userRematchControllers[req.opponentUserId]!.isClosed) {
      _userRematchControllers[req.opponentUserId]!.add(req);
    }
    if (_userRematchControllers.containsKey(req.requesterUserId) &&
        !_userRematchControllers[req.requesterUserId]!.isClosed) {
      _userRematchControllers[req.requesterUserId]!.add(req);
    }
  }
}

