import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_event.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_state.dart';

class _MockRepo implements IncidentRepository {
  final List<IncidentEntity> items = [];
  final StreamController<void> incidentsChangedController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onIncidentsChanged => incidentsChangedController.stream;

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async {
    items.add(incident);
    return incident;
  }

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async => items;

  @override
  Future<IncidentEntity?> getIncidentById(String id) async {
    return items.firstWhere((i) => i.id == id);
  }

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async {
    final index = items.indexWhere((i) => i.id == incidentId);
    final updated = items[index].copyWith(
      status: targetStatus,
      version: items[index].version + 1,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<IncidentEntity> updateIncident({
    required IncidentEntity updatedIncident,
    required UserEntity actor,
  }) async => updatedIncident;

  @override
  Future<void> deleteIncident({
    required String incidentId,
    required UserEntity actor,
  }) async {
    items.removeWhere((i) => i.id == incidentId);
  }

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async => [];

  @override
  Future<IncidentEntity> assignResponder({
    required String incidentId,
    required UserEntity responder,
    required UserEntity actor,
  }) async => throw UnimplementedError();

  @override
  Future<List<UserEntity>> getResponders({bool forceRefresh = false}) async => const [];

  @override
  Future<Map<String, int>> getResponderActiveCounts() async => const {};
}

void main() {
  late _MockRepo repository;
  late IncidentBloc bloc;

  final user = const UserEntity(
    id: 'user_1',
    email: 'user@pulsegrid.com',
    displayName: 'Lead Responder',
    role: UserRole.responder,
  );

  setUp(() {
    repository = _MockRepo();
    bloc = IncidentBloc(incidentRepository: repository);
  });

  tearDown(() => bloc.close());

  test('initial state is IncidentInitial', () {
    expect(bloc.state, const IncidentInitial());
  });

  test('LoadIncidentsEvent emits [IncidentLoading, IncidentLoaded]', () async {
    final expectedStates = [
      const IncidentLoading(),
      const IncidentLoaded([]),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));
    bloc.add(const LoadIncidentsEvent());
  });

  test('CreateIncidentEvent creates incident successfully', () async {
    final expectedStates = [
      isA<IncidentCreating>(),
      isA<IncidentCreatedSuccess>(),
    ];

    expectLater(bloc.stream, emitsInOrder(expectedStates));

    bloc.add(
      CreateIncidentEvent(
        title: 'Gas Leak',
        category: 'Hazmat',
        severity: IncidentSeverity.high,
        description: 'Smell of methane reported near warehouse',
        creator: user,
      ),
    );
  });

  test('onIncidentsChanged triggers quiet refresh without emitting IncidentLoading', () async {
    final newIncident = IncidentEntity(
      id: 'inc-bg-1',
      title: 'Power Outage',
      category: 'Infrastructure',
      severity: IncidentSeverity.medium,
      description: 'Grid failure',
      status: IncidentStatus.newIncident,
      version: 1,
      createdBy: 'user-test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    repository.items.add(newIncident);

    // Initial load
    bloc.add(const LoadIncidentsEvent());
    await pumpEventQueue();
    expect((bloc.state as IncidentLoaded).incidents.length, 1);

    // Another incident added by background sync
    final secondIncident = IncidentEntity(
      id: 'inc-bg-2',
      title: 'Water Main Break',
      category: 'Infrastructure',
      severity: IncidentSeverity.low,
      description: 'Street flooding',
      status: IncidentStatus.newIncident,
      version: 1,
      createdBy: 'user-test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    repository.items.add(secondIncident);

    // Repository emits onIncidentsChanged
    repository.incidentsChangedController.add(null);
    await pumpEventQueue();

    // Bloc updates state quietly
    expect(bloc.state, isA<IncidentLoaded>());
    expect((bloc.state as IncidentLoaded).incidents.length, 2);
  });
}

