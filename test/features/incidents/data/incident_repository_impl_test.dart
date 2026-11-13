import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/data/models/activity_event_model.dart';
import 'package:pulsegrid/features/incidents/data/models/assignment_model.dart';
import 'package:pulsegrid/features/incidents/data/models/incident_model.dart';
import 'package:pulsegrid/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/resources/data/models/resource_log_model.dart';
import 'package:pulsegrid/features/sync/data/models/sync_operation_model.dart';

class _InMemoryLocalDataSource implements LocalDataSource {
  final Map<String, IncidentModel> incidents = {};
  final List<ActivityEventModel> activityEvents = [];
  final List<SyncOperationModel> syncOps = [];

  @override
  Stream<String> get onTableChanged => const Stream.empty();

  @override
  Future<void> saveIncident(IncidentModel incident) async {
    incidents[incident.id] = incident;
  }

  @override
  Future<IncidentModel?> getIncidentById(String id) async => incidents[id];

  @override
  Future<List<IncidentModel>> getAllIncidents({
    String? query,
    String? severity,
    String? status,
    String? assignedResponderId,
    String? sortBy,
  }) async {
    var result = incidents.values.toList();
    if (status != null) {
      result = result.where((i) => i.status == status).toList();
    }
    if (severity != null) {
      result = result.where((i) => i.severity == severity).toList();
    }
    if (query != null && query.isNotEmpty) {
      result = result
          .where((i) =>
              i.title.toLowerCase().contains(query.toLowerCase()) ||
              i.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    return result;
  }

  @override
  Future<List<IncidentModel>> getOpenIncidents() async =>
      incidents.values.where((i) => i.status != 'Closed').toList();

  @override
  Future<List<IncidentModel>> getCriticalIncidents() async =>
      incidents.values.where((i) => i.severity == 'Critical').toList();

  @override
  Future<int> deleteIncident(String id) async {
    return incidents.remove(id) != null ? 1 : 0;
  }

  @override
  Future<void> saveAssignment(AssignmentModel assignment) async {}

  @override
  Future<AssignmentModel?> getAssignmentByIncidentId(String incidentId) async => null;

  @override
  Future<List<AssignmentModel>> getAllAssignments() async => const [];

  @override
  Future<Map<String, int>> getActiveIncidentCountsByResponder() async => const {};

  @override
  Future<List<IncidentModel>> getIncidentsAssignedTo(String responderId) async => [];

  @override
  Future<void> saveResourceLog(ResourceLogModel log) async {}

  @override
  Future<List<ResourceLogModel>> getResourceLogsForIncident(String incidentId) async => [];

  @override
  Future<Map<String, double>> getResourceSummaryForIncident(String incidentId) async => {};

  @override
  Future<List<Map<String, dynamic>>> getDetailedResourceSummaryForIncident(String incidentId) async => [];

  @override
  Future<void> saveActivityEvent(ActivityEventModel event) async {
    activityEvents.add(event);
  }

  @override
  Future<List<ActivityEventModel>> getActivityTimeline(String incidentId) async {
    return activityEvents.where((e) => e.incidentId == incidentId).toList();
  }

  @override
  Future<void> enqueueSyncOperation(SyncOperationModel operation) async {
    syncOps.add(operation);
  }

  @override
  Future<List<SyncOperationModel>> getPendingSyncOperations() async => syncOps;

  @override
  Future<void> updateSyncOperationState(
    String operationId,
    String newState, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final idx = syncOps.indexWhere((o) => o.operationId == operationId);
    if (idx != -1) {
      syncOps[idx] = syncOps[idx].copyWith(syncState: newState);
    }
  }

  @override
  Future<int> getPendingSyncCount() async => syncOps.length;

  @override
  Future<List<SyncOperationModel>> getAllSyncOperations() async => syncOps;

  @override
  Future<int> getFailedSyncCount() async =>
      syncOps.where((o) => o.syncState == 'FAILED').length;

  @override
  Future<void> clearSyncedOperations() async {
    syncOps.removeWhere((o) => o.syncState == 'SYNCED');
  }

  @override
  Future<void> removeSyncOperation(String operationId) async {
    syncOps.removeWhere((o) => o.operationId == operationId);
  }
}

void main() {
  late _InMemoryLocalDataSource localDataSource;
  late IncidentRepositoryImpl repository;

  final coordinator = const UserEntity(
    id: 'coord_01',
    email: 'coordinator@pulsegrid.com',
    displayName: 'Chief Coordinator',
    role: UserRole.coordinator,
  );

  setUp(() {
    localDataSource = _InMemoryLocalDataSource();
    repository = IncidentRepositoryImpl(localDataSource: localDataSource);
  });

  test('createIncident saves incident to SQLite, records creation audit event, and queues sync op', () async {
    final now = DateTime.now();
    final incident = IncidentEntity(
      id: 'inc_test_1',
      title: 'Chemical Leakage',
      category: 'Hazmat',
      severity: IncidentSeverity.critical,
      description: 'Container breached at dock 4',
      status: IncidentStatus.newIncident,
      version: 1,
      latitude: 37.7749,
      longitude: -122.4194,
      createdBy: coordinator.id,
      createdAt: now,
      updatedAt: now,
    );

    final result = await repository.createIncident(incident);

    expect(result.id, 'inc_test_1');
    expect(localDataSource.incidents.containsKey('inc_test_1'), isTrue);

    // Verify audit event
    expect(localDataSource.activityEvents.length, 1);
    expect(localDataSource.activityEvents.first.eventType, 'INCIDENT_CREATED');
    expect(localDataSource.activityEvents.first.incidentId, 'inc_test_1');

    // Verify sync queue (INCIDENT + ACTIVITY_EVENT)
    expect(localDataSource.syncOps.length, 2);
    expect(localDataSource.syncOps.first.entityId, 'inc_test_1');
    expect(localDataSource.syncOps.first.operationType, 'INSERT');
    expect(localDataSource.syncOps.first.syncState, 'PENDING');
    expect(localDataSource.syncOps[1].entityType, 'ACTIVITY_EVENT');
  });

  test('updateIncidentStatus executes state machine, updates SQLite, and logs transition event', () async {
    final now = DateTime.now();
    final incident = IncidentEntity(
      id: 'inc_test_2',
      title: 'Power Failure',
      category: 'Infrastructure',
      severity: IncidentSeverity.high,
      description: 'Hospital backup grid offline',
      status: IncidentStatus.newIncident,
      version: 1,
      createdBy: coordinator.id,
      createdAt: now,
      updatedAt: now,
    );

    await repository.createIncident(incident);

    // Transition New -> Assigned
    final updated = await repository.updateIncidentStatus(
      incidentId: 'inc_test_2',
      targetStatus: IncidentStatus.assigned,
      actor: coordinator,
    );

    expect(updated.status, IncidentStatus.assigned);
    expect(updated.version, 2);

    // Verify timeline has 2 events (created + status change)
    final timeline = await repository.getActivityTimeline('inc_test_2');
    expect(timeline.length, 2);
    expect(timeline.last.eventType.value, 'STATUS_CHANGE');
    expect(timeline.last.oldValue, 'New');
    expect(timeline.last.newValue, 'Assigned');

    // Verify sync ops has 4 (INSERT INCIDENT + CREATE EVENT + STATUS_CHANGE EVENT + UPDATE INCIDENT)
    expect(localDataSource.syncOps.length, 4);
    expect(localDataSource.syncOps[2].entityType, 'ACTIVITY_EVENT');
    expect(localDataSource.syncOps.last.operationType, 'UPDATE');
  });
}
