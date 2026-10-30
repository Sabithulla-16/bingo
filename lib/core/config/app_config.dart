/// Central application configuration loaded from environment variables or compile-time definitions.
class AppConfig {
  const AppConfig._();

  static const String appName = 'BINGO';
  static const String appVersion = '1.0.0';

  /// Supabase project URL injected via --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  /// Supabase anon / publishable key injected via --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  /// Helper to check if credentials are valid production keys or development placeholders.
  static bool get hasValidSupabaseCredentials {
    return !supabaseUrl.contains('placeholder') &&
        supabasePublishableKey.isNotEmpty &&
        supabasePublishableKey != 'placeholder-anon-key';
  }
}
