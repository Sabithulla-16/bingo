import '../domain/auth_state.dart';
import '../../profile/domain/player_profile.dart';

/// Contract for email/password authentication operations.
abstract class AuthRepository {
  /// Stream of authentication state changes (authenticated, unauthenticated, initial).
  Stream<AppAuthState> get authStateChanges;

  /// Current authenticated user ID, or null if guest / unauthenticated.
  String? get currentUserId;

  /// Checks if there is an active persisted session.
  bool get isAuthenticated;

  /// Register a new account with email, password, and display name.
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Sign in an existing user with email and password.
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
  });

  /// Send password reset instructions to the given email address.
  Future<void> sendPasswordReset(String email);

  /// Sign out the current session.
  Future<void> signOut();

  /// Restores session on application launch.
  Future<PlayerProfile?> restoreSession();
}
