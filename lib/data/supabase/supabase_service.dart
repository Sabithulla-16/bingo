import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/error_logger.dart';

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
  static Future<void> initialize() async {
    if (!AppConfig.hasValidSupabaseCredentials) {
      ErrorLogger.logInfo(
        'Supabase initialized with placeholder credentials. Real auth disabled.',
        category: 'bingo.supabase',
      );
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
      ErrorLogger.logInfo(
        'Supabase client successfully initialized (${AppConfig.supabaseUrl})',
        category: 'bingo.supabase',
      );
    } catch (e, st) {
      ErrorLogger.logUnhandled(e, st, source: 'SupabaseService.initialize');
    }
  }
}
