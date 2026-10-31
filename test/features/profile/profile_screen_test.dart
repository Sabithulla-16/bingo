import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/profile/presentation/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createProfileScreen() {
    return const ProviderScope(child: MaterialApp(home: ProfileScreen()));
  }

  testWidgets(
    'ProfileScreen renders user identity, performance metrics, and win rate',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createProfileScreen());
      await tester.pumpAndSettle();

      expect(find.text('PLAYER PROFILE'), findsOneWidget);
      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Valtry'), findsWidgets);
      expect(find.text('BINGO PLAYER'), findsOneWidget);
      expect(find.text('EDIT PROFILE'), findsOneWidget);

      // Performance metrics
      expect(find.text('TOTAL MATCHES'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('WINS'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('WIN RATE'), findsOneWidget);
      expect(find.text('48%'), findsOneWidget);

      // Streaks
      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(find.text('2 WINS'), findsOneWidget);
      expect(find.text('BEST STREAK'), findsOneWidget);
      expect(find.text('5 WINS'), findsOneWidget);

      // Recent Matches
      expect(find.text('Friday BINGO Club'), findsWidgets);
    },
  );

  testWidgets('Tapping EDIT PROFILE opens dialog with avatar palette', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createProfileScreen());
    await tester.pumpAndSettle();

    final editBtn = find.text('EDIT PROFILE');
    await tester.ensureVisible(editBtn);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Choose Avatar Palette'), findsOneWidget);
    expect(find.text('SAVE CHANGES'), findsOneWidget);
  });
}
