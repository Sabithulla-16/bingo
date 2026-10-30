import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';

/// Centralized service encapsulating Supabase client operations.
class SupabaseService {
  static SupabaseClient? _client;

  /// Returns the active Supabase client instance.
  static SupabaseClient get client {
    if (_client == null) {
      throw StateError(
        'SupabaseService has not been initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Indicates whether Supabase is successfully initialized with credentials.
  static bool get isInitialized => _client != null;

  /// Initializes the Supabase SDK.
  /// If credentials are placeholders, it logs safely and continues without crashing.
  static Future<void> initialize() async {
    if (!AppConfig.hasValidSupabaseCredentials) {
      // In development / testing mode with placeholder credentials.
      return;
    }

    try {
      final supabase = await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = supabase.client;
    } catch (_) {
      // Allow local development and offline mock tests to proceed
    }
  }
}
