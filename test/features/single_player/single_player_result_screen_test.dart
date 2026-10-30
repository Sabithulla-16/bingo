import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/ai_decision_engine.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';
import 'package:bingo/features/single_player/result/single_player_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SinglePlayerResultScreen renders VICTORY header and match stats', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final board = BingoBoard(List<int>.generate(25, (i) => i + 1));

    container.read(singlePlayerGameProvider.notifier).initMatch(
          gameId: 'game_res_1',
          difficulty: AiDifficulty.hard,
          playerBoard: board,
        );

    // Set player as winner
    final notifier = container.read(singlePlayerGameProvider.notifier);
    notifier.state = notifier.state!.copyWith(
      winner: GameWinner.player,
      playerClaimedLineIds: {'row_0', 'row_1', 'row_2', 'row_3', 'row_4'},
      calledNumbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SinglePlayerResultScreen(gameId: 'game_res_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCH VICTORY'), findsOneWidget);
    expect(find.text('VICTORY!'), findsOneWidget);
    expect(find.textContaining('You successfully claimed 5 lines'), findsOneWidget);
    expect(find.text('TOTAL CALLS'), findsOneWidget);
    expect(find.text('18 Balls'), findsOneWidget);
    expect(find.text('YOUR LINES'), findsOneWidget);
    expect(find.text('5 Lines'), findsOneWidget);
    expect(find.text('DIFFICULTY'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('RETURN TO HOME'), findsOneWidget);
  });
}
