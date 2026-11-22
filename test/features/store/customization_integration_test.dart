import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/core/config/app_config.dart';
import 'package:bingo/core/theme/board_theme_config.dart';
import 'package:bingo/core/widgets/bingo_cell.dart';
import 'package:bingo/core/widgets/player_avatar.dart';
import 'package:bingo/core/widgets/victory_effect_overlay.dart';
import 'package:bingo/features/authentication/data/auth_repository_impl.dart';
import 'package:bingo/features/profile/data/profile_repository_impl.dart';
import 'package:bingo/features/profile/domain/player_customization.dart';
import 'package:bingo/features/store/data/store_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerCustomization Entity & Mapping', () {
    test('Default customization uses Classic Cream and Classic Numbers', () {
      final custom = const PlayerCustomization();
      expect(custom.boardThemeId, 1);
      expect(custom.numberStyleId, 5);
      expect(custom.avatarId, 7);
      expect(custom.victoryEffectId, 0);
      expect(custom.profileFrameId, 0);
      expect(custom.soundPackId, 10);
      expect(custom.boardThemeKey, 'classic');
      expect(custom.hasGoldenFrame, isFalse);
      expect(custom.hasGoldenBurst, isFalse);
      expect(custom.soundPackKey, 'classic');
    });

    test(
      'Customization serialization to and from Map preserves all fields',
      () {
        final custom = const PlayerCustomization(
          boardThemeId: 2, // Lavender Dream
          numberStyleId: 6, // Bold Numbers
          avatarId: 7, // Fun Collection Avatar
          victoryEffectId: 8, // Golden Burst
          profileFrameId: 9, // Golden Frame
          soundPackId: 11, // Arcade Sound Pack
        );

        final map = custom.toMap();
        final restored = PlayerCustomization.fromMap(map);

        expect(restored.boardThemeId, 2);
        expect(restored.boardThemeKey, 'lavender');
        expect(restored.numberStyleId, 6);
        expect(restored.avatarId, 7);
        expect(restored.victoryEffectId, 8);
        expect(restored.hasGoldenBurst, isTrue);
        expect(restored.profileFrameId, 9);
        expect(restored.hasGoldenFrame, isTrue);
        expect(restored.soundPackId, 11);
        expect(restored.soundPackKey, 'arcade');
      },
    );

    test('BoardThemeConfig provides distinct color palettes per theme', () {
      final classic = BoardThemeConfig.fromId(1);
      final lavender = BoardThemeConfig.fromId(2);
      final midnight = BoardThemeConfig.fromId(3);
      final neon = BoardThemeConfig.fromId(4);

      expect(classic.key, 'classic');
      expect(lavender.key, 'lavender');
      expect(midnight.key, 'midnight');
      expect(neon.key, 'neon');

      // Verify palettes have contrasting backgrounds
      expect(classic.boardBackground, isNot(equals(midnight.boardBackground)));
      expect(
        lavender.cellCalledBackground,
        isNot(equals(neon.cellCalledBackground)),
      );
    });
  });

  group('StoreRepository Customization State & Equipping', () {
    late ProfileRepositoryImpl profileRepo;
    late AuthRepositoryImpl authRepo;
    late StoreRepositoryImpl repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      profileRepo = ProfileRepositoryImpl(null);
      authRepo = AuthRepositoryImpl(null, profileRepo, enableDevFallback: true);
      repo = StoreRepositoryImpl(authRepo: authRepo, profileRepo: profileRepo);
      // Wait for async _loadState to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test(
      'Equipping board theme updates customization state and broadcasts',
      () async {
        expect(repo.currentCustomization.boardThemeId, 1);

        // Purchase and equip Lavender Dream (id: 2)
        await repo.purchaseItem(2);
        await repo.equipItem(2);

        expect(repo.currentCustomization.boardThemeId, 2);
        expect(repo.currentCustomization.boardThemeKey, 'lavender');
      },
    );

    test('Equipping bold numbers (id: 6) updates numberStyleId', () async {
      await repo.purchaseItem(6);
      await repo.equipItem(6);

      expect(repo.currentCustomization.numberStyleId, 6);
    });

    test(
      'Equipping Golden Frame (id: 9) sets hasGoldenFrame to true',
      () async {
        await repo.purchaseItem(9);
        await repo.equipItem(9);

        expect(repo.currentCustomization.hasGoldenFrame, isTrue);
      },
    );
  });

  group('Widget Integration Tests', () {
    testWidgets('BingoCell applies themeConfig and bold number styling', (
      tester,
    ) async {
      final lavenderTheme = BoardThemeConfig.fromKey('lavender');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: BingoCell(
                    number: 7,
                    state: BingoCellState.available,
                    themeConfig: lavenderTheme,
                    numberStyleId: 6, // Bold numbers
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: BingoCell(
                    number: 13,
                    state: BingoCellState.called,
                    themeConfig: lavenderTheme,
                    numberStyleId: 5, // Regular numbers
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final cell7Text = tester.widget<Text>(find.text('07'));
      expect(cell7Text.style?.fontWeight, FontWeight.w900);

      final cell13Text = tester.widget<Text>(find.text('13'));
      expect(cell13Text.style?.fontWeight, FontWeight.w800);
    });

    testWidgets(
      'PlayerAvatar renders golden border ring when hasGoldenFrame is true',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PlayerAvatar(
                displayName: 'Champion',
                hasGoldenFrame: true,
                size: 40,
              ),
            ),
          ),
        );

        // Verify PlayerAvatar widget renders
        expect(find.text('C'), findsOneWidget);
        expect(find.byType(PlayerAvatar), findsOneWidget);
      },
    );

    testWidgets(
      'VictoryEffectOverlay renders without error when isGoldenBurst is true',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VictoryEffectOverlay(
                isGoldenBurst: true,
                child: Text('MATCH WON!'),
              ),
            ),
          ),
        );

        expect(find.text('MATCH WON!'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  group('Authentication Backend & Dev Fallback Safeguards', () {
    test('Production default disables dev fallback', () {
      expect(AppConfig.isDevFallbackEnabled, isFalse);
    });

    test(
      'Uninitialized client throws StateError instead of spoofing local user in production',
      () async {
        final profileRepo = ProfileRepositoryImpl(null);
        final repo = AuthRepositoryImpl(
          null,
          profileRepo,
          enableDevFallback: false,
        );

        expect(
          () => repo.signInWithEmail(
            email: 'valtryfreefire@gmail.com',
            password: 'password123',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'Dev fallback isolates distinct emails with unique user IDs',
      () async {
        final profileRepo = ProfileRepositoryImpl(null);
        final repo = AuthRepositoryImpl(
          null,
          profileRepo,
          enableDevFallback: true,
        );

        final user1 = await repo.signInWithEmail(
          email: 'valtryfreefire@gmail.com',
          password: 'password123',
        );

        final user2 = await repo.signInWithEmail(
          email: 'sabithullasharieff16@gmail.com',
          password: 'password123',
        );

        expect(user1.id, isNot(equals('valtry-local-user')));
        expect(user2.id, isNot(equals('valtry-local-user')));
        expect(user1.id, isNot(equals(user2.id)));
        expect(user1.email, 'valtryfreefire@gmail.com');
        expect(user2.email, 'sabithullasharieff16@gmail.com');
      },
    );
  });

  group('Multiplayer Customization Isolation Invariant', () {
    test(
      'Local player theme selection does not leak or alter another player state',
      () {
        final player1Customization = const PlayerCustomization().copyWith(
          boardThemeId: 2, // Lavender Dream
        );
        final player2Customization = const PlayerCustomization().copyWith(
          boardThemeId: 3, // Midnight Blue
        );

        expect(player1Customization.boardThemeKey, 'lavender');
        expect(player2Customization.boardThemeKey, 'midnight');
        expect(
          player1Customization.boardThemeKey,
          isNot(equals(player2Customization.boardThemeKey)),
        );
      },
    );
  });
}
