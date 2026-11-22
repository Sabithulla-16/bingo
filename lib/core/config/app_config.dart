/// Central application configuration loaded from compile-time definitions,
/// environment variables, or bundled production backend defaults.
class AppConfig {
  const AppConfig._();

  static const String appName = 'BINGO';
  static const String appVersion = '1.0.0';

  /// Supabase project URL injected via --dart-define=SUPABASE_URL=...
  /// Defaults to the production BINGO project instance.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pqkrqppxbnrjcgxvmogn.supabase.co',
  );

  /// Supabase anon / publishable key injected via --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxa3JxcHB4Ym5yamNneHZtb2duIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzNzQxNjAsImV4cCI6MjEwODk1MDE2MH0.9x4_jbX5e0fCWv50baeL5tOsIVOh8M7yiwzOcP-OvFg',
  );

  /// Explicit flag to allow mock local accounts in offline development/testing only.
  /// Strictly false in production to ensure authentic Supabase registration.
  static const bool isDevFallbackEnabled = bool.fromEnvironment(
    'ENABLE_DEV_FALLBACK',
    defaultValue: false,
  );

  /// Helper to check if credentials are valid production keys.
  static bool get hasValidSupabaseCredentials {
    return !supabaseUrl.contains('placeholder') &&
        supabasePublishableKey.isNotEmpty &&
        supabasePublishableKey != 'placeholder-anon-key';
  }
}
