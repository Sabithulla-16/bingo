import 'package:flutter/foundation.dart';
import 'app_error_code.dart';

/// Represents a standardized application-level error with a user-friendly message,
/// technical diagnostic information, and optional recovery actions.
class AppError implements Exception {
  final String message;
  final AppErrorCode code;
  final String? technicalDetails;
  final Object? originalException;
  final StackTrace? stackTrace;
  final VoidCallback? recoveryAction;
  final String? recoveryActionLabel;
  final DateTime timestamp;

  AppError({
    required this.message,
    this.code = AppErrorCode.unknown,
    this.technicalDetails,
    this.originalException,
    this.stackTrace,
    this.recoveryAction,
    this.recoveryActionLabel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a copy with optional updated fields.
  AppError copyWith({
    String? message,
    AppErrorCode? code,
    String? technicalDetails,
    Object? originalException,
    StackTrace? stackTrace,
    VoidCallback? recoveryAction,
    String? recoveryActionLabel,
  }) {
    return AppError(
      message: message ?? this.message,
      code: code ?? this.code,
      technicalDetails: technicalDetails ?? this.technicalDetails,
      originalException: originalException ?? this.originalException,
      stackTrace: stackTrace ?? this.stackTrace,
      recoveryAction: recoveryAction ?? this.recoveryAction,
      recoveryActionLabel: recoveryActionLabel ?? this.recoveryActionLabel,
      timestamp: timestamp,
    );
  }

  @override
  String toString() => 'AppError(code: $code, message: "$message")';
}
