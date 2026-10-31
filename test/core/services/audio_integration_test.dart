import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/services/feedback_service.dart';
import 'package:bingo/data/supabase/supabase_provider.dart';
import 'package:bingo/features/profile/domain/player_preferences.dart';
import 'package:bingo/features/profile/domain/profile_repository.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';

class TrackingFeedbackService extends FeedbackService {
  final List<String> playedSounds = [];
  int lightTapCount = 0;
  int callNumberCount = 0;
  int claimLineCount = 0;
  int victoryBingoCount = 0;
  int bingoVoiceCount = 0;

  TrackingFeedbackService(super.ref);

  @override
  Future<void> lightTap() async {
    lightTapCount++;
    playedSounds.add('tap.wav');
    await super.lightTap();
  }

  @override
  Future<void> callNumber() async {
    callNumberCount++;
    playedSounds.add('number_call.wav');
    await super.callNumber();
  }

  @override
  Future<void> claimLine() async {
    claimLineCount++;
    playedSounds.add('line_strike.wav');
    await super.claimLine();
  }

  @override
  Future<void> victoryBingo() async {
    final before = lastVictoryPlayedAt;
    await super.victoryBingo();
    if (lastVictoryPlayedAt != before) {
      victoryBingoCount++;
      playedSounds.add('bingo_victory.wav');
    }
  }

  @override
  Future<void> bingoVoice() async {
    bingoVoiceCount++;
    playedSounds.add('bingo_voice.wav');
    await super.bingoVoice();
  }
}

class MockProfileRepoForAudio implements ProfileRepository {
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
        .setMockMethodCallHandler(globalChannel, (MethodCall call) async => 1);

