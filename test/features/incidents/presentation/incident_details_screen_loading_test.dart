import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/incident_details_screen.dart';
import 'package:pulsegrid/features/incidents/presentation/widgets/incident_details_skeleton.dart';

class _MockRepo implements IncidentRepository {
  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<IncidentEntity?> getIncidentById(String id) async => null;

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async => incident;

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async => throw UnimplementedError();

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async => [];
}

void main() {
  const dummyUser = UserEntity(
    id: 'user-01',
    email: 'test@pulsegrid.com',
    displayName: 'Test User',
    role: UserRole.coordinator,
  );

  final dummyIncident = IncidentEntity(
    id: 'inc-01',
    title: 'Gas Leak Detected',
    category: 'Hazard',
    severity: IncidentSeverity.high,
    description: 'Gas pipeline pressure abnormal.',
    status: IncidentStatus.newIncident,
    createdBy: 'user-01',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('IncidentDetailsScreen displays IncidentDetailsSkeleton and no status chip when isLoading is true', (tester) async {
    final repo = _MockRepo();
    final bloc = IncidentBloc(incidentRepository: repo);

    await tester.pumpWidget(
      BlocProvider<IncidentBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: IncidentDetailsScreen(
            incident: dummyIncident,
            currentUser: dummyUser,
            isLoading: true,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IncidentDetailsSkeleton), findsOneWidget);
    expect(find.text('Incident Details'), findsOneWidget);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('IncidentDetailsScreen displays incident content and status chip immediately when loaded (instant offline cache)', (tester) async {
    final repo = _MockRepo();
    final bloc = IncidentBloc(incidentRepository: repo);

    await tester.pumpWidget(
      BlocProvider<IncidentBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: IncidentDetailsScreen(
            incident: dummyIncident,
            currentUser: dummyUser,
            isLoading: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IncidentDetailsSkeleton), findsNothing);
    expect(find.text('Gas Leak Detected'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
  });
}
