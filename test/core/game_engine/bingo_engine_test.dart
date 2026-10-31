import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/game_engine/bingo_board.dart';
import 'package:bingo/core/game_engine/bingo_engine.dart';
import 'package:bingo/core/game_engine/board_coordinate.dart';
import 'package:bingo/core/widgets/bingo_cell.dart';

void main() {
  group('BingoEngine Core Game Rules & Invariants', () {
    late BingoBoard standardBoard;

    setUp(() {
      // Create a deterministic 5x5 board:
      //  1  2  3  4  5   (Row 0)
      //  6  7  8  9 10   (Row 1)
      // 11 12 13 14 15   (Row 2 - center is 13)
      // 16 17 18 19 20   (Row 3)
      // 21 22 23 24 25   (Row 4)
      final numbers = List<int>.generate(25, (i) => i + 1);
      standardBoard = BingoBoard(numbers);
    });

    test(
      'STRICT OVERLAPPING LINE INVARIANT: Shared cell (2, 2) never invalidates other intersecting lines',
      () {
        // 1. Complete Main Diagonal (1, 7, 13, 19, 25)
        var called = <int>{1, 7, 13, 19, 25};
        var claimed = <String>{};

        var engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(engine.completedLines.length, equals(1));
        expect(engine.completedLines.first.id, equals('diag_main'));
        expect(engine.hasUnclaimedLines, isTrue);

        // Claim diag_main -> awards 'B'
        claimed = engine.claimLine('diag_main');
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(engine.claimedLinesCount, equals(1));
        expect(engine.claimedLetters, equals(['B']));
        expect(engine.hasBingo, isFalse);

        // 2. Complete Row 2: 11, 12, 13, 14, 15 (note 13 is shared with already-claimed diag_main)
        called = {...called, 11, 12, 14, 15};
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        // CRITICAL: Row 2 MUST be complete and claimable even though cell 13 was claimed in diag_main
        expect(
          engine.isLineComplete(
            engine.completedLines.firstWhere((l) => l.id == 'row_2'),
          ),
          isTrue,
        );
        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('row_2'),
        );

        // Claim row_2 -> awards 'I'
        claimed = engine.claimLine('row_2');
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(engine.claimedLinesCount, equals(2));
        expect(engine.claimedLetters, equals(['B', 'I']));

        // 3. Complete Column 2: 3, 8, 13, 18, 23 (13 is shared with both diag_main and row_2)
        called = {...called, 3, 8, 18, 23};
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('col_2'),
        );
        claimed = engine.claimLine('col_2');
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(engine.claimedLinesCount, equals(3));
        expect(engine.claimedLetters, equals(['B', 'I', 'N']));

        // 4. Complete Anti Diagonal: 5, 9, 13, 17, 21 (13 is shared with all previous 3 lines)
        called = {...called, 5, 9, 17, 21};
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('diag_anti'),
        );
        claimed = engine.claimLine('diag_anti');
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(engine.claimedLinesCount, equals(4));
        expect(engine.claimedLetters, equals(['B', 'I', 'N', 'G']));

        // 5. Complete Row 0 (1, 2, 3, 4, 5) -> call remaining 2 and 4
        called = {...called, 2, 4};
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          contains('row_0'),
        );
        claimed = engine.claimLine('row_0');
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: claimed,
        );

        // VICTORY: 5 claimed lines achieves B-I-N-G-O!
        expect(engine.claimedLinesCount, equals(5));
        expect(engine.claimedLetters, equals(['B', 'I', 'N', 'G', 'O']));
        expect(engine.hasBingo, isTrue);
        expect(engine.isDraw, isFalse);
      },
    );

    test(
      'Simultaneous multi-line completion and batch claimAllCompletedLines',
      () {
        // Mark all cells in row 2 and col 2 EXCEPT center 13
        final called = <int>{
          11, 12, 14, 15, // Row 2 except 13
          3, 8, 18, 23, // Col 2 except 13
        };

        var engine = BingoEngine(
          board: standardBoard,
          calledNumbers: called,
          claimedLineIds: {},
        );

        expect(engine.completedLines, isEmpty);

        // Now call center number 13 -> completes BOTH row_2 and col_2 simultaneously!
        final updatedCalls = {...called, 13};
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: updatedCalls,
          claimedLineIds: {},
        );

        expect(engine.completedLines.length, equals(2));
        expect(engine.unclaimedCompletedLines.length, equals(2));
        expect(
          engine.unclaimedCompletedLines.map((l) => l.id),
          containsAll(['row_2', 'col_2']),
        );

        // Claim all at once
        final claimedAll = engine.claimAllCompletedLines();
        expect(claimedAll.length, equals(2));
        expect(claimedAll, containsAll(['row_2', 'col_2']));
      },
    );

    test(
      'cellVisualState accurately transitions between available, called, completedUnclaimed, and claimed',
      () {
        // Initially, all cells are available
        var engine = BingoEngine(
          board: standardBoard,
          calledNumbers: {},
          claimedLineIds: {},
        );

        expect(
          engine.cellVisualState(const BoardCoordinate(0, 0)),
          equals(BingoCellState.available),
        );

        // Call number 1 at (0, 0)
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: {1},
          claimedLineIds: {},
        );

        expect(
          engine.cellVisualState(const BoardCoordinate(0, 0)),
          equals(BingoCellState.called),
        );

        // Complete Row 0 (1, 2, 3, 4, 5) without claiming
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: {1, 2, 3, 4, 5},
          claimedLineIds: {},
        );

        expect(
          engine.cellVisualState(const BoardCoordinate(0, 0)),
          equals(BingoCellState.completedUnclaimed),
        );
        expect(
          engine.cellVisualState(const BoardCoordinate(0, 4)),
          equals(BingoCellState.completedUnclaimed),
        );

        // Claim Row 0
        engine = BingoEngine(
          board: standardBoard,
          calledNumbers: {1, 2, 3, 4, 5},
          claimedLineIds: {'row_0'},
        );

        expect(
          engine.cellVisualState(const BoardCoordinate(0, 0)),
          equals(BingoCellState.claimed),
        );
        expect(
          engine.cellVisualState(const BoardCoordinate(0, 4)),
          equals(BingoCellState.claimed),
        );
        // Cell (1, 0) not called
        expect(
          engine.cellVisualState(const BoardCoordinate(1, 0)),
          equals(BingoCellState.available),
        );
      },
    );

    test(
      'isDraw is true when all 25 numbers are called and player has fewer than 5 lines',
      () {
        final all25 = List<int>.generate(25, (i) => i + 1).toSet();

        // Only 3 lines claimed
        final engine = BingoEngine(
          board: standardBoard,
          calledNumbers: all25,
          claimedLineIds: {'row_0', 'row_1', 'row_2'},
        );

        expect(engine.claimedLinesCount, equals(3));
        expect(engine.hasBingo, isFalse);
        expect(engine.isDraw, isTrue);
      },
    );

    test(
      'claimLine throws StateError if line is not complete or already claimed',
      () {
        final engine = BingoEngine(
          board: standardBoard,
          calledNumbers: {1, 2, 3}, // Incomplete Row 0
          claimedLineIds: {},
        );

        expect(() => engine.claimLine('row_0'), throwsA(isA<StateError>()));
      },
    );
  });
}
