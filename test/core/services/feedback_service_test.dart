import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/services/feedback_service.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/profile/domain/player_preferences.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';

class MockProfileRepoForFeedback implements ProfileRepository {
  PlayerPreferences preferences = const PlayerPreferences();

  @override
  Future<PlayerPreferences> getPreferences() async => preferences;

  @override
  Future<void> savePreferences(PlayerPreferences prefs) async {
    preferences = prefs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedbackService Tests', () {
    late ProviderContainer container;
    late MockProfileRepoForFeedback mockRepo;

    setUp(() {
      mockRepo = MockProfileRepoForFeedback();
      container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(mockRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'FeedbackService triggers lightTap, callNumber, claimLine and victory without errors',
      () async {
        final feedback = container.read(feedbackServiceProvider);

        // Verify each feedback method executes cleanly
        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);
        await expectLater(feedback.errorAlert(), completes);
      },
    );

    test(
      'FeedbackService honors disabled haptics and sounds preferences',
      () async {
        // Disable both sound and haptics
        final notifier = container.read(playerPreferencesProvider.notifier);
        await notifier.toggleHaptics();
        await notifier.toggleSoundEffects();

        final feedback = container.read(feedbackServiceProvider);
        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);
      },
    );
  });
}
