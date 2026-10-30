import '../../profile/domain/player_profile.dart';

/// Represents the global authentication state of the application.
sealed class AppAuthState {
  const AppAuthState();
}

/// Initializing or verifying session on launch.
class AuthInitial extends AppAuthState {
  const AuthInitial();
}

/// Authenticated with a valid player profile.
class Authenticated extends AppAuthState {
  final PlayerProfile profile;
  const Authenticated(this.profile);
}

/// No active session or signed out.
class Unauthenticated extends AppAuthState {
  const Unauthenticated();
}

/// Authentication encountered an error.
class AuthFailure extends AppAuthState {
  final String message;
  const AuthFailure(this.message);
}
