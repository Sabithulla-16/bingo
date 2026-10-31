import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../../features/authentication/data/auth_repository_impl.dart';
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
  if (authState is Authenticated) {
    return authState.profile;
  }
  return null;
});

/// StateNotifier that coordinates authentication state across the application.
class AuthStateNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  AuthStateNotifier(this._authRepository, this._profileRepository)
    : super(const AuthInitial()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final profile = await _authRepository.restoreSession();
      if (profile != null) {
        state = Authenticated(profile);
      } else {
        state = const Unauthenticated();
      }
    } catch (_) {
      state = const Unauthenticated();
    }

    _authRepository.authStateChanges.listen((authState) {
      state = authState;
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
    } catch (e) {
      state = AuthFailure(e.toString());
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
    } catch (e) {
      state = AuthFailure(e.toString());
      rethrow;
    }
  }

  Future<void> signInAsGuest({String? displayName}) async {
    try {
      final profile = await _authRepository.signInAsGuest(
        displayName: displayName,
      );
      state = Authenticated(profile);
    } catch (e) {
      state = AuthFailure(e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
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
}

/// Provider for player career statistics.
final careerStatsProvider = FutureProvider.family<PlayerCareerStats, String>((
  ref,
  userId,
) async {
  final profileRepo = ref.watch(profileRepositoryProvider);
  return await profileRepo.getCareerStats(userId);
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
