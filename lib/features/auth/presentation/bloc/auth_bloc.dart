import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../sync/domain/services/sync_engine.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final SyncEngine? syncEngine;
  StreamSubscription<Map<String, String>>? _userNamesSubscription;
  StreamSubscription<Map<String, String>>? _userRanksSubscription;

  AuthBloc({
    required this.authRepository,
    this.syncEngine,
    AuthState initialState = const AuthInitial(),
  }) : super(initialState) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInWithRoleEvent>(_onSignInWithRole);
    on<SignInWithEmailPasswordEvent>(_onSignInWithEmailPassword);
    on<UpdateDisplayNameEvent>(_onUpdateDisplayName);
    on<ApplyRemoteDisplayNameEvent>(_onApplyRemoteDisplayName);
    on<ApplyRemoteRankEvent>(_onApplyRemoteRank);
    on<SignOutEvent>(_onSignOut);

    _userNamesSubscription = syncEngine?.onUserNamesUpdated.listen((names) {
      final current = state;
      if (current is Authenticated) {
        final remoteName = names[current.user.id];
        if (remoteName != null &&
            remoteName.trim().isNotEmpty &&
            remoteName.trim() != current.user.displayName) {
          add(ApplyRemoteDisplayNameEvent(remoteName.trim()));
        }
      }
    });

    _userRanksSubscription = syncEngine?.onUserRanksUpdated.listen((ranks) {
      final current = state;
      if (current is Authenticated) {
        final remoteRank = ranks[current.user.id];
        if (remoteRank != null &&
            remoteRank.trim().isNotEmpty &&
            remoteRank.trim() != current.user.rank) {
          add(ApplyRemoteRankEvent(remoteRank.trim()));
        }
      }
    });
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithRole(
    SignInWithRoleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.signInWithRole(event.role);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithEmailPassword(
    SignInWithEmailPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      if (event.email.trim().isEmpty || event.password.trim().isEmpty) {
        emit(const AuthError('Email and password must not be empty.'));
        return;
      }
      final user = await authRepository.signInWithEmailPassword(
        event.email,
        event.password,
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUpdateDisplayName(
    UpdateDisplayNameEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final updated = await authRepository.updateDisplayName(event.displayName);
      syncEngine?.updateLocalUserName(updated.id, updated.displayName);
      emit(Authenticated(updated));
    } catch (_) {
      // Keep current Authenticated state intact if rename fails validation
    }
  }

  Future<void> _onApplyRemoteDisplayName(
    ApplyRemoteDisplayNameEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final updated = await authRepository.updateDisplayName(
        event.displayName,
        syncRemote: false,
      );
      emit(Authenticated(updated));
    } catch (_) {}
  }

  Future<void> _onApplyRemoteRank(
    ApplyRemoteRankEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final updated = await authRepository.applyRemoteRank(event.rank);
      emit(Authenticated(updated));
    } catch (_) {}
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await authRepository.signOut();
    emit(const Unauthenticated());
  }

  @override
  Future<void> close() {
    _userNamesSubscription?.cancel();
    _userRanksSubscription?.cancel();
    return super.close();
  }
}

