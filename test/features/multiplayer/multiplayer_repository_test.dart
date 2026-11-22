import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/authentication/domain/auth_repository.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/multiplayer/domain/room.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';
import 'package:bingo/features/profile/domain/player_preferences.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';

class MockAuthRepository implements AuthRepository {
  PlayerProfile? currentProfile;

  MockAuthRepository([this.currentProfile]);

  @override
  String? get currentUserId => currentProfile?.id;

  @override
  bool get isAuthenticated => currentProfile != null;

  @override
  bool get isGuest => currentProfile?.isGuest ?? false;

  @override
  Stream<AppAuthState> get authStateChanges => Stream.value(
    currentProfile != null
        ? Authenticated(currentProfile!)
        : const Unauthenticated(),
  );

  @override
  Future<PlayerProfile?> restoreSession() async => currentProfile;

  @override
  Future<PlayerProfile> signInAsGuest({String? displayName}) async =>
      currentProfile!;

  @override
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async => currentProfile!;

  @override
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => currentProfile!;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    currentProfile = null;
  }
}

class MockProfileRepository implements ProfileRepository {
  final Map<String, PlayerProfile> profiles = {};

  MockProfileRepository([PlayerProfile? initialProfile]) {
    if (initialProfile != null) {
      profiles[initialProfile.id] = initialProfile;
    }
  }

  void setProfile(PlayerProfile profile) {
    profiles[profile.id] = profile;
  }

  @override
  Future<PlayerProfile?> getProfile(String userId) async => profiles[userId];

