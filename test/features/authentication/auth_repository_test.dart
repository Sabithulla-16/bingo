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
      authRepo = AuthRepositoryImpl(null, profileRepo, enableDevFallback: true);
    });

    test(
      'signs in as guest and produces valid PlayerProfile with AuthGuest state',
      () async {
        expectLater(
          authRepo.authStateChanges,
          emits(isA<AuthGuest>().having((s) => s.isGuest, 'isGuest', isTrue)),
        );

        final profile = await authRepo.signInAsGuest(displayName: 'TestValtry');

        expect(profile.id.startsWith('guest_'), isTrue);
        expect(profile.displayName, equals('TestValtry'));
        expect(profile.chips, equals(500));
        expect(profile.isGuest, isTrue);
        expect(authRepo.isGuest, isTrue);
      },
    );

    test(
      'signUpWithEmail creates and returns authenticated profile with unique ID',
      () async {
        expectLater(
          authRepo.authStateChanges,
          emits(
            isA<Authenticated>().having((s) => s.isGuest, 'isGuest', isFalse),
          ),
        );

        final profile = await authRepo.signUpWithEmail(
          email: 'player@bingo.app',
          password: 'password123',
          displayName: 'StrikeMaster',
        );

        expect(profile.displayName, equals('StrikeMaster'));
        expect(profile.email, equals('player@bingo.app'));
        expect(profile.chips, equals(500));
        expect(profile.isGuest, isFalse);
        expect(authRepo.isGuest, isFalse);
        expect(profile.id, isNot(equals('valtry-local-user')));
      },
    );

    test('signInWithEmail restores user profile as registered user', () async {
      final profile = await authRepo.signInWithEmail(
        email: 'valtry@bingo.app',
        password: 'password123',
      );

      expect(profile.email, equals('valtry@bingo.app'));
      expect(profile.isGuest, isFalse);
      expect(authRepo.isGuest, isFalse);
    });

    test(
      'different emails receive unique IDs and never share valtry-local-user',
      () async {
        final u1 = await authRepo.signInWithEmail(
          email: 'valtryfreefire@gmail.com',
          password: 'password123',
        );
        final u2 = await authRepo.signInWithEmail(
          email: 'sabithullasharieff16@gmail.com',
          password: 'password123',
        );

        expect(u1.id, isNot(equals(u2.id)));
        expect(u1.id, isNot(equals('valtry-local-user')));
        expect(u2.id, isNot(equals('valtry-local-user')));
      },
    );

    test(
      'production mode rejects login/signup if Supabase client is unavailable',
      () async {
        final prodRepo = AuthRepositoryImpl(
          null,
          profileRepo,
          enableDevFallback: false,
        );

        expect(
          () => prodRepo.signInWithEmail(
            email: 'user@bingo.app',
            password: 'password123',
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          () => prodRepo.signUpWithEmail(
            email: 'user@bingo.app',
            password: 'password123',
            displayName: 'User',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'restoreSession recovers active guest session if explicitly saved',
      () async {
        await authRepo.signInAsGuest(displayName: 'PersistentGuest');
        final restored = await authRepo.restoreSession();

        expect(restored, isNotNull);
        expect(restored!.displayName, equals('PersistentGuest'));
        expect(restored.isGuest, isTrue);
      },
    );

    test('restoreSession prioritizes registered session over guest', () async {
      await authRepo.signInAsGuest(displayName: 'OldGuest');
      await authRepo.signInWithEmail(
        email: 'registered@bingo.app',
        password: 'pass',
      );

      final restored = await authRepo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.isGuest, isFalse);
    });

    test('signOut clears active session and emits Unauthenticated', () async {
      await authRepo.signInAsGuest(displayName: 'GuestUser');

      expectLater(authRepo.authStateChanges, emits(isA<Unauthenticated>()));

      await authRepo.signOut();
      final restored = await authRepo.restoreSession();
      expect(restored, isNull);
      expect(authRepo.isGuest, isFalse);
    });
  });
}
