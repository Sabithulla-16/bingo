import '../../profile/domain/player_profile.dart';

/// Represents the global authentication state of the application.
sealed class AppAuthState {
  const AppAuthState();
}

/// Initializing or verifying session on launch.
class AuthInitial extends AppAuthState {
  const AuthInitial();
}

/// Authenticated with a valid registered player profile.
class Authenticated extends AppAuthState {
  final PlayerProfile profile;
  const Authenticated(this.profile);
}

/// Signed in as a local anonymous guest player.
class AuthGuest extends AppAuthState {
  final PlayerProfile profile;
  const AuthGuest(this.profile);
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

extension AppAuthStateExt on AppAuthState {
  PlayerProfile? get profile {
    final self = this;
    if (self is Authenticated) return self.profile;
    if (self is AuthGuest) return self.profile;
    return null;
  }

  bool get isGuest => this is AuthGuest;
  bool get isRegistered => this is Authenticated;
}
