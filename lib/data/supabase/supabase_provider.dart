import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../../features/authentication/data/auth_repository_impl.dart';
import '../../core/errors/error_mapper.dart';
import '../../features/authentication/domain/auth_repository.dart';
import '../../features/authentication/domain/auth_state.dart';
import '../../features/profile/data/profile_repository_impl.dart';
import '../../features/profile/domain/player_career_stats.dart';
import '../../features/profile/domain/player_preferences.dart';
import '../../features/profile/domain/player_profile.dart';
import '../../features/profile/domain/profile_repository.dart';

/// Provider exposing the Supabase client instance (or null in placeholder mode).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (SupabaseService.isInitialized) {
    return SupabaseService.client;
  }
  return null;
});

/// Provider for ProfileRepository.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepositoryImpl(client);
});

/// Provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  return AuthRepositoryImpl(client, profileRepo);
});

/// Global state provider tracking the current authentication state.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AppAuthState>((ref) {
      final authRepo = ref.watch(authRepositoryProvider);
      final profileRepo = ref.watch(profileRepositoryProvider);
      return AuthStateNotifier(authRepo, profileRepo);
    });

/// Convenience provider returning the currently authenticated PlayerProfile or null.
final currentProfileProvider = Provider<PlayerProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.profile;
});

/// StateNotifier that coordinates authentication state across the application.
class AuthStateNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  StreamSubscription<PlayerProfile>? _profileSub;

  AuthStateNotifier(this._authRepository, this._profileRepository)
    : super(const AuthInitial()) {
    _init();
  }

  void _watchProfile(String userId) {
    _profileSub?.cancel();
    _profileSub = _profileRepository.watchProfile(userId).listen((updated) {
      refreshProfile(updated);
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final profile = await _authRepository.restoreSession();
      if (profile != null) {
        if (profile.isGuest) {
          state = AuthGuest(profile);
        } else {
          state = Authenticated(profile);
        }
        _watchProfile(profile.id);
      } else {
        state = const Unauthenticated();
      }
    } catch (_) {
      state = const Unauthenticated();
    }

    _authRepository.authStateChanges.listen((authState) {
      state = authState;
      if (authState is Authenticated) {
        _watchProfile(authState.profile.id);
      } else if (authState is AuthGuest) {
        _watchProfile(authState.profile.id);
      } else {
        _profileSub?.cancel();
      }
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final profile = await _authRepository.signInWithEmail(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = Authenticated(profile);
      _watchProfile(profile.id);
    } catch (e) {
      state = AuthFailure(ErrorMapper.map(e).message);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final profile = await _authRepository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = Authenticated(profile);
      _watchProfile(profile.id);
    } catch (e) {
      state = AuthFailure(ErrorMapper.map(e).message);
      rethrow;
    }
  }

  Future<void> signInAsGuest({String? displayName}) async {
    try {
      final profile = await _authRepository.signInAsGuest(
        displayName: displayName,
      );
      state = AuthGuest(profile);
      _watchProfile(profile.id);
    } catch (e) {
      state = AuthFailure(ErrorMapper.map(e).message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    await _authRepository.signOut();
    state = const Unauthenticated();
  }

  Future<void> updateProfile({
    String? displayName,
    String? avatarId,
    String? avatarColorHex,
  }) async {
    final current = state;
    if (current is Authenticated) {
      final updated = current.profile.copyWith(
        displayName: displayName,
        avatarId: avatarId,
        avatarColorHex: avatarColorHex,
        updatedAt: DateTime.now(),
      );
      await _profileRepository.upsertProfile(updated);
      state = Authenticated(updated);
    }
  }

  void refreshProfile(PlayerProfile profile) {
    final current = state;
    if (current is Authenticated) {
      state = Authenticated(profile);
    } else if (current is AuthGuest) {
      state = AuthGuest(profile);
    }
  }

  Future<void> reloadProfile() async {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      final p = await _profileRepository.getProfile(uid);
      if (p != null) {
        refreshProfile(p);
      }
    }
  }
}

/// Provider for player career statistics, synchronized in real time.
final careerStatsProvider =
    StreamProvider.autoDispose.family<PlayerCareerStats, String>((
  ref,
  userId,
) {
  final profileRepo = ref.watch(profileRepositoryProvider);
  return profileRepo.watchCareerStats(userId);
});

/// Provider for managing local player preferences (sound, haptics).
final playerPreferencesProvider =
    StateNotifierProvider<PlayerPreferencesNotifier, PlayerPreferences>((ref) {
      final profileRepo = ref.watch(profileRepositoryProvider);
      return PlayerPreferencesNotifier(profileRepo);
    });

class PlayerPreferencesNotifier extends StateNotifier<PlayerPreferences> {
  final ProfileRepository _profileRepo;

  PlayerPreferencesNotifier(this._profileRepo)
    : super(const PlayerPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _profileRepo.getPreferences();
    state = loaded;
  }

  Future<void> toggleSoundEffects() async {
    final updated = state.copyWith(
      soundEffectsEnabled: !state.soundEffectsEnabled,
    );
    state = updated;
    await _profileRepo.savePreferences(updated);
  }

  Future<void> toggleHaptics() async {
    final updated = state.copyWith(hapticsEnabled: !state.hapticsEnabled);
    state = updated;
    await _profileRepo.savePreferences(updated);
  }
}
