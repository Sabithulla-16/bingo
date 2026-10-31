import 'app_error.dart';
import 'error_mapper.dart';

/// Value class representing a user-facing failure message.
class AppFailure {
  final String message;
  final String? code;

  const AppFailure(this.message, {this.code});

  factory AppFailure.fromException(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) return error;
    if (error is AppError) {
      return AppFailure(error.message, code: error.code.name);
    }
    final appError = ErrorMapper.map(error, stackTrace);
    return AppFailure(appError.message, code: appError.code.name);
  }

  @override
  String toString() => message;
}
