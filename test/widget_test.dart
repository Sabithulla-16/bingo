import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bingo/app/bingo_app.dart';

void main() {
  testWidgets('BingoApp initializes without crashing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: BingoApp(),
      ),
    );

    // Initial frame builds MaterialApp and router
    await tester.pump();
    expect(find.byType(BingoApp), findsOneWidget);

    // Advance clock past the splash session timer to complete navigation
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
  });
}
