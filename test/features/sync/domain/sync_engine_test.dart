import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/core/network/network_info.dart';
import 'package:pulsegrid/features/incidents/data/models/activity_event_model.dart';
import 'package:pulsegrid/features/incidents/data/models/assignment_model.dart';
import 'package:pulsegrid/features/incidents/data/models/incident_model.dart';
import 'package:pulsegrid/features/resources/data/models/resource_log_model.dart';
import 'package:pulsegrid/features/sync/data/datasources/firestore_remote_data_source.dart';
import 'package:pulsegrid/features/sync/data/models/sync_operation_model.dart';
import 'package:pulsegrid/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:pulsegrid/features/sync/domain/repositories/sync_repository.dart';
import 'package:pulsegrid/features/sync/domain/services/sync_engine.dart';
import 'package:pulsegrid/features/sync/domain/services/sync_queue_manager.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected = true;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void emitConnectivity(bool isConnected) {
    connected = isConnected;
    _connectivityController.add(isConnected);
  }

  void dispose() {
    _connectivityController.close();
  }
}

class _FakeFirestoreRemoteDataSource implements FirestoreRemoteDataSource {
  final List<Map<String, dynamic>> pushedIncidents = [];
  final List<Map<String, dynamic>> pushedResources = [];
  final List<Map<String, dynamic>> pushedEvents = [];
  final List<String> deletedIncidentIds = [];

  List<Map<String, dynamic>> stubbedRemoteIncidents = [];
  List<Map<String, dynamic>> stubbedRemoteResources = [];
  List<Map<String, dynamic>> stubbedRemoteEvents = [];

  @override
  Future<void> pushIncident(Map<String, dynamic> incidentData) async {
    pushedIncidents.add(incidentData);
  }

  @override
  Future<void> pushResourceLog(Map<String, dynamic> resourceData) async {
    pushedResources.add(resourceData);
  }

  @override
  Future<void> pushActivityEvent(Map<String, dynamic> eventData) async {
    pushedEvents.add(eventData);
  }

  @override
  Future<void> deleteIncident(String incidentId) async {
    deletedIncidentIds.add(incidentId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullIncidents() async => stubbedRemoteIncidents;

  @override
  Future<List<Map<String, dynamic>>> pullResourceLogs({String? incidentId}) async =>
      stubbedRemoteResources;

  @override
  Future<List<Map<String, dynamic>>> pullActivityEvents({String? incidentId}) async =>
      stubbedRemoteEvents;

  @override
  Future<Map<String, dynamic>?> getRemoteIncident(String incidentId) async {
    return stubbedRemoteIncidents.firstWhere(
      (m) => m['id'] == incidentId,
      orElse: () => {},
    );
  }
}

class _FakeLocalDataSource implements LocalDataSource {
  final Map<String, IncidentModel> incidents = {};
  final List<ResourceLogModel> resources = [];
  final List<ActivityEventModel> events = [];

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
  }) async =>
      incidents.values.toList();

  @override
  Future<void> saveResourceLog(ResourceLogModel log) async {
    resources.add(log);
  }

  @override
  Future<List<ResourceLogModel>> getResourceLogsForIncident(String incidentId) async =>
      resources.where((r) => r.incidentId == incidentId).toList();

  @override
  Future<void> saveActivityEvent(ActivityEventModel event) async {
    events.add(event);
  }

  @override
  Future<List<ActivityEventModel>> getActivityTimeline(String incidentId) async =>
      events.where((e) => e.incidentId == incidentId).toList();

