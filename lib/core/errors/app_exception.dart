/// Base class for all domain and operational exceptions in BINGO.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Thrown when authentication operations fail.
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.details});
}

/// Thrown when room or lobby operations encounter an illegal state.
class RoomException extends AppException {
  const RoomException(super.message, {super.code, super.details});
}

/// Thrown when game rule validation fails (e.g. invalid board or call out of turn).
class GameException extends AppException {
  const GameException(super.message, {super.code, super.details});
}
