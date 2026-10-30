import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/authentication/presentation/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createAuthScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: AuthScreen(),
      ),
    );
  }

  testWidgets('AuthScreen renders welcome headers, logo, and mini preview board', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    expect(find.text('WELCOME TO BINGO'), findsOneWidget);
    expect(find.text("Let's get you started!"), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('CONTINUE AS GUEST'), findsOneWidget);

    // Verify miniature board preview cells are rendered
    expect(find.text('08'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
    expect(find.text('07'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('AuthScreen toggles between Create Account and Sign In views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    // In register view, 'YOUR NAME' is visible
    expect(find.text('YOUR NAME'), findsOneWidget);

    // Tap 'Sign In' in the segmented switcher
    final signInTab = find.text('Sign In').first;
    await tester.tap(signInTab);
    await tester.pumpAndSettle();

    // Verify Sign In view headers
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