  @override
  Future<void> enqueueSyncOperation(SyncOperationModel operation) async {}
  @override
  Future<List<SyncOperationModel>> getPendingSyncOperations() async => [];
  @override
  Future<List<SyncOperationModel>> getAllSyncOperations() async => [];
  @override
  Future<void> updateSyncOperationState(String id, String state, {String? errorMessage, int? retryCount}) async {}
  @override
  Future<int> getPendingSyncCount() async => 0;
  @override
  Future<int> getFailedSyncCount() async => 0;
  @override
  Future<void> removeSyncOperation(String id) async {}
  @override
  Future<void> clearSyncedOperations() async {}
  @override
  Future<int> deleteIncident(String id) async {
    final existed = incidents.remove(id);
    return existed != null ? 1 : 0;
  }
  @override
  Future<void> saveAssignment(AssignmentModel assignment) async {}
  @override
  Future<AssignmentModel?> getAssignmentByIncidentId(String incidentId) async => null;
  @override
  Future<List<IncidentModel>> getOpenIncidents() async =>
      incidents.values.where((i) => i.status.toUpperCase() != 'CLOSED' && i.status.toUpperCase() != 'RESOLVED').toList();
  @override
  Future<List<IncidentModel>> getCriticalIncidents() async =>
      incidents.values.where((i) => i.severity.toUpperCase() == 'CRITICAL').toList();
  @override
  Future<List<IncidentModel>> getIncidentsAssignedTo(String responderId) async => [];
  @override
  Future<Map<String, double>> getResourceSummaryForIncident(String incidentId) async => {};
  @override
  Future<List<Map<String, dynamic>>> getDetailedResourceSummaryForIncident(String incidentId) async => [];
}

class _FakeSyncRepository implements SyncRepository {
  final List<SyncOperationEntity> ops = [];

  @override
  Future<void> enqueueOperation(SyncOperationEntity operation) async {
    ops.add(operation);
  }

  @override
  Future<List<SyncOperationEntity>> getPendingOperations() async =>
      ops.where((o) => o.status == SyncStatus.pending || o.status == SyncStatus.failed).toList();

  @override
  Future<List<SyncOperationEntity>> getAllOperations() async => List.from(ops);

  @override
  Future<void> updateOperationStatus(
    String operationId,
    SyncStatus newStatus, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final idx = ops.indexWhere((o) => o.operationId == operationId);
    if (idx != -1) {
      ops[idx] = ops[idx].copyWith(status: newStatus, errorMessage: errorMessage, retryCount: retryCount);
    }
  }

  @override
  Future<int> getPendingCount() async => ops.where((o) => o.status == SyncStatus.pending).length;
  @override
  Future<int> getFailedCount() async => ops.where((o) => o.status == SyncStatus.failed).length;
  @override
  Future<void> removeOperation(String operationId) async => ops.removeWhere((o) => o.operationId == operationId);
  @override
  Future<void> clearSyncedOperations() async => ops.removeWhere((o) => o.status == SyncStatus.synced);
}

