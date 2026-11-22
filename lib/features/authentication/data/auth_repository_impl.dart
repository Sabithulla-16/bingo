import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/error_logger.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';

/// Concrete implementation of AuthRepository with managed session persistence,
/// Supabase authentication, and offline guest fallback.
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient? _client;
  final ProfileRepository _profileRepository;
  final bool _enableDevFallback;
  final _authStateController = StreamController<AppAuthState>.broadcast();
  String? _guestUserId;

  static const String _prefGuestSessionKey = 'bingo_active_guest_session';
  static const String _prefUserSessionKey = 'bingo_active_user_session';
  static const String _prefRememberMeKey = 'bingo_remember_me';

  AuthRepositoryImpl(
    this._client,
    this._profileRepository, {
    bool enableDevFallback = false,
  }) : _enableDevFallback =
           enableDevFallback || AppConfig.isDevFallbackEnabled {
    _client?.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      ErrorLogger.logInfo(
        'Auth state change received: ${data.event.name}',
        category: 'bingo.auth',
        details: {'hasSession': session != null},
      );
      if (session != null) {
        _guestUserId = null;
        final profile = await _profileRepository.getProfile(session.user.id);
        if (profile != null) {
          await _saveActiveSession(profile.id, isGuest: false);
          ErrorLogger.logInfo(
            'Session restored for registered user: ${profile.id}',
            category: 'bingo.auth',
          );
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
          await _saveActiveSession(newProfile.id, isGuest: false);
          ErrorLogger.logInfo(
            'Created default profile for registered user: ${newProfile.id}',
            category: 'bingo.auth',
          );
          _authStateController.add(Authenticated(newProfile));
        }
      } else {
        // When session is null, never automatically fall back to guest!
        // A null session explicitly represents an Unauthenticated state.
        ErrorLogger.logInfo(
          'Auth state changed to Unauthenticated (null session)',
          category: 'bingo.auth',
        );
        _authStateController.add(const Unauthenticated());
      }
    });
  }

  @override
  Stream<AppAuthState> get authStateChanges => _authStateController.stream;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id ?? _guestUserId;

  @override
  bool get isAuthenticated => _client?.auth.currentSession != null;

  @override
  bool get isGuest =>
      _guestUserId != null ||
      (_client?.auth.currentUser == null &&
          currentUserId != null &&
          currentUserId!.startsWith('guest_'));

  @override
  Future<PlayerProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = displayName.trim().isEmpty
        ? 'Valtry'
        : displayName.trim();

    ErrorLogger.logInfo(
      'Attempting signup for email: $cleanEmail',
      category: 'bingo.auth',
    );
    if (_client == null) {
      if (!_enableDevFallback) {
        throw StateError(
          'Supabase authentication backend is unavailable. Please check your internet connection.',
        );
      }
      // Isolated development-only fallback with unique ID per account
      final devId =
          'dev_${cleanEmail.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final profile = PlayerProfile(
        id: devId,
        displayName: cleanName,
        email: cleanEmail,
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(profile);
      await _saveActiveSession(profile.id);
      ErrorLogger.logInfo(
        'Dev fallback signup completed for unique user: ${profile.id}',
        category: 'bingo.auth',
      );
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
      await _saveActiveSession(profile.id);
      ErrorLogger.logInfo(
        'Supabase signup succeeded: ${profile.id}',
        category: 'bingo.auth',
      );
      _authStateController.add(Authenticated(profile));
      return profile;
    } on sb.AuthException catch (e) {
      ErrorLogger.logInfo(
        'Supabase signup failed: ${e.message}',
        category: 'bingo.auth',
      );
      throw Exception(e.message);
    } catch (e) {
      ErrorLogger.logInfo(
        'Unexpected signup error: $e',
        category: 'bingo.auth',
      );
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
    ErrorLogger.logInfo(
      'Attempting login for email: $cleanEmail (rememberMe: $rememberMe)',
      category: 'bingo.auth',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRememberMeKey, rememberMe);

    if (_client == null) {
      if (!_enableDevFallback) {
        throw StateError(
          'Supabase authentication backend is unavailable. Please check your internet connection.',
        );
      }
      // Isolated development-only fallback with unique ID per account
      final devId =
          'dev_${cleanEmail.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final profile = PlayerProfile(
        id: devId,
        displayName: cleanEmail.split('@').first,
        email: cleanEmail,
        avatarId: 'avatar_coral',
        avatarColorHex: '#FC695C',
        chips: 500,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(profile);
      await _saveActiveSession(profile.id);
      ErrorLogger.logInfo(
        'Dev fallback login completed for unique user: ${profile.id}',
        category: 'bingo.auth',
      );
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

      await _saveActiveSession(profile.id);
      ErrorLogger.logInfo(
        'Supabase login succeeded: ${profile.id}',
        category: 'bingo.auth',
      );
      _authStateController.add(Authenticated(profile));
      return profile;
    } on sb.AuthException catch (e) {
      ErrorLogger.logInfo(
        'Supabase login failed: ${e.message}',
        category: 'bingo.auth',
      );
      throw Exception(e.message);
    } catch (e) {
      ErrorLogger.logInfo('Unexpected login error: $e', category: 'bingo.auth');
      throw Exception('An unexpected error occurred during signin: $e');
    }
  }

  @override
  Future<PlayerProfile> signInAsGuest({String? displayName}) async {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'Guest Valtry';

    ErrorLogger.logInfo(
      'Explicit guest login initiated for $name',
      category: 'bingo.auth',
    );

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

    _guestUserId = guestProfile.id;
    await _profileRepository.upsertProfile(guestProfile);
    await _saveActiveSession(guestProfile.id, isGuest: true);

    ErrorLogger.logInfo(
      'Guest session established: ${guestProfile.id}',
      category: 'bingo.auth',
    );
    _authStateController.add(AuthGuest(guestProfile));
    return guestProfile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    ErrorLogger.logInfo(
      'Initiating password reset for: $cleanEmail',
      category: 'bingo.auth',
    );
    if (_client == null) {
      // Local development / mock fallback mode
      return;
    }

    try {
      await _client.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'bingo://auth/reset-password',
      );
      ErrorLogger.logInfo(
        'Password reset email sent: $cleanEmail',
        category: 'bingo.auth',
      );
    } on sb.AuthException catch (e) {
      ErrorLogger.logInfo(
        'Password reset failed: ${e.message}',
        category: 'bingo.auth',
      );
      throw Exception(e.message);
    } catch (e) {
      ErrorLogger.logInfo(
        'Password reset unexpected error: $e',
        category: 'bingo.auth',
      );
      throw Exception('Failed to send password reset email: $e');
    }
  }

  @override
  Future<void> signOut() async {
    ErrorLogger.logInfo('Signing out current user', category: 'bingo.auth');
    _guestUserId = null;
    await _clearActiveSession();
    if (_client != null) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
    _authStateController.add(const Unauthenticated());
  }

  @override
  Future<PlayerProfile?> restoreSession() async {
    ErrorLogger.logInfo(
      'Restoring session on app launch...',
      category: 'bingo.auth',
    );
    // 1. Check Supabase session first (authoritative registered user)
    if (_client != null) {
      final session = _client.auth.currentSession;
      if (session != null) {
        _guestUserId = null;
        final profile = await _profileRepository.getProfile(session.user.id);
        if (profile != null) {
          await _saveActiveSession(profile.id, isGuest: false);
          ErrorLogger.logInfo(
            'Authoritative Supabase session restored for ${profile.id}',
            category: 'bingo.auth',
          );
          return profile;
        }
      }
    }

    // 2. Check explicitly saved session (only if user explicitly chose it)
    final stored = await _getStoredActiveSession();
    if (stored != null) {
      if (stored.isGuest) {
        _guestUserId = stored.id;
        ErrorLogger.logInfo(
          'Saved guest session restored for ${stored.id}',
          category: 'bingo.auth',
        );
      } else {
        ErrorLogger.logInfo(
          'Saved registered session restored for ${stored.id}',
          category: 'bingo.auth',
        );
      }
      return stored;
    }

    ErrorLogger.logInfo('No existing session found.', category: 'bingo.auth');
    return null;
  }

  Future<void> _saveActiveSession(String userId, {bool isGuest = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isGuest) {
        await prefs.setString(_prefGuestSessionKey, userId);
        await prefs.remove(_prefUserSessionKey);
      } else {
        await prefs.setString(_prefUserSessionKey, userId);
        await prefs.remove(_prefGuestSessionKey);
      }
    } catch (_) {}
  }

  Future<PlayerProfile?> _getStoredActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registeredId = prefs.getString(_prefUserSessionKey);
      if (registeredId != null) {
        return await _profileRepository.getProfile(registeredId);
      }
      final guestId = prefs.getString(_prefGuestSessionKey);
      if (guestId != null) {
        return await _profileRepository.getProfile(guestId);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserSessionKey);
      await prefs.remove(_prefGuestSessionKey);
    } catch (_) {}
  }
}
