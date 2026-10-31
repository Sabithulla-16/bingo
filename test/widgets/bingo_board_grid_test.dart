import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/widgets/bingo_board_grid.dart';
import 'package:bingo/core/widgets/bingo_cell.dart';

void main() {
  group('BingoBoardGrid Widget Tests', () {
    testWidgets('renders exactly 25 BingoCells in 5x5 arrangement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final matrix = List<int>.generate(25, (i) => i + 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: BingoBoardGrid(matrix: matrix),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BingoCell), findsNWidgets(25));
      expect(find.text('01'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('passes called and claimed states correctly to child cells', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final matrix = List<int>.generate(25, (i) => i + 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: BingoBoardGrid(
                  matrix: matrix,
                  calledNumbers: const {5, 10},
                  claimedNumbers: const {5},
                ),
              ),
            ),
          ),
        ),
      );

      final cell5Finder = find.byWidgetPredicate(
        (widget) =>
            widget is BingoCell &&
            widget.number == 5 &&
            widget.state == BingoCellState.claimed,
      );
      final cell10Finder = find.byWidgetPredicate(
        (widget) =>
            widget is BingoCell &&
            widget.number == 10 &&
            widget.state == BingoCellState.called,
      );
      final cell1Finder = find.byWidgetPredicate(
        (widget) =>
            widget is BingoCell &&
            widget.number == 1 &&
            widget.state == BingoCellState.available,
      );

      expect(cell5Finder, findsOneWidget);
      expect(cell10Finder, findsOneWidget);
      expect(cell1Finder, findsOneWidget);
    });
  });
}
