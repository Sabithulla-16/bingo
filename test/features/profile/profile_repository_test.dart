import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/profile/data/profile_repository_impl.dart';
import 'package:bingo/features/profile/domain/player_career_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileRepository & Statistics Tests', () {
    late ProfileRepositoryImpl profileRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      profileRepo = ProfileRepositoryImpl(null);
    });

    test(
      'getCareerStats returns zero initial stats and calculates win percentage accurately',
      () async {
        // 1. Fresh user has 0 matches
        final emptyStats = await profileRepo.getCareerStats('user-1');
        expect(emptyStats.totalMatches, equals(0));
        expect(emptyStats.wins, equals(0));
        expect(emptyStats.winRatePercentage, equals(0));

        // 2. Record 12 victories, 10 defeats, and 3 draws
        for (int i = 0; i < 12; i++) {
          await profileRepo.recordMatchResult(
            userId: 'user-1',
            outcome: MatchOutcome.victory,
            linesClaimed: 5,
            callsCount: 16,
            isMultiplayer: false,
          );
        }
        for (int i = 0; i < 10; i++) {
          await profileRepo.recordMatchResult(
            userId: 'user-1',
            outcome: MatchOutcome.defeat,
            linesClaimed: 3,
            callsCount: 18,
            isMultiplayer: false,
          );
        }
        for (int i = 0; i < 3; i++) {
          await profileRepo.recordMatchResult(
            userId: 'user-1',
            outcome: MatchOutcome.draw,
            linesClaimed: 2,
            callsCount: 25,
            isMultiplayer: false,
          );
        }

        final stats = await profileRepo.getCareerStats('user-1');

        // Verified data: 12 wins out of 25 matches = 48%
        expect(stats.totalMatches, equals(25));
        expect(stats.wins, equals(12));
        expect(stats.losses, equals(10));
        expect(stats.draws, equals(3));
        expect(stats.winRatePercentage, equals(48));
      },
    );

    test('updateDisplayName modifies profile and persists locally', () async {
      final initial = await profileRepo.getProfile('user-test');
      expect(initial, isNotNull);

      await profileRepo.updateDisplayName('user-test', 'NewCaptain');
      final updated = await profileRepo.getProfile('user-test');

      expect(updated!.displayName, equals('NewCaptain'));
    });

    test('updateAvatar updates color hex and avatar id', () async {
      await profileRepo.updateAvatar(
        'user-test',
        avatarId: 'avatar_yellow',
        avatarColorHex: '#FFD166',
      );

      final updated = await profileRepo.getProfile('user-test');
      expect(updated!.avatarColorHex, equals('#FFD166'));
      expect(updated.avatarId, equals('avatar_yellow'));
    });

    test('preferences load defaults and save toggled settings', () async {
      final initial = await profileRepo.getPreferences();
      expect(initial.soundEffectsEnabled, isTrue);
      expect(initial.hapticsEnabled, isTrue);

      final modified = initial.copyWith(soundEffectsEnabled: false);
      await profileRepo.savePreferences(modified);

      final reloaded = await profileRepo.getPreferences();
      expect(reloaded.soundEffectsEnabled, isFalse);
      expect(reloaded.hapticsEnabled, isTrue);
    });
  });
}
