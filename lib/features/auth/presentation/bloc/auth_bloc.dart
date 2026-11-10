import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({
    required this.authRepository,
    AuthState initialState = const AuthInitial(),
  }) : super(initialState) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInWithRoleEvent>(_onSignInWithRole);
    on<SignInWithEmailPasswordEvent>(_onSignInWithEmailPassword);
    on<SignOutEvent>(_onSignOut);
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

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await authRepository.signOut();
    emit(const Unauthenticated());
  }
}

