import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/widgets/bingo_progress_letters.dart';

void main() {
  group('BingoProgressLetters Widget Tests', () {
    testWidgets('renders all 5 letters B, I, N, G, O', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BingoProgressLetters(claimedCount: 2)),
        ),
      );

      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('O'), findsOneWidget);
    });
  });
}
