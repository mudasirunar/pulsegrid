import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/utils/photo_file_resolver.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'features/dashboard/presentation/screens/home_screen.dart';
import 'features/incidents/presentation/bloc/incident_bloc.dart';
import 'features/incidents/presentation/bloc/incident_event.dart';
import 'features/resources/presentation/cubit/resource_cubit.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await di.initInjection();
  await PhotoFileResolver.initialize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<ThemeCubit>()),
        BlocProvider(
          create: (_) => di.sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
        ),
        BlocProvider(
          create: (_) => di.sl<IncidentBloc>()..add(const LoadIncidentsEvent()),
        ),
        BlocProvider(
          create: (_) => di.sl<ResourceCubit>(),
        ),
      ],
      child: const PulseGridApp(),
    ),
  );
}

class PulseGridApp extends StatelessWidget {
  const PulseGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'Pulse Grid',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is Authenticated) {
                return HomeScreen(user: state.user);
              }
              if (state is AuthInitial) {
                return const Scaffold(
                  body: SizedBox.shrink(),
                );
              }
              return const SignInScreen();
            },
          ),
        );
      },
    );
  }
}
