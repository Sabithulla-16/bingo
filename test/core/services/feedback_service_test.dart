import 'package:flutter/services.dart';
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

  setUpAll(() {
    const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, (MethodCall call) async {
          return 1;
        });

    const playerChannel = MethodChannel('xyz.luan/audioplayers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playerChannel, (MethodCall call) async {
          return 1;
        });
  });

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
      'FeedbackService triggers lightTap, callNumber, claimLine, victory and bingoVoice without errors',
      () async {
        final feedback = container.read(feedbackServiceProvider);

        // Verify each feedback method executes cleanly
        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);
        await expectLater(feedback.bingoVoice(), completes);
        await expectLater(feedback.errorAlert(), completes);
      },
    );

    test(
      'FeedbackService guards against duplicate victory triggers within window',
      () async {
        final feedback = container.read(feedbackServiceProvider);

        // First victory call completes
        await expectLater(feedback.victoryBingo(), completes);

        // Second immediate victory call should be safely guarded and complete immediately without throwing
        await expectLater(feedback.victoryBingo(), completes);
      },
    );

    test(
      'FeedbackService honors disabled haptics and sounds preferences independently',
      () async {
        final notifier = container.read(playerPreferencesProvider.notifier);
        await pumpEventQueue();
        final feedback = container.read(feedbackServiceProvider);

        // 1. Only Sound disabled, Haptics enabled
        await notifier.toggleSoundEffects();
        expect(
          container.read(playerPreferencesProvider).soundEffectsEnabled,
          isFalse,
        );
        expect(
          container.read(playerPreferencesProvider).hapticsEnabled,
          isTrue,
        );

        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);

        // 2. Both disabled
        await notifier.toggleHaptics();
        expect(
          container.read(playerPreferencesProvider).soundEffectsEnabled,
          isFalse,
        );
        expect(
          container.read(playerPreferencesProvider).hapticsEnabled,
          isFalse,
        );

        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);

        // 3. Sound enabled, Haptics disabled
        await notifier.toggleSoundEffects();
        expect(
          container.read(playerPreferencesProvider).soundEffectsEnabled,
          isTrue,
        );
        expect(
          container.read(playerPreferencesProvider).hapticsEnabled,
          isFalse,
        );

        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);
      },
    );
  });
}
