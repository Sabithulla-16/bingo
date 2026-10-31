import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/errors/app_error_code.dart';
import 'package:bingo/core/errors/app_error.dart';
import 'package:bingo/core/widgets/app_error_dialog.dart';
import 'package:bingo/core/widgets/app_error_banner.dart';
import 'package:bingo/core/widgets/global_error_boundary.dart';

void main() {
  group('AppErrorDialog Tests', () {
    testWidgets('renders dialog with user-friendly message and actions', (
      WidgetTester tester,
    ) async {
      bool recoveryTriggered = false;

      final error = AppError(
        code: AppErrorCode.networkUnavailable,
        message:
            'Unable to connect. Check your internet connection and try again.',
        recoveryActionLabel: 'RETRY',
        recoveryAction: () {
          recoveryTriggered = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppErrorDialog.show(context, error: error),
                    child: const Text('SHOW DIALOG'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('SHOW DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('Notice'), findsOneWidget);
      expect(
        find.text(
          'Unable to connect. Check your internet connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('RETRY'), findsOneWidget);
      expect(find.text('DISMISS'), findsOneWidget);

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();

      expect(recoveryTriggered, isTrue);
      expect(find.byType(AppErrorDialog), findsNothing);
    });

    testWidgets('okay button closes dialog when no recovery action', (
      WidgetTester tester,
    ) async {
      final error = AppError(
        code: AppErrorCode.roomFull,
        message: 'This room is currently full.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppErrorDialog.show(context, error: error),
                    child: const Text('SHOW'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('SHOW'));
      await tester.pumpAndSettle();

      expect(find.text('Notice'), findsOneWidget);
      expect(find.text('This room is currently full.'), findsOneWidget);
      expect(find.text('OKAY'), findsOneWidget);

      await tester.tap(find.text('OKAY'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorDialog), findsNothing);
    });
  });

  group('AppErrorBanner Tests', () {
    testWidgets('renders inline banner with message and dismiss action', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorBanner(
              message: 'Invalid room code entered.',
              isDismissible: true,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Invalid room code entered.'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets(
      'AppErrorBanner.connectionLost factory renders connection message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: AppErrorBanner.connectionLost())),
        );

        expect(
          find.text('Connection lost. Trying to reconnect...'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      },
    );
  });

  group('GlobalErrorBoundaryWidget Tests', () {
    testWidgets('renders boundary fallback screen with action button', (
      WidgetTester tester,
    ) async {
      bool resetTriggered = false;

      await tester.pumpWidget(
        GlobalErrorBoundaryWidget(
          onReset: () {
            resetTriggered = true;
          },
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('RELOAD APPLICATION'), findsOneWidget);

      await tester.tap(find.text('RELOAD APPLICATION'));
      await tester.pumpAndSettle();

      expect(resetTriggered, isTrue);
    });
  });
}
