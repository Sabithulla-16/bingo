import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/multiplayer/data/multiplayer_repository_impl.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';
import 'multiplayer_repository_test.dart';

void main() {
  group('Guest Restriction Security Tests', () {
    late MultiplayerRepositoryImpl repository;
    late MockAuthRepository mockAuth;
    late MockProfileRepository mockProfile;

    final guestUser = PlayerProfile(
      id: 'guest_user_9999',
      displayName: 'Guest Player',
      email: 'guest@bingo.app',
      avatarColorHex: '#FC695C',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final registeredUser = PlayerProfile(
      id: 'reg_user_1111',
      displayName: 'Registered Host',
      email: 'reg@bingo.app',
      avatarColorHex: '#FF6B5E',
      chips: 1000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuth = MockAuthRepository(guestUser);
      mockProfile = MockProfileRepository(guestUser);
      mockProfile.setProfile(registeredUser);
      repository = MultiplayerRepositoryImpl(
        authRepository: mockAuth,
        profileRepository: mockProfile,
      );
    });

    test('guest profile is correctly identified as guest', () {
      expect(guestUser.isGuest, isTrue);
      expect(registeredUser.isGuest, isFalse);
    });

    test('guest is rejected when attempting to create a room', () async {
      expect(
        () => repository.createRoom(
          name: 'Guest Room',
          maxPlayers: 4,
          prepTimeSeconds: 45,
          turnTimeSeconds: 20,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Guest users cannot access multiplayer'),
          ),
        ),
      );
    });

    test('guest is rejected when attempting to join a room', () async {
      // First, registered user creates a room
      mockAuth.currentProfile = registeredUser;
      final room = await repository.createRoom(
        name: 'Open Tournament',
        maxPlayers: 4,
        prepTimeSeconds: 45,
        turnTimeSeconds: 20,
      );

      // Now switch to guest user
      mockAuth.currentProfile = guestUser;
      expect(
        () => repository.joinRoomByCode(room.code),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Guest users cannot access multiplayer'),
          ),
        ),
      );
    });
  });
}
