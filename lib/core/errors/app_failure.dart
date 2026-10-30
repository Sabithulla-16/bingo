/// Value class representing a user-facing failure message.
class AppFailure {
  final String message;
  final String? code;

  const AppFailure(this.message, {this.code});

  factory AppFailure.fromException(Object error) {
    if (error is AppFailure) return error;
    return AppFailure(error.toString());
  }

  @override
  String toString() => message;
}
