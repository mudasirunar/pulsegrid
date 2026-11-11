import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulsegrid/core/theme/app_theme.dart';
import 'package:pulsegrid/core/widgets/app_button.dart';
import 'package:pulsegrid/core/widgets/app_text_field.dart';
import 'package:pulsegrid/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pulsegrid/features/auth/domain/repositories/auth_repository.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_state.dart';
import 'package:pulsegrid/features/auth/presentation/screens/sign_in_screen.dart';

class MockAuthBloc extends AuthBloc {
  MockAuthBloc(AuthRepository authRepository, {super.initialState = const Unauthenticated()})
      : super(authRepository: authRepository);

  void emitState(AuthState state) => emit(state);
}

void main() {
  late SharedPreferences prefs;
  late AuthRepositoryImpl repository;
  late MockAuthBloc authBloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = AuthRepositoryImpl(sharedPreferences: prefs);
    authBloc = MockAuthBloc(repository);
  });

  tearDown(() {
    authBloc.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const SignInScreen(),
      ),
    );
  }

  testWidgets('Validation: Invalid email shows error on email only, clears on keystroke', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFields = find.byType(AppTextField);
    final emailField = textFields.first;
    final passwordField = textFields.last;

    // Set invalid email and valid password
    await tester.enterText(emailField, 'invalid-email');
    await tester.enterText(passwordField, 'ValidPassword123!');
    await tester.pumpAndSettle();

    // Tap Sign In
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Verify error is shown on email ONLY
    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsNothing);
    expect(find.text('Password is required'), findsNothing);

    // Start typing in email field -> error immediately clears
    await tester.enterText(emailField, 'valid@pulsegrid.org');
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsNothing);
  });

  testWidgets('Validation: Short password (<6 chars) shows error on password only, clears on keystroke', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFields = find.byType(AppTextField);
    final emailField = textFields.first;
    final passwordField = textFields.last;

    // Set valid email and short password
    await tester.enterText(emailField, 'coordinator@pulsegrid.org');
    await tester.enterText(passwordField, '123');
    await tester.pumpAndSettle();

    // Tap Sign In
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Verify error is shown on password ONLY
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(find.text('Email is required'), findsNothing);
    expect(find.text('Please enter a valid email address'), findsNothing);

    // Start typing in password field -> error immediately clears
    await tester.enterText(passwordField, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsNothing);
  });

  testWidgets('AuthLoading state shows in-button spinner and disables role toggle', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    authBloc = MockAuthBloc(repository, initialState: const AuthLoading());
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Verify in-button progress indicator is present
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify role toggle is absorbed/disabled
    final absorbPointer = tester.widget<AbsorbPointer>(
      find.byWidgetPredicate((widget) => widget is AbsorbPointer && widget.absorbing == true),
    );
    expect(absorbPointer.absorbing, isTrue);

    // Sign in button is disabled
    final appButton = tester.widget<AppButton>(find.byType(AppButton));
    expect(appButton.isDisabled, isTrue);
    expect(appButton.isLoading, isTrue);
  });

  testWidgets('AuthError state displays custom AppSnackBar', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Trigger an error in authBloc
    authBloc.emitState(const AuthError('Invalid credentials entered.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // allow snackbar entrance animation

    // AppSnackBar content is visible
    expect(find.text('Authentication Error'), findsOneWidget);
    expect(find.text('Invalid credentials entered.'), findsOneWidget);
  });
}
