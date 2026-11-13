import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsegrid/core/theme/theme_cubit.dart';
import 'package:pulsegrid/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pulsegrid/features/auth/presentation/bloc/auth_state.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_state.dart';
import 'package:pulsegrid/features/sync/domain/services/sync_queue_manager.dart';
import 'package:pulsegrid/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:pulsegrid/main.dart';

class _FakeIncidentRepository implements IncidentRepository {
  @override
  Stream<void> get onIncidentsChanged => const Stream.empty();

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async => incident;

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async => [];

  @override
  Future<IncidentEntity?> getIncidentById(String id) async => null;

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<IncidentEntity> updateIncident({
    required IncidentEntity updatedIncident,
    required actor,
  }) async => updatedIncident;

  @override
  Future<void> deleteIncident({
    required String incidentId,
    required actor,
  }) async {}

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<IncidentEntity> assignResponder({
    required String incidentId,
    required responder,
    required actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<UserEntity>> getResponders({bool forceRefresh = false}) async => const [];

  @override
  Future<Map<String, int>> getResponderActiveCounts() async => const {};
}

class _FakeSyncQueueManager extends Fake implements SyncQueueManager {
  @override
  Stream<SyncQueueMetrics> get metricsStream => const Stream.empty();
}

void main() {
  late SharedPreferences prefs;
  late AuthRepositoryImpl authRepository;
  late ThemeCubit themeCubit;
  late IncidentBloc incidentBloc;
  late SyncBloc syncBloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authRepository = AuthRepositoryImpl(sharedPreferences: prefs);
    themeCubit = ThemeCubit(prefs);
    incidentBloc = IncidentBloc(
      incidentRepository: _FakeIncidentRepository(),
      initialState: const IncidentLoaded([]),
    );
    syncBloc = SyncBloc(syncQueueManager: _FakeSyncQueueManager());
  });

  tearDown(() {
    themeCubit.close();
    incidentBloc.close();
    syncBloc.close();
  });

  Widget createWidgetUnderTest(AuthBloc authBloc) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: themeCubit),
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<IncidentBloc>.value(value: incidentBloc),
        BlocProvider<SyncBloc>.value(value: syncBloc),
      ],
      child: const PulseGridApp(),
    );
  }

  testWidgets('Renders SignInScreen when unauthenticated and displays role toggle and form',
      (WidgetTester tester) async {
    final authBloc = AuthBloc(
      authRepository: authRepository,
      initialState: const Unauthenticated(),
    );

    await tester.pumpWidget(createWidgetUnderTest(authBloc));
    await tester.pump();

    expect(find.text('PULSE GRID'), findsOneWidget);
    expect(find.text('SELECT OPERATIONAL ROLE'), findsOneWidget);
    expect(find.text('Coordinator'), findsOneWidget);
    expect(find.text('Responder'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    authBloc.close();
  });

  testWidgets('Signing in as Coordinator displays coordinator permissions and capabilities',
      (WidgetTester tester) async {
    final authBloc = AuthBloc(
      authRepository: authRepository,
      initialState: const Authenticated(AuthRepositoryImpl.coordinatorDemo),
    );

    await tester.pumpWidget(createWidgetUnderTest(authBloc));
    await tester.pump();

    // Verify HomeScreen renders with coordinator dashboard metrics and + CTA
    expect(find.text('Pulse Grid'), findsOneWidget);
    expect(find.text('Assigned to Me'), findsOneWidget);
    expect(find.text('Pending Sync'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    authBloc.close();
  });

  testWidgets('Signing in as Viewer hides + CTA and operational metrics (Role Guarding)',
      (WidgetTester tester) async {
    final authBloc = AuthBloc(
      authRepository: authRepository,
      initialState: const Authenticated(AuthRepositoryImpl.viewerDemo),
    );

    await tester.pumpWidget(createWidgetUnderTest(authBloc));
    await tester.pump();

    expect(find.text('Pulse Grid'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.text('Assigned to Me'), findsNothing);
    expect(find.text('Pending Sync'), findsNothing);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);

    authBloc.close();
  });
}
