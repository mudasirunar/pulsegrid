import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'database_constants.dart';

class AppDatabase {
  sqflite.Database? _db;
  final sqflite.DatabaseFactory? databaseFactory;

  AppDatabase({this.databaseFactory});

  /// Returns the active SQLite database instance, initializing if needed.
  Future<sqflite.Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<sqflite.Database> _initDatabase() async {
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final databasesPath = await factory.getDatabasesPath();
    final path = join(databasesPath, DatabaseConstants.databaseName);

    return await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: DatabaseConstants.databaseVersion,
        onCreate: createTables,
        onConfigure: (db) async {
          // Enable SQLite Foreign Key constraints for relational integrity
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  /// Creates all 5 required tables and performance indexes
  static Future<void> createTables(sqflite.Database db, int version) async {
    await db.transaction((txn) async {
      // 1. Incidents Table
      await txn.execute('''
        CREATE TABLE ${DatabaseConstants.tableIncidents} (
          ${DatabaseConstants.colId} TEXT PRIMARY KEY,
          ${DatabaseConstants.colTitle} TEXT NOT NULL,
          ${DatabaseConstants.colCategory} TEXT NOT NULL,
          ${DatabaseConstants.colSeverity} TEXT NOT NULL,
          ${DatabaseConstants.colDescription} TEXT NOT NULL,
          ${DatabaseConstants.colStatus} TEXT NOT NULL,
          ${DatabaseConstants.colVersion} INTEGER NOT NULL DEFAULT 1,
          ${DatabaseConstants.colLatitude} REAL,
          ${DatabaseConstants.colLongitude} REAL,
          ${DatabaseConstants.colManualLocationNotes} TEXT,
          ${DatabaseConstants.colPhotoPath} TEXT,
          ${DatabaseConstants.colCreatedBy} TEXT NOT NULL,
          ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
          ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL
        )
      ''');

      // 2. Assignments Table
      await txn.execute('''
        CREATE TABLE ${DatabaseConstants.tableAssignments} (
          ${DatabaseConstants.colId} TEXT PRIMARY KEY,
          ${DatabaseConstants.colIncidentId} TEXT NOT NULL,
          ${DatabaseConstants.colResponderId} TEXT NOT NULL,
          ${DatabaseConstants.colAssignedBy} TEXT NOT NULL,
          ${DatabaseConstants.colAssignedAt} TEXT NOT NULL,
          FOREIGN KEY (${DatabaseConstants.colIncidentId}) 
            REFERENCES ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colId}) 
            ON DELETE CASCADE
        )
      ''');

      // 3. Resource Logs Table
      await txn.execute('''
        CREATE TABLE ${DatabaseConstants.tableResourceLogs} (
          ${DatabaseConstants.colId} TEXT PRIMARY KEY,
          ${DatabaseConstants.colIncidentId} TEXT NOT NULL,
          ${DatabaseConstants.colResourceType} TEXT NOT NULL,
          ${DatabaseConstants.colQuantity} REAL NOT NULL,
          ${DatabaseConstants.colUnit} TEXT NOT NULL,
          ${DatabaseConstants.colNotes} TEXT,
          ${DatabaseConstants.colLoggedBy} TEXT NOT NULL,
          ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
          FOREIGN KEY (${DatabaseConstants.colIncidentId}) 
            REFERENCES ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colId}) 
            ON DELETE CASCADE
        )
      ''');

      // 4. Activity Events Table (Audit / Timeline)
      await txn.execute('''
        CREATE TABLE ${DatabaseConstants.tableActivityEvents} (
          ${DatabaseConstants.colId} TEXT PRIMARY KEY,
          ${DatabaseConstants.colIncidentId} TEXT NOT NULL,
          ${DatabaseConstants.colActorId} TEXT NOT NULL,
          ${DatabaseConstants.colEventType} TEXT NOT NULL,
          ${DatabaseConstants.colOldValue} TEXT,
          ${DatabaseConstants.colNewValue} TEXT,
          ${DatabaseConstants.colTimestamp} TEXT NOT NULL,
          FOREIGN KEY (${DatabaseConstants.colIncidentId}) 
            REFERENCES ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colId}) 
            ON DELETE CASCADE
        )
      ''');

      // 5. Sync Operations Table (Write-ahead local mutation queue)
      await txn.execute('''
        CREATE TABLE ${DatabaseConstants.tableSyncOperations} (
          ${DatabaseConstants.colOperationId} TEXT PRIMARY KEY,
          ${DatabaseConstants.colEntityId} TEXT NOT NULL,
          ${DatabaseConstants.colEntityType} TEXT NOT NULL,
          ${DatabaseConstants.colOperationType} TEXT NOT NULL,
          ${DatabaseConstants.colPayload} TEXT NOT NULL,
          ${DatabaseConstants.colRetryCount} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseConstants.colSyncState} TEXT NOT NULL,
          ${DatabaseConstants.colErrorMessage} TEXT,
          ${DatabaseConstants.colCreatedAt} TEXT NOT NULL
        )
      ''');

      // Performance Indexes for Fast Searching & Filtering
      await txn.execute(
        'CREATE INDEX idx_incidents_status ON ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colStatus})',
      );
      await txn.execute(
        'CREATE INDEX idx_incidents_severity ON ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colSeverity})',
      );
      await txn.execute(
        'CREATE INDEX idx_incidents_updatedAt ON ${DatabaseConstants.tableIncidents} (${DatabaseConstants.colUpdatedAt})',
      );
      await txn.execute(
        'CREATE INDEX idx_assignments_incidentId ON ${DatabaseConstants.tableAssignments} (${DatabaseConstants.colIncidentId})',
      );
      await txn.execute(
        'CREATE INDEX idx_resources_incidentId ON ${DatabaseConstants.tableResourceLogs} (${DatabaseConstants.colIncidentId})',
      );
      await txn.execute(
        'CREATE INDEX idx_activity_incidentId ON ${DatabaseConstants.tableActivityEvents} (${DatabaseConstants.colIncidentId})',
      );
      await txn.execute(
        'CREATE INDEX idx_sync_state ON ${DatabaseConstants.tableSyncOperations} (${DatabaseConstants.colSyncState})',
      );
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

