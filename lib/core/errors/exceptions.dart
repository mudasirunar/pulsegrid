/// Base exception for Pulse Grid domain & data errors
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.code]);
}

class ServerException extends AppException {
  const ServerException(super.message, [super.code]);
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.code]);
}

class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}

class ConflictException extends AppException {
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;

  const ConflictException({
    required String message,
    required this.localData,
    required this.serverData,
  }) : super(message, 'VERSION_CONFLICT');
}

