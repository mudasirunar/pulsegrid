import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/app_database.dart';
import 'core/database/local_data_source.dart';
import 'core/network/network_info.dart';
import 'core/preferences/app_preferences_cubit.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/incidents/data/repositories/incident_repository_impl.dart';
import 'features/incidents/domain/repositories/incident_repository.dart';
import 'features/incidents/domain/services/location_service.dart';
import 'features/incidents/domain/services/media_service.dart';
import 'features/incidents/presentation/bloc/incident_bloc.dart';
import 'features/resources/data/repositories/resource_repository_impl.dart';
import 'features/resources/domain/repositories/resource_repository.dart';
import 'features/resources/presentation/cubit/resource_cubit.dart';
import 'features/sync/data/datasources/firestore_remote_data_source.dart';
import 'features/sync/data/repositories/sync_repository_impl.dart';
import 'features/sync/domain/repositories/sync_repository.dart';
import 'features/sync/domain/services/sync_engine.dart';
import 'features/sync/domain/services/sync_queue_manager.dart';
import 'features/sync/presentation/bloc/sync_bloc.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // -------------------------------------------------------------
  // External Core Services
  // -------------------------------------------------------------
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  sl.registerLazySingleton<LocalDataSource>(() => LocalDataSourceImpl(sl()));

  // -------------------------------------------------------------
  // Core Infrastructure
  // -------------------------------------------------------------
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // -------------------------------------------------------------
  // Theme Feature
  // -------------------------------------------------------------
  sl.registerFactory<ThemeCubit>(() => ThemeCubit(sl()));
  sl.registerFactory<AppPreferencesCubit>(() => AppPreferencesCubit(sl()));

  // -------------------------------------------------------------
  // Authentication & RBAC Feature
  // -------------------------------------------------------------
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      sharedPreferences: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: sl(),
      syncEngine: sl(),
    ),
  );

  // -------------------------------------------------------------
  // Incidents Feature
  // -------------------------------------------------------------
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<MediaService>(() => MediaServiceImpl());
  sl.registerLazySingleton<IncidentRepository>(
    () => IncidentRepositoryImpl(localDataSource: sl()),
  );
  sl.registerFactory<IncidentBloc>(
    () => IncidentBloc(incidentRepository: sl()),
  );

  // -------------------------------------------------------------
  // Resources Feature
  // -------------------------------------------------------------
  sl.registerLazySingleton<ResourceRepository>(
    () => ResourceRepositoryImpl(localDataSource: sl()),
  );
  sl.registerFactory<ResourceCubit>(
    () => ResourceCubit(resourceRepository: sl()),
  );

  // -------------------------------------------------------------
  // Sync Engine & Queue Feature
  // -------------------------------------------------------------
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirestoreRemoteDataSource>(
    () => FirestoreRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<SyncQueueManager>(
    () => SyncQueueManager(syncRepository: sl()),
  );
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      queueManager: sl(),
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      firebaseAuth: sl(),
    ),
  );
  sl.registerFactory<SyncBloc>(
    () => SyncBloc(syncQueueManager: sl()),
  );
}
