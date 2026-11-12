import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pulsegrid/core/database/app_database.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/core/errors/exceptions.dart';
import 'package:pulsegrid/features/incidents/data/models/incident_model.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/resources/data/repositories/resource_repository_impl.dart';
import 'package:pulsegrid/features/resources/domain/repositories/resource_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late LocalDataSource localDataSource;
  late ResourceRepository repository;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    localDataSource = LocalDataSourceImpl(appDatabase);
    repository = ResourceRepositoryImpl(localDataSource: localDataSource);

    // Seed a parent incident so foreign keys succeed
    final sampleIncident = IncidentModel(
      id: 'inc-test-01',
      title: 'Power Outage',
      category: 'Infrastructure',
      severity: 'Medium',
      description: 'Main substation breaker tripped',
      status: 'In Progress',
      version: 1,
      latitude: 24.8607,
      longitude: 67.0011,
      createdBy: 'coordinator-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await localDataSource.saveIncident(sampleIncident);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('ResourceRepositoryImpl', () {
    test('logResource successfully saves log, writes activity event, and queues sync operation', () async {
      final result = await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'Water',
        quantity: 50.0,
        unit: 'Liters',
        notes: 'Bottles delivered by team alpha',
        loggedBy: 'responder-01',
      );

      // 1. Verify entity output
      expect(result.id, isNotEmpty);
      expect(result.incidentId, 'inc-test-01');
      expect(result.resourceType, 'Water');
      expect(result.quantity, 50.0);
      expect(result.unit, 'Liters');
      expect(result.notes, 'Bottles delivered by team alpha');
      expect(result.loggedBy, 'responder-01');

      // 2. Verify stored in SQLite
      final logsInDb = await localDataSource.getResourceLogsForIncident('inc-test-01');
      expect(logsInDb.length, 1);
      expect(logsInDb.first.id, result.id);
      expect(logsInDb.first.quantity, 50.0);

      // 3. Verify ActivityEvent created
      final events = await localDataSource.getActivityTimeline('inc-test-01');
      expect(events.length, 1);
      expect(events.first.eventType, ActivityEventType.resourceLogged.value);
      expect(events.first.actorId, 'responder-01');
      expect(events.first.newValue, '50 Liters of Water');

      // 4. Verify SyncOperations queued (RESOURCE_LOG + ACTIVITY_EVENT)
      final syncOps = await localDataSource.getPendingSyncOperations();
      expect(syncOps.length, 2);
      expect(syncOps.first.entityType, 'RESOURCE_LOG');
      expect(syncOps.first.entityId, result.id);
      expect(syncOps.first.syncState, 'PENDING');
      expect(syncOps[1].entityType, 'ACTIVITY_EVENT');
    });

    test('logResource throws ValidationException on zero or negative quantity and does not persist', () async {
      expect(
        () => repository.logResource(
          incidentId: 'inc-test-01',
          resourceType: 'Water',
          quantity: 0.0,
          unit: 'Liters',
          loggedBy: 'responder-01',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repository.logResource(
          incidentId: 'inc-test-01',
          resourceType: 'Water',
          quantity: -5.0,
          unit: 'Liters',
          loggedBy: 'responder-01',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Ensure no rows were written
      final logsInDb = await localDataSource.getResourceLogsForIncident('inc-test-01');
      expect(logsInDb, isEmpty);

      final events = await localDataSource.getActivityTimeline('inc-test-01');
      expect(events, isEmpty);

      final syncOps = await localDataSource.getPendingSyncOperations();
      expect(syncOps, isEmpty);
    });

    test('getResourceLogs returns all logs recorded for the incident', () async {
      await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'Water',
        quantity: 20.0,
        unit: 'Liters',
        loggedBy: 'responder-01',
      );
      await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'First Aid Kits',
        quantity: 5.0,
        unit: 'Kits',
        loggedBy: 'responder-02',
      );

      final logs = await repository.getResourceLogs('inc-test-01');
      expect(logs.length, 2);
      expect(logs.any((l) => l.resourceType == 'Water' && l.quantity == 20.0), isTrue);
      expect(logs.any((l) => l.resourceType == 'First Aid Kits' && l.quantity == 5.0), isTrue);
    });

    test('getResourceSummary aggregates totals correctly per resource type', () async {
      await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'Water',
        quantity: 25.0,
        unit: 'Liters',
        loggedBy: 'responder-01',
      );
      await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'Water',
        quantity: 75.0,
        unit: 'Liters',
        loggedBy: 'responder-02',
      );
      await repository.logResource(
        incidentId: 'inc-test-01',
        resourceType: 'Oxygen Tanks',
        quantity: 3.0,
        unit: 'Tanks',
        loggedBy: 'responder-01',
      );

      final summary = await repository.getResourceSummary('inc-test-01');
      expect(summary.length, 2);

      final waterSummary = summary.firstWhere((s) => s.resourceType == 'Water');
      expect(waterSummary.totalQuantity, 100.0);
      expect(waterSummary.unit, 'Liters');
      expect(waterSummary.formattedTotal, '100 Liters');

      final oxygenSummary = summary.firstWhere((s) => s.resourceType == 'Oxygen Tanks');
      expect(oxygenSummary.totalQuantity, 3.0);
      expect(oxygenSummary.unit, 'Tanks');
      expect(oxygenSummary.formattedTotal, '3 Tanks');
    });
  });
}

