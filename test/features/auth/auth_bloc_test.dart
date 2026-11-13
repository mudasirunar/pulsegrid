import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsegrid/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_event.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_state.dart';

void main() {
  late SharedPreferences prefs;
  late AuthRepositoryImpl repository;
  late AuthBloc authBloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = AuthRepositoryImpl(sharedPreferences: prefs);
    authBloc = AuthBloc(authRepository: repository);
  });

  tearDown(() {
    authBloc.close();
  });

  test('initial state is AuthInitial', () {
    expect(authBloc.state, const AuthInitial());
  });

  test('CheckAuthStatusEvent emits Unauthenticated when no active session', () async {
    final expected = [
      const AuthLoading(),
      const Unauthenticated(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const CheckAuthStatusEvent());
  });

  test('SignInWithRoleEvent signs in as Coordinator and persists session', () async {
    final expected = [
      const AuthLoading(),
      predicate<AuthState>((state) {
        return state is Authenticated &&
            state.user.role == UserRole.coordinator &&
            state.user.role.canAssignAndClose == true &&
            state.user.role.isReadOnly == false;
      }),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const SignInWithRoleEvent(UserRole.coordinator));
  });

  test('SignInWithRoleEvent signs in as Responder with update & log resource permissions', () async {
    final expected = [
      const AuthLoading(),
      predicate<AuthState>((state) {
        return state is Authenticated &&
            state.user.role == UserRole.responder &&
            state.user.role.canAssignAndClose == false &&
            state.user.role.canUpdateAssignedAndLogResources == true &&
            state.user.role.isReadOnly == false;
      }),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const SignInWithRoleEvent(UserRole.responder));
  });

  test('SignInWithRoleEvent signs in as Viewer with strictly read-only permissions', () async {
    final expected = [
      const AuthLoading(),
      predicate<AuthState>((state) {
        return state is Authenticated &&
            state.user.role == UserRole.viewer &&
            state.user.role.canAssignAndClose == false &&
            state.user.role.canUpdateAssignedAndLogResources == false &&
            state.user.role.isReadOnly == true;
      }),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const SignInWithRoleEvent(UserRole.viewer));
  });

  test('SignInWithEmailPasswordEvent rejects empty credentials', () async {
    final expected = [
      const AuthLoading(),
      const AuthError('Email and password must not be empty.'),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const SignInWithEmailPasswordEvent(email: '', password: ''));
  });

  test('SignOutEvent clears session and emits Unauthenticated', () async {
    // First sign in
    await repository.signInWithRole(UserRole.coordinator);
    expect(await repository.getCurrentUser(), isNotNull);

    final expected = [
      const AuthLoading(),
      const Unauthenticated(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const SignOutEvent());

    await pumpEventQueue();
    expect(await repository.getCurrentUser(), isNull);
  });

  test('UpdateDisplayNameEvent updates user displayName and persists session', () async {
    await repository.signInWithRole(UserRole.responder);

    final expected = [
      predicate<AuthState>((state) {
        return state is Authenticated &&
            state.user.displayName == 'Marcus Updated';
      }),
    ];

    expectLater(authBloc.stream, emitsInOrder(expected));
    authBloc.add(const UpdateDisplayNameEvent('  Marcus Updated  '));

    await pumpEventQueue();
    final persisted = await repository.getCurrentUser();
    expect(persisted?.displayName, 'Marcus Updated');
  });
}