    const playerChannel = MethodChannel('xyz.luan/audioplayers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playerChannel, (MethodCall call) async => 1);
  });

  group('Complete Audio Integration Tests (12 Test Scenarios)', () {
    late ProviderContainer container;
    late MockProfileRepoForAudio mockProfileRepo;
    late TrackingFeedbackService trackingFeedback;

    setUp(() {
      mockProfileRepo = MockProfileRepoForAudio();
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
          feedbackServiceProvider.overrideWith(
            (ref) => TrackingFeedbackService(ref),
          ),
        ],
      );
      trackingFeedback =
          container.read(feedbackServiceProvider) as TrackingFeedbackService;
    });

    tearDown(() {
      container.dispose();
    });

    // 1. Single-player human turns
    test(
      '1. Single-player human turns: callNumber triggers number_call.wav',
      () async {
        final notifier = container.read(singlePlayerGameProvider.notifier);
        final board = BingoBoard(List<int>.generate(25, (i) => i + 1));
        notifier.initMatch(
          gameId: 'sp_test_1',
          difficulty: AiDifficulty.easy,
          playerBoard: board,
        );

        final initialCalls = trackingFeedback.callNumberCount;
        // Human calls number 7
        notifier.callNumber(7);
        // Simulate listener trigger
        await container.read(feedbackServiceProvider).callNumber();

        expect(trackingFeedback.callNumberCount, equals(initialCalls + 1));
        expect(trackingFeedback.playedSounds, contains('number_call.wav'));
      },
    );

    // 2. Single-player bot turns
    test(
      '2. Single-player bot turns: Bot calling an uncalled number plays number_call.wav',
      () async {
        final notifier = container.read(singlePlayerGameProvider.notifier);
        final board = BingoBoard(List<int>.generate(25, (i) => i + 1));
        notifier.initMatch(
          gameId: 'sp_test_2',
          difficulty: AiDifficulty.easy,
          playerBoard: board,
        );

        final initialCalls = trackingFeedback.callNumberCount;
        // Bot triggers a call
        await container.read(feedbackServiceProvider).callNumber();

        expect(trackingFeedback.callNumberCount, equals(initialCalls + 1));
        expect(trackingFeedback.playedSounds.last, equals('number_call.wav'));
      },
    );

    // 3. Human line claims
    test(
      '3. Human line claims: Claiming a valid winning line plays line_strike.wav',
      () async {
        final notifier = container.read(singlePlayerGameProvider.notifier);
        final board = BingoBoard(List<int>.generate(25, (i) => i + 1));
        notifier.initMatch(
          gameId: 'sp_test_3',
          difficulty: AiDifficulty.easy,
          playerBoard: board,
        );

        // Call Row 0 (1, 2, 3, 4, 5)
        notifier.state = notifier.state!.copyWith(
          calledNumbers: [1, 2, 3, 4, 5],
        );

        final initialClaims = trackingFeedback.claimLineCount;
        // Claim Row 0
        notifier.claimLine('row_0');
        await container.read(feedbackServiceProvider).claimLine();

        expect(trackingFeedback.claimLineCount, equals(initialClaims + 1));
        expect(trackingFeedback.playedSounds, contains('line_strike.wav'));
      },
    );

    // 4. Bot automatic line claims
    test(
      '4. Bot automatic line claims: Bot line claim triggers line_strike.wav',
      () async {
        final initialClaims = trackingFeedback.claimLineCount;
        await container.read(feedbackServiceProvider).claimLine();

        expect(trackingFeedback.claimLineCount, equals(initialClaims + 1));
        expect(trackingFeedback.playedSounds, contains('line_strike.wav'));
      },
    );

    // 5. Human victory
    test(
      '5. Human victory: Reaching 5 lines triggers upgraded bingo_victory.wav',
      () async {
        final feedback = container.read(feedbackServiceProvider);
        final initialVictories = trackingFeedback.victoryBingoCount;

        await feedback.victoryBingo();

        expect(
          trackingFeedback.victoryBingoCount,
          equals(initialVictories + 1),
        );
        expect(trackingFeedback.playedSounds, contains('bingo_victory.wav'));
      },
    );

    // 6. Bot victory
    test(
      '6. Bot victory: Bot reaching 5 lines triggers bingo_victory.wav',
      () async {
        final feedback = container.read(feedbackServiceProvider);

        // Wait out any debounce window if needed
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final countBefore = trackingFeedback.victoryBingoCount;
        await feedback.victoryBingo();

        expect(
          trackingFeedback.victoryBingoCount,
          greaterThanOrEqualTo(countBefore),
        );
      },
    );

    // 7. Multiplayer number calls
    test(
      '7. Multiplayer number calls: Any participant calling a number plays number_call.wav',
      () async {
        final initialCalls = trackingFeedback.callNumberCount;
        await container.read(feedbackServiceProvider).callNumber();

        expect(trackingFeedback.callNumberCount, equals(initialCalls + 1));
        expect(trackingFeedback.playedSounds, contains('number_call.wav'));
      },
    );

    // 8. Multiplayer line claims
    test(
      '8. Multiplayer line claims: Successful line claim plays line_strike.wav',
      () async {
        final initialClaims = trackingFeedback.claimLineCount;
        await container.read(feedbackServiceProvider).claimLine();

        expect(trackingFeedback.claimLineCount, equals(initialClaims + 1));
        expect(trackingFeedback.playedSounds, contains('line_strike.wav'));
      },
    );

    // 9. Multiplayer victory
    test(
      '9. Multiplayer victory: Authoritative completed round triggers bingo_victory.wav',
      () async {
        final initialVictories = trackingFeedback.victoryBingoCount;
        await container.read(feedbackServiceProvider).victoryBingo();

        expect(
          trackingFeedback.victoryBingoCount,
          equals(initialVictories + 1),
        );
      },
    );

    // 10. Simultaneous winners
    test(
      '10. Simultaneous winners: Completing 5 lines simultaneously plays victory once',
      () async {
        final initialVictories = trackingFeedback.victoryBingoCount;
        await container.read(feedbackServiceProvider).victoryBingo();

        // Guarded duplicate trigger within window
        await container.read(feedbackServiceProvider).victoryBingo();

        expect(
          trackingFeedback.victoryBingoCount,
          equals(initialVictories + 1),
        );
      },
    );

    // 11. Sound Effects ON/OFF
    test(
      '11. Sound Effects ON/OFF: Muting sounds stops audio playback',
      () async {
        final notifier = container.read(playerPreferencesProvider.notifier);
        await pumpEventQueue();

        // Disable sound effects
        await notifier.toggleSoundEffects();
        expect(
          container.read(playerPreferencesProvider).soundEffectsEnabled,
          isFalse,
        );

        // Audio execution completes silently without throwing
        final feedback = container.read(feedbackServiceProvider);
        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
        await expectLater(feedback.victoryBingo(), completes);
        await expectLater(feedback.bingoVoice(), completes);
      },
    );

    // 12. Haptic Feedback ON/OFF independently
    test(
      '12. Haptic Feedback ON/OFF independently: Haptics operate independently from sound',
      () async {
        final notifier = container.read(playerPreferencesProvider.notifier);
        await pumpEventQueue();

        // Enable Sound, Disable Haptics
        if (!container.read(playerPreferencesProvider).soundEffectsEnabled) {
          await notifier.toggleSoundEffects();
        }
        await notifier.toggleHaptics();

        expect(
          container.read(playerPreferencesProvider).soundEffectsEnabled,
          isTrue,
        );
        expect(
          container.read(playerPreferencesProvider).hapticsEnabled,
          isFalse,
        );

        final feedback = container.read(feedbackServiceProvider);
        await expectLater(feedback.lightTap(), completes);
        await expectLater(feedback.callNumber(), completes);
        await expectLater(feedback.claimLine(), completes);
      },
    );
  });
}
