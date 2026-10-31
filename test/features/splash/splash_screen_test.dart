import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/splash/presentation/splash_screen.dart';
import 'package:bingo/features/splash/presentation/widgets/splash_animated_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SplashScreen renders animated board, logo, and loading elements',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SplashScreen())),
      );

      // Initial frame
      await tester.pump();

      // Verify widgets present
      expect(find.byType(SplashAnimatedBingoBoard), findsOneWidget);
      expect(find.text('PICK • MARK • STRIKE • WIN'), findsOneWidget);
      expect(find.text('PREPARING YOUR GAME'), findsOneWidget);
      expect(find.text('Welcome to BINGO'), findsOneWidget);

      // Verify star center icon and numbers on board
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Advance animation forward
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // CustomPaint is actively painting the diagonal strike
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );
}
