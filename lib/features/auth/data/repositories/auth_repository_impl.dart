import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/local_data_source.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../sync/data/models/sync_operation_model.dart';
import '../../../sync/domain/entities/sync_operation_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  static const String _sessionKey = 'auth_active_user_session';
  final SharedPreferences sharedPreferences;
  final FirebaseAuth? firebaseAuth;
  final FirebaseFirestore? firestore;
  final LocalDataSource? localDataSource;

  AuthRepositoryImpl({
    required this.sharedPreferences,
    this.firebaseAuth,
    this.firestore,
    this.localDataSource,
  });

  // Pre-configured default credentials for the 3 roles
  static const String defaultPassword = 'Emergency123!';
  static const String coordinatorEmail = 'coordinator@pulsegrid.org';
  static const String responderEmail = 'responder@pulsegrid.org';
  static const String viewerEmail = 'viewer@pulsegrid.org';

  static const UserModel coordinatorDemo = UserModel(
    id: 'user-coordinator-01',
    email: coordinatorEmail,
    displayName: 'Sarah Chen',
    rank: 'Incident Commander',
    role: UserRole.coordinator,
  );

  static const UserModel responderDemo = UserModel(
    id: 'user-responder-01',
    email: responderEmail,
    displayName: 'Marcus Vance',
    rank: 'Field Responder',
    role: UserRole.responder,
  );

  static const UserModel viewerDemo = UserModel(
    id: 'user-viewer-01',
    email: viewerEmail,
    displayName: 'Auditor Evans',
    rank: 'Liaison',
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
    final (email, password) = switch (role) {
      UserRole.coordinator => (coordinatorEmail, defaultPassword),
      UserRole.responder => (responderEmail, defaultPassword),
      UserRole.viewer => (viewerEmail, defaultPassword),
    };
    return await signInWithEmailPassword(email, password);
  }

  @override
  Future<UserModel> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw const ValidationException('Email and password must not be empty.');
    }

    final (inferredName, inferredRank, inferredRole) = _inferProfile(cleanEmail);

    // If Firebase is not initialized (e.g. running unit tests without native Firebase mock)
    if (firebaseAuth == null && Firebase.apps.isEmpty) {
      final user = UserModel(
        id: 'user-${cleanEmail.replaceAll('@', '-').replaceAll('.', '-')}',
        email: cleanEmail,
        displayName: inferredName,
        rank: inferredRank,
        role: inferredRole,
      );
      await sharedPreferences.setString(_sessionKey, user.toJson());
      return user;
    }

    final auth = firebaseAuth ?? FirebaseAuth.instance;
    final db = firestore ?? FirebaseFirestore.instance;

    UserCredential credential;

    try {
      // 1. Authenticate with Firebase Auth (Strict Sign In only - no account creation)
      credential = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        throw const AuthException('Invalid email or password.');
      } else if (e.code == 'user-disabled') {
        throw const AuthException('This account has been disabled.');
      }
      throw AuthException(e.message ?? 'Authentication failed.');
    } catch (e) {
      // If network fails in offline/airplane mode, fallback to cached session if available
      final cached = await getCurrentUser();
      if (cached != null && cached.email.toLowerCase() == cleanEmail) {
        return cached;
      }
      throw AuthException('Network error: unable to sign in offline without an active session.');
    }

    final userObj = credential.user;
    if (userObj == null) {
      throw const AuthException('Sign in failed: no user returned from Firebase Auth.');
    }
    final uid = userObj.uid;

    // 2. Fetch user profile from Cloud Firestore (/users/{uid}) as primary source of truth
    String resolvedDisplayName = userObj.displayName ?? inferredName;
    String? resolvedRank = inferredRank;
    UserRole resolvedRole = inferredRole;

    try {
      final userDoc = db.collection('users').doc(uid);
      final snapshot = await userDoc.get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data['displayName'] != null && (data['displayName'] as String).isNotEmpty) {
          final parsed = UserModel.parseNameAndRank(data['displayName'] as String);
          resolvedDisplayName = parsed.name;
          resolvedRank = (data['rank'] as String?) ?? parsed.rank ?? inferredRank;
        }
        if (data['rank'] != null && (data['rank'] as String).isNotEmpty) {
          resolvedRank = data['rank'] as String;
        }
        if (data['role'] != null) {
          resolvedRole = UserRole.fromString(data['role'] as String);
        }
      }

      // Clean up and standardize the document in Cloud Firestore
      await userDoc.set({
        'displayName': resolvedDisplayName,
        'rank': resolvedRank,
        'role': resolvedRole.name,
        'email': cleanEmail,
      }, SetOptions(merge: true));
    } catch (_) {
      // If offline after initial auth, fall back to cached session
      final cached = await getCurrentUser();
      if (cached != null && cached.id == uid) {
        return cached;
      }
    }

    final user = UserModel(
      id: uid,
      email: cleanEmail,
      displayName: resolvedDisplayName,
      rank: resolvedRank,
      role: resolvedRole,
    );

    await _persistSession(user);
    return user;
  }

  @override
  Future<UserModel> updateDisplayName(
    String newDisplayName, {
    bool syncRemote = true,
  }) async {
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Display name cannot be empty.');
    }

    final current = await getCurrentUser();
    if (current == null) {
      throw const AuthException('No authenticated user found.');
    }

    final updated = UserModel(
      id: current.id,
      email: current.email,
      displayName: trimmed,
      rank: current.rank,
      role: current.role,
    );

    await _persistSession(updated);

    if (!syncRemote) {
      return updated;
    }

    unawaited(_syncDisplayNameRemotely(updated));
    return updated;
  }

  Future<void> _syncDisplayNameRemotely(UserModel updated) async {
    try {
      if (firebaseAuth != null || Firebase.apps.isNotEmpty) {
        final auth = firebaseAuth ?? FirebaseAuth.instance;
        await auth.currentUser?.updateDisplayName(updated.displayName);
      }
    } catch (_) {}

    bool remoteSynced = false;
    try {
      if (firestore != null || Firebase.apps.isNotEmpty) {
        final db = firestore ?? FirebaseFirestore.instance;
        await db.collection('users').doc(updated.id).set({
          'displayName': updated.displayName,
          'rank': updated.rank,
          'role': updated.role.name,
          'email': updated.email,
        }, SetOptions(merge: true));
        remoteSynced = true;
      }
    } catch (_) {}

    if (!remoteSynced && localDataSource != null) {
      final syncOp = SyncOperationModel(
        operationId: const Uuid().v4(),
        entityId: updated.id,
        entityType: SyncEntityType.userProfile.toDbValue(),
        operationType: SyncOperationType.update.toDbValue(),
        payload: jsonEncode({
          'id': updated.id,
          'displayName': updated.displayName,
          'rank': updated.rank,
          'role': updated.role.name,
          'email': updated.email,
        }),
        createdAt: DateTime.now().toUtc(),
        syncState: SyncStatus.pending.toDbValue(),
      );
      await localDataSource!.enqueueSyncOperation(syncOp);
    }
  }

  @override
  Future<UserModel> applyRemoteRank(String newRank) async {
    final trimmed = newRank.trim();
    if (trimmed.isEmpty) {
      throw const AuthException('Rank cannot be empty.');
    }
    final current = await getCurrentUser();
    if (current == null) {
      throw const AuthException('No authenticated user found.');
    }
    final updated = UserModel(
      id: current.id,
      email: current.email,
      displayName: current.displayName,
      rank: trimmed,
      role: current.role,
    );
    await _persistSession(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    try {
      if (firebaseAuth != null || Firebase.apps.isNotEmpty) {
        final auth = firebaseAuth ?? FirebaseAuth.instance;
        await auth.signOut();
      }
    } catch (_) {}
    await sharedPreferences.remove(_sessionKey);
  }

  Future<void> _persistSession(UserModel user) async {
    await sharedPreferences.setString(_sessionKey, user.toJson());
  }

  (String displayName, String rank, UserRole role) _inferProfile(String email) {
    if (email.contains('coordinator')) {
      return ('Sarah Chen', 'Incident Commander', UserRole.coordinator);
    } else if (email.contains('viewer')) {
      return ('Auditor Evans', 'Liaison', UserRole.viewer);
    } else {
      return ('Marcus Vance', 'Field Responder', UserRole.responder);
    }
  }
}
