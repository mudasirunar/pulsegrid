import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/database/database_constants.dart';
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
  Set<String> stubbedDeletedIncidentIds = {};
  List<Map<String, dynamic>> stubbedRemoteResources = [];
  List<Map<String, dynamic>> stubbedRemoteEvents = [];

  final StreamController<List<Map<String, dynamic>>> incidentsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<String> removedIdsController =
      StreamController<String>.broadcast();
  final StreamController<List<String>> deletedTombstonesController =
      StreamController<List<String>>.broadcast();
  final StreamController<Map<String, dynamic>?> singleIncidentController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final StreamController<List<Map<String, dynamic>>> resourcesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> eventsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  Stream<List<Map<String, dynamic>>> watchIncidents() => incidentsController.stream;

  @override
  Stream<String> watchRemovedIncidentIds() => removedIdsController.stream;

  @override
  Stream<List<String>> watchDeletedIncidentIds() => deletedTombstonesController.stream;

  @override
  Stream<Map<String, dynamic>?> watchIncident(String incidentId) =>
      singleIncidentController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchResourceLogs(String incidentId) =>
      resourcesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchActivityEvents(String incidentId) =>
      eventsController.stream;

  @override
  Future<void> pushIncident(
    Map<String, dynamic> incidentData, {
    bool isUpdate = false,
  }) async {
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
  Future<void> pushAssignment(Map<String, dynamic> assignmentData) async {}

  @override
  Future<List<Map<String, dynamic>>> pullAssignments({String? incidentId}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchResponders() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchAllAssignments() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> watchAssignments(String incidentId) => const Stream.empty();

  @override
  Future<void> deleteIncident(String incidentId) async {
    deletedIncidentIds.add(incidentId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullIncidents() async => stubbedRemoteIncidents;

  @override
  Future<Set<String>> pullDeletedIncidentIds() async => stubbedDeletedIncidentIds;

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
  final StreamController<String> tableChangeController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onTableChanged => tableChangeController.stream;

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
  Future<List<AssignmentModel>> getAllAssignments() async => const [];
  @override
  Future<Map<String, int>> getActiveIncidentCountsByResponder() async => const {};
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

  test('live WebSocket stream from Firestore mirrors incoming remote incidents into SQLite', () async {
    await syncEngine.initialize();

    // Remote Firestore emits a new incident via snapshot WebSocket stream
    fakeRemote.incidentsController.add([
      {
        'id': 'ws-inc-1',
        'title': 'Chemical Leak Detected',
        'category': 'Hazmat',
        'severity': 'Critical',
        'description': 'Toxic fumes in Sector B',
        'status': 'New',
        'version': 1,
        'createdBy': 'user-remote',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }
    ]);
    await pumpEventQueue();

    final localIncident = fakeLocal.incidents['ws-inc-1'];
    expect(localIncident, isNotNull);
    expect(localIncident!.title, 'Chemical Leak Detected');
    expect(localIncident.category, 'Hazmat');
  });

  test('scoped watchIncidentDetails mirrors remote resource logs and activity events into SQLite', () async {
    final scopedSub = syncEngine.watchIncidentDetails('inc-100');

    // Remote emits resource log for inc-100
    fakeRemote.resourcesController.add([
      {
        'id': 'res-live-1',
        'incidentId': 'inc-100',
        'resourceType': 'Water',
        'quantity': 50.0,
        'unit': 'Liters',
        'notes': 'Delivered by drone',
        'loggedBy': 'pilot-1',
        'createdAt': DateTime.now().toIso8601String(),
      }
    ]);

    // Remote emits activity event for inc-100
    fakeRemote.eventsController.add([
      {
        'id': 'evt-live-1',
        'incidentId': 'inc-100',
        'actorId': 'pilot-1',
        'eventType': 'RESOURCE_LOGGED',
        'oldValue': null,
        'newValue': '50 Liters of Water',
        'timestamp': DateTime.now().toIso8601String(),
      }
    ]);
    await pumpEventQueue();

    expect(fakeLocal.resources.length, 1);
    expect(fakeLocal.resources.first.id, 'res-live-1');
    expect(fakeLocal.resources.first.quantity, 50.0);

    expect(fakeLocal.events.length, 1);
    expect(fakeLocal.events.first.id, 'evt-live-1');

    await scopedSub.cancel();
  });

  test('enqueuing a sync operation triggers immediate outbound push in background', () async {
    fakeNetwork.connected = true;
    await syncEngine.initialize();

    await fakeSyncRepo.enqueueOperation(
      SyncOperationEntity(
        operationId: 'op-auto-push-1',
        entityId: 'inc-auto-1',
        entityType: SyncEntityType.incident,
        operationType: SyncOperationType.create,
        payload: jsonEncode({'id': 'inc-auto-1', 'title': 'Flash Flood'}),
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
      ),
    );

    // Emitting tableSyncOperations on SQLite change stream triggers push
    fakeLocal.tableChangeController.add(DatabaseConstants.tableSyncOperations);
    await pumpEventQueue();

    expect(fakeRemote.pushedIncidents.length, 1);
    expect(fakeRemote.pushedIncidents.first['id'], 'inc-auto-1');
    expect(fakeSyncRepo.ops.first.status, SyncStatus.synced);
  });

  test('Last-Write-Wins: newer remote updatedAt overwrites local even with same version; older is ignored', () async {
    final t1 = DateTime.utc(2026, 11, 13, 10, 0, 0, 0);
    final t2 = DateTime.utc(2026, 11, 13, 10, 0, 0, 1); // 1ms later
    final t0 = DateTime.utc(2026, 11, 13, 9, 59, 59, 999); // 1ms earlier

    await fakeLocal.saveIncident(
      IncidentModel(
        id: 'inc-lww-1',
        title: 'Local Version',
        category: 'Fire',
        severity: 'High',
        description: 'Local desc',
        status: 'New',
        version: 2,
        createdBy: 'u1',
        createdAt: t0,
        updatedAt: t1,
      ),
    );

    await syncEngine.initialize();

    // 1. Older remote update (1ms earlier) is ignored
    fakeRemote.incidentsController.add([
      {
        'id': 'inc-lww-1',
        'title': 'Stale Remote Version',
        'category': 'Fire',
        'severity': 'High',
        'description': 'Stale',
        'status': 'New',
        'version': 2,
        'createdBy': 'u1',
        'createdAt': t0.toIso8601String(),
        'updatedAt': t0.toIso8601String(),
      }
    ]);
    await pumpEventQueue();
    expect((await fakeLocal.getIncidentById('inc-lww-1'))?.title, 'Local Version');

    // 2. Newer remote update (1ms later) overwrites local
    fakeRemote.incidentsController.add([
      {
        'id': 'inc-lww-1',
        'title': 'Newer Remote Version',
        'category': 'Fire',
        'severity': 'Critical',
        'description': 'Updated',
        'status': 'New',
        'version': 2,
        'createdBy': 'u1',
        'createdAt': t0.toIso8601String(),
        'updatedAt': t2.toIso8601String(),
      }
    ]);
    await pumpEventQueue();
    final after = await fakeLocal.getIncidentById('inc-lww-1');
    expect(after?.title, 'Newer Remote Version');
    expect(after?.severity, 'Critical');
  });

  test('Remote deletion tombstone purges local SQLite and broadcasts on onIncidentDeletedRemote', () async {
    final now = DateTime.utc(2026, 11, 13, 10, 0);
    await fakeLocal.saveIncident(
      IncidentModel(
        id: 'inc-del-1',
        title: 'To Be Deleted Remotely',
        category: 'Medical',
        severity: 'Low',
        description: 'desc',
        status: 'New',
        version: 1,
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final deletedEvents = <String>[];
    final sub = syncEngine.onIncidentDeletedRemote.listen(deletedEvents.add);

    await syncEngine.initialize();
    fakeRemote.deletedTombstonesController.add(['inc-del-1']);
    await pumpEventQueue();

    expect(await fakeLocal.getIncidentById('inc-del-1'), isNull);
    expect(deletedEvents, contains('inc-del-1'));
    await sub.cancel();
  });
}
