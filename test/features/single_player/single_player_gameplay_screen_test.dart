import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/single_player/gameplay/single_player_gameplay_screen.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SinglePlayerGameplayScreen renders HUD, You vs Bot, and interactive cells', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer(
      overrides: [
        singlePlayerGameProvider.overrideWith(
          (ref) => SinglePlayerGameNotifier(computerResponseDelay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    final playerBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));

    container.read(singlePlayerGameProvider.notifier).initMatch(
          gameId: 'game_123',
          difficulty: AiDifficulty.medium,
          playerBoard: playerBoard,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SinglePlayerGameplayScreen(gameId: 'game_123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BINGO'), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('BOT'), findsOneWidget);
    expect(find.text('YOUR TURN'), findsOneWidget);
    expect(find.text('CALLED NUMBERS'), findsOneWidget);

    // Call number 01 by tapping cell '01'
    final cell1 = find.text('01').first;
    await tester.tap(cell1);
    await tester.pumpAndSettle();

    // Verify 01 was added to called numbers
    expect(container.read(singlePlayerGameProvider)!.calledNumbers, contains(1));
  });

  testWidgets('Line Claim panel appears and allows claiming completed line', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer(
      overrides: [
        singlePlayerGameProvider.overrideWith(
          (ref) => SinglePlayerGameNotifier(computerResponseDelay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    final playerBoard = BingoBoard(List<int>.generate(25, (i) => i + 1));

    container.read(singlePlayerGameProvider.notifier).initMatch(
          gameId: 'game_123',
          difficulty: AiDifficulty.medium,
          playerBoard: playerBoard,
        );

    // Call numbers 1, 2, 3, 4, 5 (Row 0 complete)
    final notifier = container.read(singlePlayerGameProvider.notifier);
    notifier.state = notifier.state!.copyWith(
      calledNumbers: [1, 2, 3, 4, 5],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SinglePlayerGameplayScreen(gameId: 'game_123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Claim Panel appears
    expect(find.textContaining('COMPLETED LINES (1 READY)'), findsOneWidget);
    expect(find.text('CLAIM ✦'), findsOneWidget);

    // Tap CLAIM ✦
    await tester.tap(find.text('CLAIM ✦'));
    await tester.pumpAndSettle();

    // Verify letter 'B' is awarded
    expect(container.read(singlePlayerGameProvider)!.playerClaimedLineIds, contains('row_0'));
  });
}
