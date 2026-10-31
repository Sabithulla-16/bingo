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
    return const ProviderScope(child: MaterialApp(home: AuthScreen()));
  }

  testWidgets(
    'AuthScreen renders welcome headers, logo, and mini preview board',
    (WidgetTester tester) async {
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
    },
  );

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

  testWidgets(
    'AuthScreen opens Terms of Service and Privacy Policy dialogs on tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAuthScreen());
      await tester.pumpAndSettle();

      // Tap on Terms of Service link
      final termsLink = find.text('Terms of Service');
      expect(termsLink, findsOneWidget);
      await tester.tap(termsLink);
      await tester.pumpAndSettle();

      // Verify dialog is opened
      expect(find.text('1. Fair Play & Gameplay Integrity'), findsOneWidget);
      expect(find.text('I Understand'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('I Understand'));
      await tester.pumpAndSettle();
      expect(find.text('1. Fair Play & Gameplay Integrity'), findsNothing);

      // Tap on Privacy Policy link
      final privacyLink = find.text('Privacy Policy');
      expect(privacyLink, findsOneWidget);
      await tester.tap(privacyLink);
      await tester.pumpAndSettle();

      // Verify privacy policy dialog
      expect(find.text('1. Information We Collect'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('1. Information We Collect'), findsNothing);
    },
  );

  testWidgets(
    'AuthScreen displays rate limit and inbox instructions on forgot password submit',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAuthScreen());
      await tester.pumpAndSettle();

      // Switch to Sign In
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();

      // Switch to Forgot Password
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset your password'), findsOneWidget);

      // Enter valid email
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your email'),
        'player@bingo.app',
      );
      await tester.pumpAndSettle();

      // Tap Send Reset Link
      await tester.tap(find.text('SEND RESET LINK'));
      await tester.pumpAndSettle();

      // Verify dispatched instructions with rate limit warning
      expect(find.text('Instructions Dispatched'), findsOneWidget);
      expect(find.textContaining('Rate limit notice'), findsOneWidget);
    },
  );
}
