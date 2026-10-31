import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'app_error.dart';

/// Centralized diagnostic logger that securely logs technical error details
/// without exposing sensitive user credentials, database schemas, or internal tokens.
class ErrorLogger {
  const ErrorLogger._();

  static final RegExp _sensitivePattern = RegExp(
    r'(password|token|bearer|apikey|authorization|jwt|secret|access_token|refresh_token)\s*[:=\s]\s*([^\s,;]+)',
    caseSensitive: false,
  );

  static final RegExp _jwtPattern = RegExp(
    r'eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(\.[a-zA-Z0-9_\-]+)?',
  );

  static final RegExp _sqlSchemaPattern = RegExp(
    r'(select|insert\s+into|update|delete\s+from|create\s+table|"public\.[a-z0-9_]+"|relation\s+"[^"]+"|\bpublic\.[a-z0-9_]+\b)',
    caseSensitive: false,
  );

  /// Sanitizes any raw string by masking sensitive keys, tokens, and SQL queries.
  static String sanitize(String input) {
    var sanitized = input.replaceAllMapped(_sensitivePattern, (match) {
      final key = match.group(1);
      return '$key=***REDACTED***';
    });

    sanitized = sanitized.replaceAll(_jwtPattern, '***JWT_REDACTED***');

    if (_sqlSchemaPattern.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(
        _sqlSchemaPattern,
        '***DB_QUERY_REDACTED***',
      );
    }

    return sanitized;
  }

  /// Securely logs an application error with technical diagnostics in debug mode.
  static void log(AppError error, {String? operation, StackTrace? stackTrace}) {
    final effectiveStackTrace = stackTrace ?? error.stackTrace;
    final sanitizedDetails = error.technicalDetails != null
        ? sanitize(error.technicalDetails!)
        : null;

    final logPayload = <String, dynamic>{
      'code': error.code.name,
      'operation': operation ?? 'unspecified_operation',
      'timestamp': error.timestamp.toIso8601String(),
    };
    if (sanitizedDetails != null) {
      logPayload['technical_details'] = sanitizedDetails;
    }
    if (error.originalException != null) {
      logPayload['exception_type'] = error.originalException.runtimeType
          .toString();
    }

    if (kDebugMode) {
      developer.log(
        '🚨 [BINGO ERROR] [${error.code.name}] ${error.message}',
        name: 'bingo.error',
        time: error.timestamp,
        error: logPayload,
        stackTrace: effectiveStackTrace,
      );
    }
  }

  /// Securely logs global unhandled errors.
  static void logUnhandled(
    Object error,
    StackTrace stackTrace, {
    String source = 'global',
  }) {
    final sanitizedError = sanitize(error.toString());
    if (kDebugMode) {
      developer.log(
        '🔥 [BINGO UNHANDLED] from $source: $sanitizedError',
        name: 'bingo.unhandled',
        error: sanitizedError,
        stackTrace: stackTrace,
      );
    }
  }
}