void main() {
  late _FakeNetworkInfo fakeNetwork;
  late _FakeFirestoreRemoteDataSource fakeRemote;
  late _FakeLocalDataSource fakeLocal;
  late _FakeSyncRepository fakeSyncRepo;
  late SyncQueueManager queueManager;
  late SyncEngine syncEngine;

  setUp(() {
    fakeNetwork = _FakeNetworkInfo();
    fakeRemote = _FakeFirestoreRemoteDataSource();
    fakeLocal = _FakeLocalDataSource();
    fakeSyncRepo = _FakeSyncRepository();
    queueManager = SyncQueueManager(syncRepository: fakeSyncRepo);

    syncEngine = SyncEngine(
      queueManager: queueManager,
      remoteDataSource: fakeRemote,
      localDataSource: fakeLocal,
      networkInfo: fakeNetwork,
    );
  });

  tearDown(() {
    syncEngine.dispose();
    queueManager.dispose();
    fakeNetwork.dispose();
  });

  test('dispatchOperation pushes incident to Firestore', () async {
    final op = SyncOperationEntity(
      operationId: 'op-inc-1',
      entityId: 'inc-1',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.create,
      payload: jsonEncode({'id': 'inc-1', 'title': 'Flood in District 4'}),
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );

    await syncEngine.dispatchOperation(op);

    expect(fakeRemote.pushedIncidents.length, 1);
    expect(fakeRemote.pushedIncidents.first['id'], 'inc-1');
    expect(fakeRemote.pushedIncidents.first['title'], 'Flood in District 4');
  });

  test('dispatchOperation pushes resource log to Firestore', () async {
    final op = SyncOperationEntity(
      operationId: 'op-res-1',
      entityId: 'res-1',
      entityType: SyncEntityType.resource,
      operationType: SyncOperationType.create,
      payload: jsonEncode({'id': 'res-1', 'resourceType': 'Oxygen Tanks', 'quantity': 10}),
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );

    await syncEngine.dispatchOperation(op);

    expect(fakeRemote.pushedResources.length, 1);
    expect(fakeRemote.pushedResources.first['resourceType'], 'Oxygen Tanks');
  });

  test('dispatchOperation pushes activity event to Firestore', () async {
    final op = SyncOperationEntity(
      operationId: 'op-act-1',
      entityId: 'act-1',
      entityType: SyncEntityType.activityEvent,
      operationType: SyncOperationType.create,
      payload: jsonEncode({'id': 'act-1', 'eventType': 'STATUS_CHANGED'}),
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );

    await syncEngine.dispatchOperation(op);

    expect(fakeRemote.pushedEvents.length, 1);
    expect(fakeRemote.pushedEvents.first['eventType'], 'STATUS_CHANGED');
  });

  test('dispatchOperation deletes incident from Firestore when operationType is delete', () async {
    final op = SyncOperationEntity(
      operationId: 'op-del-1',
      entityId: 'inc-to-delete',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.delete,
      payload: jsonEncode({'id': 'inc-to-delete'}),
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );

    await syncEngine.dispatchOperation(op);

    expect(fakeRemote.deletedIncidentIds, ['inc-to-delete']);
  });

  test('initialize sets remoteSyncHandler and auto-syncs when online', () async {
    fakeNetwork.connected = true;

    // Put a pending item in queue
    await fakeSyncRepo.enqueueOperation(
      SyncOperationEntity(
        operationId: 'op-auto-1',
        entityId: 'inc-auto-1',
        entityType: SyncEntityType.incident,
        operationType: SyncOperationType.create,
        payload: jsonEncode({'id': 'inc-auto-1', 'title': 'Gas Leak'}),
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
      ),
    );

    await syncEngine.initialize();

    expect(queueManager.remoteSyncHandler, isNotNull);
    expect(fakeRemote.pushedIncidents.length, 1);
    expect(fakeSyncRepo.ops.first.status, SyncStatus.synced);
  });

  test('in Airplane Mode (offline), syncAll does not dispatch and keeps operations safely queued', () async {
    fakeNetwork.connected = false;
    await syncEngine.initialize();

    await fakeSyncRepo.enqueueOperation(
      SyncOperationEntity(
        operationId: 'op-offline-1',
        entityId: 'inc-offline-1',
        entityType: SyncEntityType.incident,
        operationType: SyncOperationType.create,
        payload: jsonEncode({'id': 'inc-offline-1', 'title': 'Earthquake'}),
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
      ),
    );

    await syncEngine.syncAll();

    expect(fakeRemote.pushedIncidents, isEmpty);
    expect(fakeSyncRepo.ops.first.status, SyncStatus.pending);

    // Reconnecting triggers sync
    fakeNetwork.emitConnectivity(true);
    await pumpEventQueue();

    expect(fakeRemote.pushedIncidents.length, 1);
    expect(fakeSyncRepo.ops.first.status, SyncStatus.synced);
  });

  test('pullRemoteUpdates pulls remote Firestore incidents and saves locally', () async {
    fakeRemote.stubbedRemoteIncidents = [
      {
        'id': 'remote-inc-1',
        'title': 'Wildfire Alert',
        'category': 'Fire',
        'severity': 'Critical',
        'description': 'Rapidly spreading brush fire',
        'status': 'In Progress',
        'version': 2,
        'createdBy': 'coord-99',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }
    ];

    await syncEngine.pullRemoteUpdates();

    final saved = fakeLocal.incidents['remote-inc-1'];
    expect(saved, isNotNull);
    expect(saved!.title, 'Wildfire Alert');
    expect(saved.version, 2);
  });
}
