import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../../features/authentication/data/auth_repository_impl.dart';
import '../../features/authentication/domain/auth_repository.dart';
import '../../features/authentication/domain/auth_state.dart';
import '../../features/profile/data/profile_repository_impl.dart';
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
      return AuthStateNotifier(authRepo);
    });

/// StateNotifier that coordinates authentication state across the application.
class AuthStateNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _authRepository;

  AuthStateNotifier(this._authRepository) : super(const AuthInitial()) {
    _init();
  }

  Future<void> _init() async {
    // Check for existing session
    try {
      final profile = await _authRepository.restoreSession();
      if (profile != null) {
        state = Authenticated(profile);
      } else {
        state = const Unauthenticated();
      }
    } catch (e) {
      state = const Unauthenticated();
    }

    // Subscribe to ongoing auth state changes
    _authRepository.authStateChanges.listen((authState) {
      state = authState;
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final profile = await _authRepository.signInWithEmail(
        email: email,
        password: password,
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

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const Unauthenticated();
  }
}
