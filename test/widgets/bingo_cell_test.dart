import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/widgets/bingo_cell.dart';

void main() {
  group('BingoCell Widget Tests', () {
    testWidgets('renders 2-digit formatted number with leading zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BingoCell(number: 7))),
      );

      expect(find.text('07'), findsOneWidget);
    });

    testWidgets('renders numbers >= 10 without leading zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BingoCell(number: 23))),
      );

      expect(find.text('23'), findsOneWidget);
    });

    testWidgets('triggers onTap callback when interactive', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BingoCell(
              number: 14,
              isInteractive: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BingoCell));
      expect(tapped, isTrue);
    });

    testWidgets('supports all four cell presentation states without error', (
      tester,
    ) async {
      for (final state in BingoCellState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BingoCell(number: 10, state: state)),
          ),
        );
        expect(find.text('10'), findsOneWidget);
      }
    });
  });
}
