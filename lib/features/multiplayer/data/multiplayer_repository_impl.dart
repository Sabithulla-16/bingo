import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
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
}
