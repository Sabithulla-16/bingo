import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/multiplayer_game.dart';
import '../domain/room.dart';
import 'multiplayer_repository.dart';

class MultiplayerRepositoryImpl implements MultiplayerRepository {
  final SupabaseClient? _supabaseClient;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  // In-memory fallback stores for offline mode & deterministic testing
  final Map<String, Room> _localRooms = {};
  final Map<String, List<RoomPlayer>> _localPlayers = {};
  final Map<String, StreamController<Room>> _roomControllers = {};
  final Map<String, StreamController<List<RoomPlayer>>> _playersControllers = {};

  final Map<String, MultiplayerGame> _localGames = {};
  final Map<String, List<MultiplayerPlayerState>> _localGamePlayers = {};
  final Map<String, StreamController<MultiplayerGame>> _gameControllers = {};
  final Map<String, StreamController<List<MultiplayerPlayerState>>> _gamePlayersControllers = {};

  MultiplayerRepositoryImpl({
    SupabaseClient? supabaseClient,
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
  })  : _supabaseClient = supabaseClient,
        _authRepository = authRepository,
        _profileRepository = profileRepository;

  bool get _isOnline =>
      _supabaseClient != null &&
      _supabaseClient.auth.currentUser != null;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing 0/O, 1/I
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
    final userId = currentProfile?.id ?? _authRepository.currentUserId ?? 'host_${DateTime.now().millisecondsSinceEpoch}';
    final userName = currentProfile?.displayName ?? 'Host Player';
    final userAvatar = currentProfile?.avatarColorHex ?? '#FF6B5E';

    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
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
      id: 'rp_${DateTime.now().millisecondsSinceEpoch}',
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

