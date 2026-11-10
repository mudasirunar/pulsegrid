import 'package:equatable/equatable.dart';

/// Base Failure class for clean error handling across Domain and Presentation layers
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.code]);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.code]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code]);
}

class ConflictFailure extends Failure {
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;

  const ConflictFailure({
    required String message,
    required this.localData,
    required this.serverData,
  }) : super(message, 'VERSION_CONFLICT');

  @override
  List<Object?> get props => [message, code, localData, serverData];
}

