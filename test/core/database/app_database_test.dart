import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pulsegrid/core/database/app_database.dart';
import 'package:pulsegrid/core/database/database_constants.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDatabase;
  late Database db;

  setUp(() async {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    db = await appDatabase.database;
  });

  tearDown(() async {
    await db.close();
    await appDatabase.close();
  });

  test('SQLite database initializes all 5 required tables and indexes', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final tableNames = tables.map((t) => t['name'] as String).toSet();

    expect(tableNames, contains(DatabaseConstants.tableIncidents));
    expect(tableNames, contains(DatabaseConstants.tableAssignments));
    expect(tableNames, contains(DatabaseConstants.tableResourceLogs));
    expect(tableNames, contains(DatabaseConstants.tableActivityEvents));
    expect(tableNames, contains(DatabaseConstants.tableSyncOperations));
  });

  test('Can insert and retrieve records from incidents and sync_operations table', () async {
    final now = DateTime.now().toIso8601String();

    // Insert incident
    await db.insert(DatabaseConstants.tableIncidents, {
      DatabaseConstants.colId: 'inc-001',
      DatabaseConstants.colTitle: 'Building Flash Flood',
      DatabaseConstants.colCategory: 'Flood',
      DatabaseConstants.colSeverity: 'Critical',
      DatabaseConstants.colDescription: 'Basement flooding with electrical risk',
      DatabaseConstants.colStatus: 'New',
      DatabaseConstants.colVersion: 1,
      DatabaseConstants.colLatitude: 24.8607,
      DatabaseConstants.colLongitude: 67.0011,
      DatabaseConstants.colManualLocationNotes: null,
      DatabaseConstants.colPhotoPath: null,
      DatabaseConstants.colCreatedBy: 'user-001',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
    });

    final incidents = await db.query(DatabaseConstants.tableIncidents);
    expect(incidents.length, 1);
    expect(incidents.first[DatabaseConstants.colTitle], 'Building Flash Flood');
    expect(incidents.first[DatabaseConstants.colSeverity], 'Critical');

    // Insert sync operation
    await db.insert(DatabaseConstants.tableSyncOperations, {
      DatabaseConstants.colOperationId: 'op-001',
      DatabaseConstants.colEntityId: 'inc-001',
      DatabaseConstants.colEntityType: 'incident',
      DatabaseConstants.colOperationType: 'CREATE',
      DatabaseConstants.colPayload: '{"title":"Building Flash Flood"}',
      DatabaseConstants.colRetryCount: 0,
      DatabaseConstants.colSyncState: 'PENDING',
      DatabaseConstants.colErrorMessage: null,
      DatabaseConstants.colCreatedAt: now,
    });

    final syncOps = await db.query(DatabaseConstants.tableSyncOperations);
    expect(syncOps.length, 1);
    expect(syncOps.first[DatabaseConstants.colSyncState], 'PENDING');
  });
}

