import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/app_database.dart';
import 'core/network/network_info.dart';
import 'core/theme/theme_cubit.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // -------------------------------------------------------------
  // External Core Services
  // -------------------------------------------------------------
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // -------------------------------------------------------------
  // Core Infrastructure
  // -------------------------------------------------------------
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // -------------------------------------------------------------
  // Theme Feature
  // -------------------------------------------------------------
  sl.registerFactory<ThemeCubit>(() => ThemeCubit(sl()));
}

