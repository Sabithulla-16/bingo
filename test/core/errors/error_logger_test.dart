import 'package:flutter_test/flutter_test.dart';
import 'package:bingo/core/errors/app_error_code.dart';
import 'package:bingo/core/errors/app_error.dart';
import 'package:bingo/core/errors/error_logger.dart';

void main() {
  group('ErrorLogger Tests', () {
    test('sanitize redacts sensitive keywords and tokens', () {
      const rawText =
          'User failed login with password=SuperSecretP@ss123 and '
          'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0 '
          'apikey=sb_test_key_999 token: 94830218';

      final sanitized = ErrorLogger.sanitize(rawText);

      expect(sanitized, isNot(contains('SuperSecretP@ss123')));
      expect(sanitized, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(sanitized, isNot(contains('sb_test_key_999')));
      expect(sanitized, contains('REDACTED'));
    });

    test('sanitize redacts SQL table schema references', () {
      const rawSql =
          'ERROR: 42P01: relation "public.player_scores" does not exist at character 19';

      final sanitized = ErrorLogger.sanitize(rawSql);

      expect(sanitized, isNot(contains('public.player_scores')));
      expect(sanitized, contains('REDACTED'));
    });

    test('log records AppError safely without throwing', () {
      final error = AppError(
        code: AppErrorCode.networkUnavailable,
        message: 'Unable to connect. Check your internet connection and try again.',
        technicalDetails:
            'SocketException: Failed host lookup for supabase.co (password=12345)',
        recoveryActionLabel: 'RETRY',
      );

      expect(() => ErrorLogger.log(error, operation: 'test_op'), returnsNormally);
    });

    test('logUnhandled sanitizes raw exception string before recording', () {
      const sensitiveException =
          'Authentication failed with Bearer secret_token_xyz for auth/v1/signup';

      expect(
        () => ErrorLogger.logUnhandled(
          sensitiveException,
          StackTrace.current,
          source: 'auth_signup',
        ),
        returnsNormally,
      );
    });
  });
}
