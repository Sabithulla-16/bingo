import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/features/single_player/board_preparation/single_player_board_prep_screen.dart';
import 'package:bingo/features/single_player/presentation/single_player_game_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createBoardPrepScreen(WidgetRefCallback? onRef) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          onRef?.call(ref);
          return const MaterialApp(home: SinglePlayerBoardPrepScreen());
        },
      ),
    );
  }

  testWidgets(
    'SinglePlayerBoardPrepScreen renders 5x5 grid, quick shuffle, and status',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      WidgetRef? capturedRef;

      await tester.pumpWidget(
        createBoardPrepScreen((ref) {
          capturedRef = ref;
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Up Your Board'), findsOneWidget);
      expect(find.text('BOARD READY • 25/25 NUMBERS'), findsOneWidget);
      expect(find.text('QUICK SHUFFLE'), findsOneWidget);
      expect(find.text('CLEAR BOARD'), findsOneWidget);
      expect(find.text('CONFIRM & START GAME'), findsOneWidget);

      // Initial board is valid
      final initialNumbers = capturedRef!.read(preparedBoardProvider).numbers;
      expect(initialNumbers.length, equals(25));
      expect(initialNumbers.toSet().length, equals(25));

      // Tap Quick Shuffle
      await tester.tap(find.text('QUICK SHUFFLE'));
      await tester.pumpAndSettle();

      final shuffledNumbers = capturedRef!.read(preparedBoardProvider).numbers;
      expect(shuffledNumbers.length, equals(25));
      expect(shuffledNumbers.toSet().length, equals(25));
    },
  );

  testWidgets('Clear board shows unassigned numbers palette', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createBoardPrepScreen(null));
    await tester.pumpAndSettle();

    // Tap Clear Board
    await tester.tap(find.text('CLEAR BOARD'));
    await tester.pumpAndSettle();

    expect(find.text('25 NUMBERS UNASSIGNED'), findsOneWidget);
    expect(
      find.textContaining('TAP TO PLACE REMAINING NUMBERS'),
      findsOneWidget,
    );
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
