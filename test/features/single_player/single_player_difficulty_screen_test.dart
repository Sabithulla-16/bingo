import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/features/single_player/difficulty/single_player_difficulty_screen.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createDifficultyScreen(WidgetRefCallback? onRef) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          onRef?.call(ref);
          return const MaterialApp(
            home: SinglePlayerDifficultyScreen(),
          );
        },
      ),
    );
  }

  testWidgets('SinglePlayerDifficultyScreen renders Easy, Medium, Hard and changes selection', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    WidgetRef? capturedRef;

    await tester.pumpWidget(createDifficultyScreen((ref) {
      capturedRef = ref;
    }));
    await tester.pumpAndSettle();

    expect(find.text('Select Difficulty'), findsOneWidget);
    expect(find.text('Choose your challenge'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('BINGO BOT'), findsOneWidget);
    expect(find.text('CONTINUE TO BOARD PREP'), findsOneWidget);

    // Initial default is Medium
    expect(capturedRef!.read(selectedDifficultyProvider), equals(AiDifficulty.medium));

    // Tap Hard
    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();

    expect(capturedRef!.read(selectedDifficultyProvider), equals(AiDifficulty.hard));

    // Tap Easy
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    expect(capturedRef!.read(selectedDifficultyProvider), equals(AiDifficulty.easy));
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
