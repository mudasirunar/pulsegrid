import 'package:equatable/equatable.dart';
import '../../domain/entities/user_role.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class SignInWithRoleEvent extends AuthEvent {
  final UserRole role;

  const SignInWithRoleEvent(this.role);

  @override
  List<Object?> get props => [role];
}

class SignInWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailPasswordEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

