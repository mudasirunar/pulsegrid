import 'dart:convert';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
    super.rank,
    required super.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      if (rank != null) 'rank': rank,
      'role': role.name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawName = (map['displayName'] as String?) ?? '';
    final parsed = parseNameAndRank(rawName);

    final explicitRank = map['rank'] as String?;
    final rank = (explicitRank != null && explicitRank.isNotEmpty)
        ? explicitRank
        : parsed.rank;

    return UserModel(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      displayName: parsed.name.isNotEmpty ? parsed.name : rawName,
      rank: rank,
      role: UserRole.fromString(map['role'] as String),
    );
  }

  static ({String name, String? rank}) parseNameAndRank(String raw) {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(raw.trim());
    if (match != null) {
      return (name: match.group(1)!.trim(), rank: match.group(2)!.trim());
    }
    return (name: raw.trim(), rank: null);
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

