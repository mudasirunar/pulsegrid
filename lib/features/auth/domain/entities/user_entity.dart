import 'package:equatable/equatable.dart';
import 'user_role.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? rank;
  final UserRole role;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.rank,
    required this.role,
  });

  @override
  List<Object?> get props => [id, email, displayName, rank, role];
}

