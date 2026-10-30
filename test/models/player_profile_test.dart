import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/profile/domain/player_profile.dart';

void main() {
  group('PlayerProfile Model Tests', () {
    test('creates PlayerProfile and serializes to/from JSON correctly', () {
      final now = DateTime.now();
      final profile = PlayerProfile(
        id: 'user-uuid-1234',
        displayName: 'Valtry',
        email: 'valtry@bingo.app',
        avatarId: 'avatar_tiger',
        createdAt: now,
        updatedAt: now,
      );

      final json = profile.toJson();
      expect(json['id'], 'user-uuid-1234');
      expect(json['display_name'], 'Valtry');
      expect(json['email'], 'valtry@bingo.app');
      expect(json['avatar_id'], 'avatar_tiger');

      final deserialized = PlayerProfile.fromJson(json);
      expect(deserialized.id, profile.id);
      expect(deserialized.displayName, profile.displayName);
      expect(deserialized.email, profile.email);
      expect(deserialized.avatarId, profile.avatarId);
    });

    test(
      'copyWith properly updates specified fields while preserving others',
      () {
        final now = DateTime.now();
        final original = PlayerProfile(
          id: 'u1',
          displayName: 'OldName',
          email: 'old@bingo.app',
          avatarId: 'avatar_1',
          createdAt: now,
          updatedAt: now,
        );

        final updated = original.copyWith(
          displayName: 'NewName',
          avatarId: 'avatar_2',
        );

        expect(updated.displayName, 'NewName');
        expect(updated.avatarId, 'avatar_2');
        expect(updated.id, original.id);
        expect(updated.email, original.email);
      },
    );

    test('equality checks compare by id', () {
      final now = DateTime.now();
      final p1 = PlayerProfile(
        id: 'same-id',
        displayName: 'A',
        email: 'a@a.com',
        createdAt: now,
        updatedAt: now,
      );
      final p2 = PlayerProfile(
        id: 'same-id',
        displayName: 'B',
        email: 'b@b.com',
        createdAt: now,
        updatedAt: now,
      );

      expect(p1, equals(p2));
    });
  });
}
