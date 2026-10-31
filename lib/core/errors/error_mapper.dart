import 'dart:async';
import 'dart:io';
import 'app_error.dart';
import 'app_error_code.dart';
import 'app_exception.dart';

/// Translates technical exceptions, database errors, and operational failures
/// into clean, user-friendly, and actionable [AppError] representations.
class ErrorMapper {
  const ErrorMapper._();

  /// Converts any thrown object into an [AppError] with an appropriate message and code.
  static AppError map(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) {
      return error;
    }

    // 1. Domain AppExceptions
    if (error is AppException) {
      return _mapAppException(error, stackTrace);
    }

    final rawString = error.toString().trim();
    final lower = rawString.toLowerCase();

    // 2. Network & Socket Exceptions
    if (error is SocketException ||
        error is HttpException ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('handshakeexception')) {
      return AppError(
        code: AppErrorCode.networkUnavailable,
        message:
            'Unable to connect. Check your internet connection and try again.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
        recoveryActionLabel: 'RETRY',
      );
    }

    // 3. Timeout Exceptions
    if (error is TimeoutException || lower.contains('timeout')) {
      return AppError(
        code: AppErrorCode.timeout,
        message: 'This is taking longer than expected. Please try again.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
        recoveryActionLabel: 'RETRY',
      );
    }

    // 4. Supabase & Authentication Failures
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('wrong password') ||
        lower.contains('invalid grant')) {
      return AppError(
        code: AppErrorCode.invalidCredentials,
        message: 'Incorrect email or password. Please try again.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('user already registered') ||
        lower.contains('already registered') ||
        lower.contains('email already in use') ||
        lower.contains('user already exists')) {
      return AppError(
        code: AppErrorCode.emailAlreadyRegistered,
        message:
            'An account with this email already exists. Try signing in instead.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('password should be at least') ||
        lower.contains('weak password') ||
        lower.contains('password must be at least')) {
      return AppError(
        code: AppErrorCode.weakPassword,
        message:
            'Your password is too weak. Please choose a stronger password.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('email not confirmed') ||
        lower.contains('email not verified') ||
        lower.contains('verify your email')) {
      return AppError(
        code: AppErrorCode.emailNotVerified,
        message: 'Please verify your email address before signing in.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many attempts')) {
      return AppError(
        code: AppErrorCode.tooManyAttempts,
        message: 'Too many attempts. Please wait a moment before trying again.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('user not found') ||
        lower.contains('account not found') ||
        lower.contains('no user found')) {
      return AppError(
        code: AppErrorCode.accountNotFound,
        message: "We couldn't find an account with those details.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('session expired') ||
        lower.contains('refresh_token_not_found') ||
        lower.contains('token expired') ||
        lower.contains('jwt expired')) {
      return AppError(
        code: AppErrorCode.sessionExpired,
        message: 'Your session has expired. Please sign in again.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('password reset') || lower.contains('reset password')) {
      return AppError(
        code: AppErrorCode.passwordResetFailure,
        message: "We couldn't send the password reset email. Please try again.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('auth service unavailable') ||
        lower.contains('503') ||
        lower.contains('bad gateway')) {
      return AppError(
        code: AppErrorCode.authServiceUnavailable,
        message: 'Sign-in is temporarily unavailable. Please try again later.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 5. Multiplayer & Room Errors
    if (lower.contains('room code') ||
        lower.contains('room not found') ||
        lower.contains('invalid code') ||
        lower.contains('could not find room') ||
        lower.contains('room with code') ||
        (lower.contains('room') && lower.contains('not found'))) {
      return AppError(
        code: AppErrorCode.roomNotFound,
        message: "We couldn't find that room. Check the code and try again.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('room is full') || lower.contains('room full')) {
      return AppError(
        code: AppErrorCode.roomFull,
        message: 'This room is full.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('room expired') ||
        lower.contains('room is no longer available') ||
        lower.contains('room finished') ||
        lower.contains('already started')) {
      return AppError(
        code: AppErrorCode.roomExpired,
        message: 'This room is no longer available.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('start game failure') ||
        lower.contains('could not start game') ||
        lower.contains('could not start match')) {
      return AppError(
        code: AppErrorCode.startGameFailed,
        message: "We couldn't start the game. Please try again.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('kicked') ||
        lower.contains('removed from room') ||
        lower.contains('no longer a member')) {
      return AppError(
        code: AppErrorCode.playerRemoved,
        message: 'You are no longer a member of this room.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('reconnection failed') ||
        lower.contains('failed to reconnect')) {
      return AppError(
        code: AppErrorCode.reconnectionFailed,
        message: 'Unable to reconnect. Please check your connection.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('connection lost') ||
        lower.contains('disconnected') ||
        lower.contains('channel closed')) {
      return AppError(
        code: AppErrorCode.connectionLost,
        message: 'Connection lost. Trying to reconnect...',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('sync') || lower.contains('synchronization')) {
      return AppError(
        code: AppErrorCode.syncFailed,
        message:
            "We're having trouble syncing the game. Please wait while we reconnect.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 6. Gameplay Errors
    if (lower.contains('already been called') ||
        lower.contains('already called')) {
      return AppError(
        code: AppErrorCode.numberAlreadyCalled,
        message: 'That number has already been called.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('not your turn')) {
      return AppError(
        code: AppErrorCode.notYourTurn,
        message: "It's not your turn yet.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains("isn't complete") ||
        lower.contains('not complete') ||
        lower.contains('incomplete line')) {
      return AppError(
        code: AppErrorCode.lineIncomplete,
        message: "This line isn't complete yet.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('already claimed')) {
      return AppError(
        code: AppErrorCode.lineAlreadyClaimed,
        message: "You've already claimed this line.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (lower.contains('round has already ended') ||
        lower.contains('match already completed') ||
        lower.contains('game has ended')) {
      return AppError(
        code: AppErrorCode.roundAlreadyEnded,
        message: 'The round has already ended.',
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 7. General Backend & Database Persistence Errors
    if (lower.contains('could not load') ||
        lower.contains('pgrst116') ||
        lower.contains('404')) {
      return AppError(
        code: AppErrorCode.loadFailed,
        message: "We couldn't load this information. Please try again.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
        recoveryActionLabel: 'RELOAD',
      );
    }

    if (lower.contains('save') ||
        lower.contains('update') ||
        lower.contains('insert') ||
        lower.contains('upsert')) {
      return AppError(
        code: AppErrorCode.saveFailed,
        message: "Your changes couldn't be saved. Please try again.",
        technicalDetails: rawString,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 8. Default Safe Fallback
    return AppError(
      code: AppErrorCode.unknown,
      message: "We're having trouble connecting. Please try again.",
      technicalDetails: rawString,
      originalException: error,
      stackTrace: stackTrace,
      recoveryActionLabel: 'TRY AGAIN',
    );
  }

  static AppError _mapAppException(
    AppException exception,
    StackTrace? stackTrace,
  ) {
    if (exception is AuthException) {
      return map(exception.message, stackTrace);
    }
    if (exception is RoomException) {
      return map(exception.message, stackTrace);
    }
    if (exception is GameException) {
      return map(exception.message, stackTrace);
    }
    return AppError(
      code: AppErrorCode.unknown,
      message: exception.message,
      technicalDetails: exception.details?.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }
}