        await _supabaseClient.from('room_players').insert(hostPlayer.toMap());
        return Room.fromMap(insertedRoom);
      } catch (_) {
        // Fallback to local
      }
    }

    _localRooms[roomId] = room;
    _localPlayers[roomId] = [hostPlayer];
    _emitRoomUpdate(roomId);
    _emitPlayersUpdate(roomId);

    return room;
  }

  @override
  Future<Room> joinRoomByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final currentProfile = await _getCurrentProfile();
    final userId = currentProfile?.id ?? _authRepository.currentUserId ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final userName = currentProfile?.displayName ?? 'Guest Player';
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
      throw StateError('Room is full (${targetRoom.maxPlayers}/${targetRoom.maxPlayers} players).');
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
      id: 'rp_${DateTime.now().millisecondsSinceEpoch}',
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
        await _supabaseClient!.from('room_players').insert(newPlayer.toMap());
        return targetRoom;
      } catch (_) {
        // Fallback to local
      }
    }

    _localPlayers.putIfAbsent(targetRoom.id, () => []);
    _localPlayers[targetRoom.id]!.add(newPlayer);
    _emitPlayersUpdate(targetRoom.id);

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

    if (_isOnline && userId != null) {
      try {
        await _supabaseClient!
            .from('room_players')
            .update({'is_ready': isReady})
            .eq('room_id', roomId)
            .eq('user_id', userId);
        return;
      } catch (_) {}
    }

    final players = _localPlayers[roomId];
    if (players != null) {
      final index = players.indexWhere((p) => p.userId == userId || !p.isHost);
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
        await _supabaseClient!
            .from('room_players')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', userId);
        return;
      } catch (_) {}
    }

    final players = _localPlayers[roomId];
    if (players != null) {
      players.removeWhere((p) => p.userId == userId);
      _emitPlayersUpdate(roomId);
    }
  }

  @override
  Future<void> startGame(String roomId) async {
    if (_isOnline) {
      try {
        await _supabaseClient!
            .from('rooms')
            .update({'status': 'preparing'})
            .eq('id', roomId);
        return;
      } catch (_) {}
    }

    final room = _localRooms[roomId];
    if (room != null) {
      _localRooms[roomId] = room.copyWith(status: RoomStatus.preparing);
      _emitRoomUpdate(roomId);
    }
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    final userId = _authRepository.currentUserId;

    final players = await getRoomPlayers(roomId);
    final isHost = players.any((p) => p.userId == userId && p.isHost);

    if (_isOnline && userId != null) {
      try {
        if (isHost) {
          await _supabaseClient!.from('rooms').delete().eq('id', roomId);
        } else {
          await _supabaseClient!
              .from('room_players')
              .delete()
              .eq('room_id', roomId)
              .eq('user_id', userId);
        }
        return;
      } catch (_) {}
    }

    if (isHost) {
      _localRooms.remove(roomId);
      _localPlayers.remove(roomId);
    } else {
      _localPlayers[roomId]?.removeWhere((p) => p.userId == userId);
      _emitPlayersUpdate(roomId);
    }
  }

  @override
  Stream<Room> watchRoom(String roomId) {
    final controller = _roomControllers.putIfAbsent(
      roomId,
      () => StreamController<Room>.broadcast(),
    );

    // Initial emission
    getRoom(roomId).then((room) {
      if (room != null && !controller.isClosed) {
        controller.add(room);
      }
    });

    return controller.stream;
  }

  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomId) {
    final controller = _playersControllers.putIfAbsent(
      roomId,
      () => StreamController<List<RoomPlayer>>.broadcast(),
    );

    // Initial emission
    getRoomPlayers(roomId).then((players) {
      if (!controller.isClosed) {
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
      final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}';

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

  @override
  Stream<MultiplayerGame> watchGame(String gameId) {
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

    final userId = _authRepository.currentUserId ?? 'current_user';

    if (_isOnline) {
      try {
        await _supabaseClient!.rpc('rpc_submit_board', params: {
          'p_game_id': gameId,
          'p_board': numbers,
        });
        return;
      } catch (_) {}
    }

    // In-memory fallback
    final players = _localGamePlayers[gameId];
    if (players != null) {
      final index = players.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        players[index] = players[index].copyWith(
          boardNumbers: List.unmodifiable(numbers),
          isBoardConfirmed: true,
        );
      } else {
        players.add(MultiplayerPlayerState(
          userId: userId,
          displayName: 'Player',
          avatarColorHex: '#FF6B5E',
          boardNumbers: List.unmodifiable(numbers),
          isBoardConfirmed: true,
        ));
      }

      // Check if all players confirmed
      final allConfirmed = players.every((p) => p.isBoardConfirmed);
      if (allConfirmed && players.length >= 2) {
        final game = _localGames[gameId];
        if (game != null) {
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
        }
      }

      _emitGamePlayersUpdate(gameId);
    }
  }

  @override
  Future<void> callNumber({
    required String gameId,
    required int number,
  }) async {
    if (_isOnline) {
      try {
        await _supabaseClient!.rpc('rpc_call_number', params: {
          'p_game_id': gameId,
          'p_number': number,
        });
        return;
      } catch (_) {}
    }

    // In-memory fallback
    final game = _localGames[gameId];
    if (game == null) throw StateError('Game not found');
    if (game.status != MultiplayerGameStatus.inProgress) {
      throw StateError('Game is not in progress');
    }
    if (game.isNumberCalled(number)) {
      throw StateError('Number $number has already been called');
    }

    final players = _localGamePlayers[gameId] ?? [];
    if (players.isEmpty) return;

    // Advance turn to next player in seatIndex order
    final currentIndex = players.indexWhere((p) => p.userId == game.currentTurnUserId);
    final nextIndex = (currentIndex + 1) % players.length;
    final nextUserId = players[nextIndex].userId;

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

    if (_isOnline) {
      try {
        final result = await _supabaseClient!.rpc('rpc_claim_line', params: {
          'p_game_id': gameId,
          'p_line_type': lineType,
          'p_numbers': numbers,
        });
        return result as bool? ?? false;
      } catch (_) {}
    }

    // In-memory fallback
    final game = _localGames[gameId];
    final players = _localGamePlayers[gameId];
    if (game == null || players == null) return false;

    final index = players.indexWhere((p) => p.userId == userId);
    if (index == -1) return false;

    final p = players[index];
    if (p.claimedLineTypes.contains(lineType)) return false;

    final newLines = p.linesClaimed + 1;
    final isWinner = newLines >= 5;

    players[index] = p.copyWith(
      linesClaimed: newLines,
      claimedLineTypes: [...p.claimedLineTypes, lineType],
      isWinner: isWinner,
    );

    if (isWinner) {
      _localGames[gameId] = game.copyWith(
        status: MultiplayerGameStatus.completed,
        winnerUserId: userId,
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);

      final room = _localRooms[game.roomId];
      if (room != null) {
        _localRooms[game.roomId] = room.copyWith(status: RoomStatus.completed);
        _emitRoomUpdate(game.roomId);
      }
    }

    _emitGamePlayersUpdate(gameId);
    return isWinner;
  }

  @override
  Future<void> extendPrepTime({
    required String gameId,
    int extensionSeconds = 30,
  }) async {
    final game = _localGames[gameId];
    if (game != null) {
      _localGames[gameId] = game.copyWith(
        prepDeadline: game.prepDeadline.add(Duration(seconds: extensionSeconds)),
        updatedAt: DateTime.now(),
      );
      _emitGameUpdate(gameId);
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
}
