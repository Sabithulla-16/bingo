import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';

/// Concrete implementation of AuthRepository with managed session persistence,
/// Supabase authentication, and offline guest fallback.
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient? _client;
  final ProfileRepository _profileRepository;
  final _authStateController = StreamController<AppAuthState>.broadcast();

  static const String _prefGuestSessionKey = 'bingo_active_guest_session';
  static const String _prefRememberMeKey = 'bingo_remember_me';

  AuthRepositoryImpl(this._client, this._profileRepository) {
    _client?.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final profile = await _profileRepository.getProfile(session.user.id);
        if (profile != null) {
          _authStateController.add(Authenticated(profile));
        } else {
          final newProfile = PlayerProfile(
            id: session.user.id,
            displayName:
                session.user.userMetadata?['display_name'] as String? ??
                'Valtry',
            email: session.user.email ?? '',
            avatarId: 'avatar_coral',
            avatarColorHex: '#FC695C',
            chips: 500,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _profileRepository.upsertProfile(newProfile);
          _authStateController.add(Authenticated(newProfile));
        }
      } else {
        // Only broadcast Unauthenticated if there's no active guest session
        final guest = await _getStoredGuestSession();
        if (guest != null) {
          _authStateController.add(Authenticated(guest));
        } else {
          _authStateController.add(const Unauthenticated());
        }
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
    final cleanEmail = email.trim();
    final cleanName = displayName.trim().isEmpty ? 'Valtry' : displayName.trim();

    if (_client == null) {
      // Local fallback mode when running without Supabase credentials
      final profile = PlayerProfile(
        id: const Uuid().v4(),
        displayName: cleanName,
        email: cleanEmail,
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(profile);
      await _clearGuestSession();
      _authStateController.add(Authenticated(profile));
      return profile;
    }

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': cleanName},
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Registration failed: no user returned from server.');
      }

      final profile = PlayerProfile(
        id: user.id,
        displayName: cleanName,
        email: cleanEmail,
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _profileRepository.upsertProfile(profile);
      await _clearGuestSession();
      _authStateController.add(Authenticated(profile));
      return profile;
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred during signup: $e');
    }
  }

  @override
  Future<PlayerProfile> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRememberMeKey, rememberMe);

    if (_client == null) {
      // Local fallback mode
      final profile = PlayerProfile(
        id: 'valtry-local-user',
        displayName: 'Valtry',
        email: cleanEmail,
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(profile);
      await _clearGuestSession();
      _authStateController.add(Authenticated(profile));
      return profile;
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
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
          displayName:
              user.userMetadata?['display_name'] as String? ?? 'Valtry',
          email: user.email ?? cleanEmail,
          avatarId: 'avatar_coral',
          avatarColorHex: '#FC695C',
          chips: 500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _profileRepository.upsertProfile(profile);
      }

      await _clearGuestSession();
      _authStateController.add(Authenticated(profile));
      return profile;
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred during signin: $e');
    }
  }

  @override
  Future<PlayerProfile> signInAsGuest({String? displayName}) async {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'Guest Valtry';

    final guestProfile = PlayerProfile(
      id: 'guest_${const Uuid().v4().substring(0, 8)}',
      displayName: name,
      email: 'guest@bingo.app',
      avatarId: 'avatar_coral',
      avatarColorHex: '#FC695C',
      chips: 500,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _profileRepository.upsertProfile(guestProfile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGuestSessionKey, guestProfile.id);

    _authStateController.add(Authenticated(guestProfile));
    return guestProfile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (_client == null) return;

    try {
      await _client.auth.resetPasswordForEmail(cleanEmail);
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _clearGuestSession();
    if (_client != null) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
    _authStateController.add(const Unauthenticated());
  }

  @override
  Future<PlayerProfile?> restoreSession() async {
    // 1. Check Supabase session first
    if (_client != null) {
      final session = _client.auth.currentSession;
      if (session != null) {
        return await _profileRepository.getProfile(session.user.id);
      }
    }

    // 2. Check local guest session
    final guest = await _getStoredGuestSession();
    if (guest != null) {
      return guest;
    }

    return null;
  }

  Future<PlayerProfile?> _getStoredGuestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString(_prefGuestSessionKey);
      if (guestId != null) {
        return await _profileRepository.getProfile(guestId);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearGuestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefGuestSessionKey);
    } catch (_) {}
  }
}
