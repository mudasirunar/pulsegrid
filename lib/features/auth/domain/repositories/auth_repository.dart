import '../entities/user_role.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  /// Fetches the currently authenticated user from persisted session
  Future<UserModel?> getCurrentUser();

  /// Quick 1-tap sign-in with pre-configured role profiles (Coordinator, Responder, Viewer)
  Future<UserModel> signInWithRole(UserRole role);

  /// Sign-in using email and password credentials
  Future<UserModel> signInWithEmailPassword(String email, String password);

  /// Updates the current user's display name locally and syncs to remote.
  Future<UserModel> updateDisplayName(String newDisplayName, {bool syncRemote = true});

  /// Updates the current user's rank in the local session cache.
  Future<UserModel> applyRemoteRank(String newRank);

  /// Clears the active session and signs out
  Future<void> signOut();
}

