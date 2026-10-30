import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/supabase/supabase_provider.dart';
import 'multiplayer_repository.dart';
import 'multiplayer_repository_impl.dart';

final multiplayerRepositoryProvider = Provider<MultiplayerRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  return MultiplayerRepositoryImpl(
    supabaseClient: supabase,
    authRepository: authRepo,
    profileRepository: profileRepo,
  );
});
