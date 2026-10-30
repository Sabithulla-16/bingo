import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/widgets/bingo_logo.dart';
import 'package:bingo/core/constants/app_constants.dart';

void main() {
  group('BingoLogo Widget Tests', () {
    testWidgets('renders all five letters of B-I-N-G-O', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BingoLogo(fontSize: 32))),
      );

      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('renders tagline when showTagline is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BingoLogo(fontSize: 32, showTagline: true)),
        ),
      );

      expect(find.text(AppConstants.appTagline.toUpperCase()), findsOneWidget);
    });
  });
}
