import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/preferences/app_preferences_cubit.dart';
import 'package:pulsegrid/core/theme/theme_cubit.dart';
import 'package:pulsegrid/features/auth/data/models/user_model.dart';
import 'package:pulsegrid/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_state.dart';
import 'package:pulsegrid/features/profile/presentation/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ThemeCubit themeCubit;
  late AppPreferencesCubit prefsCubit;
  late AuthRepositoryImpl authRepository;
  late AuthBloc authBloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    themeCubit = ThemeCubit(prefs);
    prefsCubit = AppPreferencesCubit(prefs);
    authRepository = AuthRepositoryImpl(sharedPreferences: prefs);
    authBloc = AuthBloc(
      authRepository: authRepository,
      initialState: const Authenticated(AuthRepositoryImpl.coordinatorDemo),
    );
  });

  tearDown(() async {
    await themeCubit.close();
    await prefsCubit.close();
    await authBloc.close();
  });

  Widget buildSubject(UserModel user) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: themeCubit),
        BlocProvider<AppPreferencesCubit>.value(value: prefsCubit),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp(
        home: ProfileScreen(user: user),
      ),
    );
  }

  testWidgets('renders flat identity header without AppBar or Profile title', (tester) async {
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.text(AuthRepositoryImpl.coordinatorDemo.displayName), findsOneWidget);
    expect(find.text('(${AuthRepositoryImpl.coordinatorDemo.rank})'), findsOneWidget);
    expect(find.text(AuthRepositoryImpl.coordinatorDemo.email), findsOneWidget);
    expect(find.text('Coordinator'), findsOneWidget);
  });

  testWidgets('shows role-aware stats for Coordinator & Responder, hides for Viewer', (tester) async {
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Assigned Out'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.responderDemo));
    await tester.pump();
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);

    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.viewerDemo));
    await tester.pump();
    expect(find.text('Reported'), findsNothing);
    expect(find.text('Assigned'), findsNothing);
  });

  testWidgets('3-way theme selector updates ThemeCubit in System -> Light -> Dark order', (tester) async {
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));

    expect(themeCubit.state, ThemeMode.system);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(themeCubit.state, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(themeCubit.state, ThemeMode.light);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(themeCubit.state, ThemeMode.system);
  });

  testWidgets('animated preference switches update AppPreferencesCubit', (tester) async {
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));

    await tester.ensureVisible(find.text('Haptic Feedback'));
    await tester.tap(find.text('Haptic Feedback'));
    await tester.pumpAndSettle();
    expect(prefsCubit.state.hapticEnabled, isFalse);

    await tester.ensureVisible(find.text('Compact Incident List'));
    await tester.tap(find.text('Compact Incident List'));
    await tester.pumpAndSettle();
    expect(prefsCubit.state.compactCards, isTrue);
  });

  testWidgets('Sign Out button opens confirmation dialog before signing out', (tester) async {
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));

    await tester.ensureVisible(find.text('Sign Out'));
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to sign out of Pulse Grid?'), findsOneWidget);
    expect(authBloc.state, isA<Authenticated>());

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(authBloc.state, isA<Authenticated>());
  });

  testWidgets('Edit Display Name dialog autofocuses, saves, and closes without error', (tester) async {
    await authRepository.signInWithRole(UserRole.coordinator);
    await tester.pumpWidget(buildSubject(AuthRepositoryImpl.coordinatorDemo));

    await tester.tap(find.byTooltip('Edit display name'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Display Name'), findsOneWidget);
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.autofocus, isTrue);

    await tester.enterText(find.byType(TextFormField), 'Sarah Updated');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Edit Display Name'), findsNothing);
    expect((authBloc.state as Authenticated).user.displayName, 'Sarah Updated');
  });
}

