import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';

/// Concrete implementation of AuthRepository with managed session persistence.
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient? _client;
  final ProfileRepository _profileRepository;
  final _authStateController = StreamController<AppAuthState>.broadcast();

  AuthRepositoryImpl(this._client, this._profileRepository) {
    _client?.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final profile = await _profileRepository.getProfile(session.user.id);
        if (profile != null) {
          _authStateController.add(Authenticated(profile));
        } else {
          // Idempotent profile initialization
          final newProfile = PlayerProfile(
            id: session.user.id,
            displayName:
                session.user.userMetadata?['display_name'] as String? ??
                'Player',
            email: session.user.email ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _profileRepository.upsertProfile(newProfile);
          _authStateController.add(Authenticated(newProfile));
        }
      } else {
        _authStateController.add(const Unauthenticated());
      }
    });
  }

  @override
  Stream<AppAuthState> get authStateChanges => _authStateController.stream;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  bool get isAuthenticated => _client?.auth.currentSession != null;

  @override
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_client == null) {
      // Local fallback in placeholder mode
      final profile = PlayerProfile(
        id: 'mock-user-id',
        displayName: displayName,
        email: email,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _authStateController.add(Authenticated(profile));
      return profile;
    }

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed: no user returned from server.');
    }

    final profile = PlayerProfile(
      id: user.id,
      displayName: displayName.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _profileRepository.upsertProfile(profile);
    return profile;
  }

  @override
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_client == null) {
      // Local fallback in placeholder mode
      final profile = PlayerProfile(
        id: 'mock-user-id',
        displayName: 'Valtry',
        email: email,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _authStateController.add(Authenticated(profile));
      return profile;
    }

    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Sign in failed: no user returned from server.');
    }

    var profile = await _profileRepository.getProfile(user.id);
    if (profile == null) {
      profile = PlayerProfile(
        id: user.id,
        displayName: user.userMetadata?['display_name'] as String? ?? 'Player',
        email: user.email ?? email,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(profile);
    }

    return profile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (_client == null) return;
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  @override
  Future<void> signOut() async {
    if (_client != null) {
      await _client.auth.signOut();
    }
    _authStateController.add(const Unauthenticated());
  }

  @override
  Future<PlayerProfile?> restoreSession() async {
    if (_client == null) return null;

    final session = _client.auth.currentSession;
    if (session == null) return null;

    return await _profileRepository.getProfile(session.user.id);
  }
}
