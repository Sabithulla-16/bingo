import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bingo/features/authentication/data/auth_repository_impl.dart';
import 'package:bingo/features/authentication/domain/auth_state.dart';
import 'package:bingo/features/profile/data/profile_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository Offline & Guest Tests', () {
    late ProfileRepositoryImpl profileRepo;
    late AuthRepositoryImpl authRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      profileRepo = ProfileRepositoryImpl(null);
      authRepo = AuthRepositoryImpl(null, profileRepo);
    });

    test(
      'signs in as guest and produces valid PlayerProfile with default chips',
      () async {
        final profile = await authRepo.signInAsGuest(displayName: 'TestValtry');

        expect(profile.id.startsWith('guest_'), isTrue);
        expect(profile.displayName, equals('TestValtry'));
        expect(profile.chips, equals(500));
        expect(profile.avatarId, equals('avatar_coral'));
        expect(profile.avatarColorHex, equals('#FC695C'));
      },
    );

    test(
      'signUpWithEmail creates and returns authenticated profile in offline mode',
      () async {
        final profile = await authRepo.signUpWithEmail(
          email: 'player@bingo.app',
          password: 'password123',
          displayName: 'StrikeMaster',
        );

        expect(profile.displayName, equals('StrikeMaster'));
        expect(profile.email, equals('player@bingo.app'));
        expect(profile.chips, equals(500));
      },
    );

    test('signInWithEmail restores user profile', () async {
      final profile = await authRepo.signInWithEmail(
        email: 'valtry@bingo.app',
        password: 'password123',
      );

      expect(profile.displayName, equals('Valtry'));
      expect(profile.email, equals('valtry@bingo.app'));
    });

    test('restoreSession recovers active guest session', () async {
      await authRepo.signInAsGuest(displayName: 'PersistentGuest');
      final restored = await authRepo.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.displayName, equals('PersistentGuest'));
    });

    test(
      'signOut clears active guest session and emits Unauthenticated',
      () async {
        await authRepo.signInAsGuest(displayName: 'GuestUser');

        expectLater(authRepo.authStateChanges, emits(isA<Unauthenticated>()));

        await authRepo.signOut();
        final restored = await authRepo.restoreSession();
        expect(restored, isNull);
      },
    );
  });
}
