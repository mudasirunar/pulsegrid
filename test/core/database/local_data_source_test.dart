import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pulsegrid/core/database/app_database.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/features/incidents/data/models/activity_event_model.dart';
import 'package:pulsegrid/features/incidents/data/models/assignment_model.dart';
import 'package:pulsegrid/features/incidents/data/models/incident_model.dart';
import 'package:pulsegrid/features/resources/data/models/resource_log_model.dart';
import 'package:pulsegrid/features/sync/data/models/sync_operation_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late LocalDataSource localDataSource;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    localDataSource = LocalDataSourceImpl(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  IncidentModel createSampleIncident({
    String id = 'inc-100',
    String title = 'Pipeline Leak',
    String category = 'Infrastructure',
    String severity = 'High',
    String status = 'New',
  }) {
    final now = DateTime.now();
    return IncidentModel(
      id: id,
      title: title,
      category: category,
      severity: severity,
      description: 'Pipeline valve failure emitting fumes',
      status: status,
      version: 1,
      latitude: 24.8607,
      longitude: 67.0011,
      createdBy: 'coordinator-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('Incident CRUD, filtering by status and severity, and search', () async {
    final inc1 = createSampleIncident(id: 'inc-1', title: 'Medical Outbreak', severity: 'Critical', status: 'New');
    final inc2 = createSampleIncident(id: 'inc-2', title: 'Substation Fire', severity: 'High', status: 'In Progress');
    final inc3 = createSampleIncident(id: 'inc-3', title: 'Road Blockage', severity: 'Low', status: 'Closed');

    await localDataSource.saveIncident(inc1);
    await localDataSource.saveIncident(inc2);
    await localDataSource.saveIncident(inc3);

    // Retrieve by ID
    final fetched = await localDataSource.getIncidentById('inc-1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Medical Outbreak');

    // Filter Open (Resolved and Closed excluded)
    final openIncidents = await localDataSource.getOpenIncidents();
    expect(openIncidents.length, 2);
    expect(openIncidents.map((i) => i.id), containsAll(['inc-1', 'inc-2']));

    // Filter Critical
    final criticalIncidents = await localDataSource.getCriticalIncidents();
    expect(criticalIncidents.length, 1);
    expect(criticalIncidents.first.id, 'inc-1');

    // Search query
    final searchResult = await localDataSource.getAllIncidents(query: 'fire');
    expect(searchResult.length, 1);
    expect(searchResult.first.id, 'inc-2');
  });

  test('Assignments: assign responder and query assigned incidents', () async {
    final incident = createSampleIncident(id: 'inc-assign-1');
    await localDataSource.saveIncident(incident);

    final assignment = AssignmentModel(
      id: 'assign-1',
      incidentId: 'inc-assign-1',
      responderId: 'responder-42',
      assignedBy: 'coordinator-1',
      assignedAt: DateTime.now(),
    );

    await localDataSource.saveAssignment(assignment);

    final fetched = await localDataSource.getAssignmentByIncidentId('inc-assign-1');
    expect(fetched, isNotNull);
    expect(fetched!.responderId, 'responder-42');

    final assignedIncidents = await localDataSource.getIncidentsAssignedTo('responder-42');
    expect(assignedIncidents.length, 1);
    expect(assignedIncidents.first.id, 'inc-assign-1');
  });

  test('Resource logs: save logs and aggregate resource summary by type', () async {
    final incident = createSampleIncident(id: 'inc-res-1');
    await localDataSource.saveIncident(incident);

    final log1 = ResourceLogModel(
      id: 'res-1',
      incidentId: 'inc-res-1',
      resourceType: 'Water',
      quantity: 50.0,
      unit: 'Litres',
      loggedBy: 'responder-1',
      createdAt: DateTime.now(),
    );

    final log2 = ResourceLogModel(
      id: 'res-2',
      incidentId: 'inc-res-1',
      resourceType: 'Water',
      quantity: 30.0,
      unit: 'Litres',
      loggedBy: 'responder-1',
      createdAt: DateTime.now(),
    );

    final log3 = ResourceLogModel(
      id: 'res-3',
      incidentId: 'inc-res-1',
      resourceType: 'First Aid Kit',
      quantity: 5.0,
      unit: 'Boxes',
      loggedBy: 'responder-1',
      createdAt: DateTime.now(),
    );

    await localDataSource.saveResourceLog(log1);
    await localDataSource.saveResourceLog(log2);
    await localDataSource.saveResourceLog(log3);

    final logs = await localDataSource.getResourceLogsForIncident('inc-res-1');
    expect(logs.length, 3);

    final summary = await localDataSource.getResourceSummaryForIncident('inc-res-1');
    expect(summary['Water'], 80.0);
    expect(summary['First Aid Kit'], 5.0);
  });

  test('Activity events: append timeline events and read in chronological order', () async {
    final incident = createSampleIncident(id: 'inc-act-1');
    await localDataSource.saveIncident(incident);

    final event1 = ActivityEventModel(
      id: 'act-1',
      incidentId: 'inc-act-1',
      actorId: 'coordinator-1',
      eventType: 'INCIDENT_CREATED',
      oldValue: null,
      newValue: 'New',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    final event2 = ActivityEventModel(
      id: 'act-2',
      incidentId: 'inc-act-1',
      actorId: 'responder-1',
      eventType: 'STATUS_CHANGE',
      oldValue: 'New',
      newValue: 'In Progress',
      timestamp: DateTime.now(),
    );

    await localDataSource.saveActivityEvent(event1);
    await localDataSource.saveActivityEvent(event2);

    final timeline = await localDataSource.getActivityTimeline('inc-act-1');
    expect(timeline.length, 2);
    expect(timeline.first.eventType, 'INCIDENT_CREATED');
    expect(timeline.last.eventType, 'STATUS_CHANGE');
  });

  test('Sync Operations: enqueue, retrieve pending, update state, and remove', () async {
    final op1 = SyncOperationModel(
      operationId: 'op-1',
      entityId: 'inc-1',
      entityType: 'incident',
      operationType: 'CREATE',
      payload: '{"title":"Fire"}',
      syncState: 'PENDING',
      createdAt: DateTime.now(),
    );

    final op2 = SyncOperationModel(
      operationId: 'op-2',
      entityId: 'inc-2',
      entityType: 'incident',
      operationType: 'UPDATE',
      payload: '{"status":"In Progress"}',
      syncState: 'PENDING',
      createdAt: DateTime.now().add(const Duration(seconds: 1)),
    );

    await localDataSource.enqueueSyncOperation(op1);
    await localDataSource.enqueueSyncOperation(op2);

    expect(await localDataSource.getPendingSyncCount(), 2);

    final pending = await localDataSource.getPendingSyncOperations();
    expect(pending.length, 2);

    // Update op1 to SYNCED
    await localDataSource.updateSyncOperationState('op-1', 'SYNCED');
    expect(await localDataSource.getPendingSyncCount(), 1);

    // Remove op2
    await localDataSource.removeSyncOperation('op-2');
    expect(await localDataSource.getPendingSyncCount(), 0);
  });
}
