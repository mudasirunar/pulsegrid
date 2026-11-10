import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  static const String _sessionKey = 'auth_active_user_session';
  final SharedPreferences sharedPreferences;

  AuthRepositoryImpl({required this.sharedPreferences});

  // Pre-configured role profiles for quick 1-tap testing
  static const UserModel coordinatorDemo = UserModel(
    id: 'user-coordinator-01',
    email: 'coordinator@pulsegrid.org',
    displayName: 'Sarah Chen (Incident Commander)',
    role: UserRole.coordinator,
  );

  static const UserModel responderDemo = UserModel(
    id: 'user-responder-01',
    email: 'responder@pulsegrid.org',
    displayName: 'Marcus Vance (Field Responder)',
    role: UserRole.responder,
  );

  static const UserModel viewerDemo = UserModel(
    id: 'user-viewer-01',
    email: 'viewer@pulsegrid.org',
    displayName: 'Auditor Evans (Liaison)',
    role: UserRole.viewer,
  );

  @override
  Future<UserModel?> getCurrentUser() async {
    final rawJson = sharedPreferences.getString(_sessionKey);
    if (rawJson == null) return null;
    try {
      return UserModel.fromJson(rawJson);
    } catch (_) {
      await sharedPreferences.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<UserModel> signInWithRole(UserRole role) async {
    final user = switch (role) {
      UserRole.coordinator => coordinatorDemo,
      UserRole.responder => responderDemo,
      UserRole.viewer => viewerDemo,
    };

    await _persistSession(user);
    return user;
  }

  @override
  Future<UserModel> signInWithEmailPassword(String email, String password) async {
    final normalized = email.trim().toLowerCase();

    // Determine role based on email or default to responder
    final UserModel user;
    if (normalized.contains('coordinator')) {
      user = UserModel(
        id: 'user-${normalized.replaceAll('@', '-').replaceAll('.', '-')}',
        email: email.trim(),
        displayName: 'Coordinator Account',
        role: UserRole.coordinator,
      );
    } else if (normalized.contains('viewer')) {
      user = UserModel(
        id: 'user-${normalized.replaceAll('@', '-').replaceAll('.', '-')}',
        email: email.trim(),
        displayName: 'Observer Account',
        role: UserRole.viewer,
      );
    } else {
      user = UserModel(
        id: 'user-${normalized.replaceAll('@', '-').replaceAll('.', '-')}',
        email: email.trim(),
        displayName: 'Field Responder Account',
        role: UserRole.responder,
      );
    }

    await _persistSession(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    await sharedPreferences.remove(_sessionKey);
  }

  Future<void> _persistSession(UserModel user) async {
    await sharedPreferences.setString(_sessionKey, user.toJson());
  }
}