  @override
  Future<PlayerProfile> upsertProfile(PlayerProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<void> updateDisplayName(String userId, String displayName) async {
    final p = profiles[userId];
    if (p != null) profiles[userId] = p.copyWith(displayName: displayName);
  }

  @override
  Future<void> updateAvatar(
    String userId, {
    required String avatarId,
    required String avatarColorHex,
  }) async {
    final p = profiles[userId];
    if (p != null) {
      profiles[userId] = p.copyWith(
        avatarId: avatarId,
        avatarColorHex: avatarColorHex,
      );
    }
  }

  @override
  Stream<PlayerProfile> watchProfile(String userId) {
    final p = profiles[userId];
    if (p != null) return Stream.value(p);
    return const Stream.empty();
  }

  @override
  Stream<PlayerCareerStats> watchCareerStats(String userId) =>
      Stream.value(const PlayerCareerStats());

  @override
  Future<PlayerCareerStats> getCareerStats(String userId) async =>
      const PlayerCareerStats();

  @override
  Future<void> recordMatchResult({
    required String userId,
    required MatchOutcome outcome,
    required int linesClaimed,
    required int callsCount,
    required bool isMultiplayer,
  }) async {}

  @override
  Future<PlayerPreferences> getPreferences() async => const PlayerPreferences();

  @override
  Future<void> savePreferences(PlayerPreferences preferences) async {}
}

void main() {
  group('MultiplayerRepository Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;
    final hostProfile = PlayerProfile(
      id: 'host_user_1',
      displayName: 'Host Alice',
      email: 'host@bingo.dev',
      avatarColorHex: '#FF6B5E',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(hostProfile);
      mockProfile = MockProfileRepository(hostProfile);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test(
      'createRoom generates 6-char code, seats host at index 0 and sets status waiting',
      () async {
        final room = await repository.createRoom(
          name: 'Weekend Tournament',
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        expect(room.name, equals('Weekend Tournament'));
        expect(room.code.length, equals(6));
        expect(room.hostId, equals('host_user_1'));
        expect(room.maxPlayers, equals(4));
        expect(room.status, equals(RoomStatus.waiting));

        final players = await repository.getRoomPlayers(room.id);
        expect(players.length, equals(1));
        expect(players.first.isHost, isTrue);
        expect(players.first.seatIndex, equals(0));
        expect(players.first.displayName, equals('Host Alice'));
      },
    );

    test(
      'joinRoomByCode allows player to join and takes seat index 1',
      () async {
        final room = await repository.createRoom(
          name: 'Duel',
          maxPlayers: 2,
          prepTimeSeconds: 30,
          turnTimeSeconds: 15,
        );

        // Switch to Bob
        final bobProfile = PlayerProfile(
          id: 'challenger_bob_2',
          displayName: 'Challenger Bob',
          email: 'bob@bingo.dev',
          avatarColorHex: '#20243A',
          chips: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockAuth.currentProfile = bobProfile;
        mockProfile.setProfile(bobProfile);

        final joinedRoom = await repository.joinRoomByCode(room.code);
        expect(joinedRoom.id, equals(room.id));

        final players = await repository.getRoomPlayers(room.id);
        expect(players.length, equals(2));
        expect(players[1].userId, equals('challenger_bob_2'));
        expect(players[1].seatIndex, equals(1));
        expect(players[1].isHost, isFalse);
        expect(players[1].isReady, isFalse);
      },
    );

    test('joinRoomByCode throws when room is full', () async {
      final room = await repository.createRoom(
        name: '2-Player Room',
        maxPlayers: 2,
        prepTimeSeconds: 30,
        turnTimeSeconds: 15,
      );

      // 2nd player joins
      final p2 = PlayerProfile(
        id: 'user_2',
        displayName: 'User 2',
        email: 'u2@bingo.dev',
        avatarColorHex: '#20243A',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockAuth.currentProfile = p2;
      mockProfile.setProfile(p2);
      await repository.joinRoomByCode(room.code);

      // 3rd player attempts to join
      final p3 = PlayerProfile(
        id: 'user_3',
        displayName: 'User 3',
        email: 'u3@bingo.dev',
        avatarColorHex: '#20243A',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockAuth.currentProfile = p3;
      mockProfile.setProfile(p3);

      expect(
        () => repository.joinRoomByCode(room.code),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'toggleReady updates readiness and startGame transitions status to preparing',
      () async {
        final room = await repository.createRoom(
          name: 'Battle Room',
          maxPlayers: 3,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        );

        // Join as player 2
        final p2 = PlayerProfile(
          id: 'player_2',
          displayName: 'Player 2',
          email: 'p2@bingo.dev',
          avatarColorHex: '#20243A',
          chips: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockAuth.currentProfile = p2;
        mockProfile.setProfile(p2);
        await repository.joinRoomByCode(room.code);

        // Toggle ready to true
        await repository.toggleReady(roomId: room.id, isReady: true);
        var players = await repository.getRoomPlayers(room.id);
        expect(
          players.firstWhere((p) => p.userId == 'player_2').isReady,
          isTrue,
        );

        // Start game
        await repository.startGame(room.id);
        final updatedRoom = await repository.getRoom(room.id);
        expect(updatedRoom!.status, equals(RoomStatus.preparing));
      },
    );

    test('kickPlayer removes targeted player from room seats', () async {
      final room = await repository.createRoom(
        name: 'Open Room',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      // Join as player 2
      final badActor = PlayerProfile(
        id: 'bad_actor',
        displayName: 'Troll',
        email: 'bad@bingo.dev',
        avatarColorHex: '#20243A',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockAuth.currentProfile = badActor;
      mockProfile.setProfile(badActor);
      await repository.joinRoomByCode(room.code);

      var players = await repository.getRoomPlayers(room.id);
      expect(players.length, equals(2));

      // Host kicks player
      mockAuth.currentProfile = hostProfile;
      mockProfile.setProfile(hostProfile);
      await repository.kickPlayer(roomId: room.id, userId: 'bad_actor');

      players = await repository.getRoomPlayers(room.id);
      expect(players.length, equals(1));
      expect(players.any((p) => p.userId == 'bad_actor'), isFalse);
    });
  });
}
