import 'dart:async';

import 'package:sqflite/sqflite.dart';
import '../../features/incidents/data/models/activity_event_model.dart';
import '../../features/incidents/data/models/assignment_model.dart';
import '../../features/incidents/data/models/incident_model.dart';
import '../../features/resources/data/models/resource_log_model.dart';
import '../../features/sync/data/models/sync_operation_model.dart';
import 'app_database.dart';
import 'database_constants.dart';

abstract class LocalDataSource {
  /// Emits the table name whenever data in that table is modified (insert, update, delete).
  Stream<String> get onTableChanged;

  // Incidents
  Future<void> saveIncident(IncidentModel incident);
  Future<IncidentModel?> getIncidentById(String id);
  Future<List<IncidentModel>> getAllIncidents({
    String? query,
    String? severity,
    String? status,
    String? assignedResponderId,
    String? sortBy, // 'severity' or 'updatedAt'
  });
  Future<List<IncidentModel>> getOpenIncidents();
  Future<List<IncidentModel>> getCriticalIncidents();
  Future<int> deleteIncident(String id);

  // Assignments
  Future<void> saveAssignment(AssignmentModel assignment);
  Future<AssignmentModel?> getAssignmentByIncidentId(String incidentId);
  Future<List<IncidentModel>> getIncidentsAssignedTo(String responderId);

  // Resource Logs
  Future<void> saveResourceLog(ResourceLogModel log);
  Future<List<ResourceLogModel>> getResourceLogsForIncident(String incidentId);
  Future<Map<String, double>> getResourceSummaryForIncident(String incidentId);
  Future<List<Map<String, dynamic>>> getDetailedResourceSummaryForIncident(String incidentId);

  // Activity Events
  Future<void> saveActivityEvent(ActivityEventModel event);
  Future<List<ActivityEventModel>> getActivityTimeline(String incidentId);

  // Sync Operations
  Future<void> enqueueSyncOperation(SyncOperationModel operation);
  Future<List<SyncOperationModel>> getPendingSyncOperations();
  Future<List<SyncOperationModel>> getAllSyncOperations();
  Future<void> updateSyncOperationState(
    String operationId,
    String newState, {
    String? errorMessage,
    int? retryCount,
  });
  Future<int> getPendingSyncCount();
  Future<int> getFailedSyncCount();
  Future<void> removeSyncOperation(String operationId);
  Future<void> clearSyncedOperations();
}

class LocalDataSourceImpl implements LocalDataSource {
  final AppDatabase appDatabase;
  final StreamController<String> _tableChangeController =
      StreamController<String>.broadcast();

  LocalDataSourceImpl(this.appDatabase);

  @override
  Stream<String> get onTableChanged => _tableChangeController.stream;

  Future<Database> get _db async => await appDatabase.database;

  // -------------------------------------------------------------
  // Incidents
  // -------------------------------------------------------------
  @override
  Future<void> saveIncident(IncidentModel incident) async {
    final db = await _db;
    // Perform an UPDATE first so existing child foreign-key rows (activity_events, photos, etc.)
    // are not deleted via ON DELETE CASCADE (which happens when INSERT OR REPLACE deletes the row).
    final count = await db.update(
      DatabaseConstants.tableIncidents,
      incident.toMap(),
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [incident.id],
    );
    if (count == 0) {
      await db.insert(
        DatabaseConstants.tableIncidents,
        incident.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    _tableChangeController.add(DatabaseConstants.tableIncidents);
  }

  @override
  Future<IncidentModel?> getIncidentById(String id) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableIncidents,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return IncidentModel.fromMap(results.first);
  }

  @override
  Future<List<IncidentModel>> getAllIncidents({
    String? query,
    String? severity,
    String? status,
    String? assignedResponderId,
    String? sortBy,
  }) async {
    final db = await _db;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add(
        '(${DatabaseConstants.colTitle} LIKE ? OR ${DatabaseConstants.colId} LIKE ?)',
      );
      whereArgs.add('%${query.trim()}%');
      whereArgs.add('%${query.trim()}%');
    }

    if (severity != null && severity.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colSeverity} = ?');
      whereArgs.add(severity);
    }

    if (status != null && status.isNotEmpty) {
      whereClauses.add('${DatabaseConstants.colStatus} = ?');
      whereArgs.add(status);
    }

    if (assignedResponderId != null && assignedResponderId.isNotEmpty) {
      whereClauses.add(
        '${DatabaseConstants.colId} IN (SELECT ${DatabaseConstants.colIncidentId} FROM ${DatabaseConstants.tableAssignments} WHERE ${DatabaseConstants.colResponderId} = ?)',
      );
      whereArgs.add(assignedResponderId);
    }

    String orderBy;
    if (sortBy == 'severity') {
      // Order critical first, then high, medium, low
      orderBy = '''
        CASE ${DatabaseConstants.colSeverity}
          WHEN 'Critical' THEN 1
          WHEN 'High' THEN 2
          WHEN 'Medium' THEN 3
          WHEN 'Low' THEN 4
          ELSE 5
        END ASC, ${DatabaseConstants.colUpdatedAt} DESC
      ''';
    } else {
      // Default: Most recently updated first
      orderBy = '${DatabaseConstants.colUpdatedAt} DESC';
    }

    final results = await db.query(
      DatabaseConstants.tableIncidents,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return results.map(IncidentModel.fromMap).toList();
  }

  @override
  Future<List<IncidentModel>> getOpenIncidents() async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableIncidents,
      where: '${DatabaseConstants.colStatus} NOT IN (?, ?)',
      whereArgs: ['Resolved', 'Closed'],
      orderBy: '${DatabaseConstants.colUpdatedAt} DESC',
    );
    return results.map(IncidentModel.fromMap).toList();
  }

  @override
  Future<List<IncidentModel>> getCriticalIncidents() async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableIncidents,
      where: '${DatabaseConstants.colSeverity} = ? AND ${DatabaseConstants.colStatus} != ?',
      whereArgs: ['Critical', 'Closed'],
      orderBy: '${DatabaseConstants.colUpdatedAt} DESC',
    );
    return results.map(IncidentModel.fromMap).toList();
  }

  @override
  Future<int> deleteIncident(String id) async {
    final db = await _db;
    final deleted = await db.delete(
      DatabaseConstants.tableIncidents,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
    if (deleted > 0) {
      _tableChangeController.add(DatabaseConstants.tableIncidents);
    }
    return deleted;
  }

  // -------------------------------------------------------------
  // Assignments
  // -------------------------------------------------------------
  @override
  Future<void> saveAssignment(AssignmentModel assignment) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableAssignments,
      assignment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<AssignmentModel?> getAssignmentByIncidentId(String incidentId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableAssignments,
      where: '${DatabaseConstants.colIncidentId} = ?',
      whereArgs: [incidentId],
      orderBy: '${DatabaseConstants.colAssignedAt} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AssignmentModel.fromMap(results.first);
  }

  @override
  Future<List<IncidentModel>> getIncidentsAssignedTo(String responderId) async {
    return await getAllIncidents(assignedResponderId: responderId);
  }

  // -------------------------------------------------------------
  // Resource Logs
  // -------------------------------------------------------------
  @override
  Future<void> saveResourceLog(ResourceLogModel log) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableResourceLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _tableChangeController.add(DatabaseConstants.tableResourceLogs);
  }

  @override
  Future<List<ResourceLogModel>> getResourceLogsForIncident(String incidentId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableResourceLogs,
      where: '${DatabaseConstants.colIncidentId} = ?',
      whereArgs: [incidentId],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return results.map(ResourceLogModel.fromMap).toList();
  }

  @override
  Future<Map<String, double>> getResourceSummaryForIncident(String incidentId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        ${DatabaseConstants.colResourceType}, 
        SUM(${DatabaseConstants.colQuantity}) as total
      FROM ${DatabaseConstants.tableResourceLogs}
      WHERE ${DatabaseConstants.colIncidentId} = ?
      GROUP BY ${DatabaseConstants.colResourceType}
    ''', [incidentId]);

    final summary = <String, double>{};
    for (final row in results) {
      final resourceType = row[DatabaseConstants.colResourceType] as String;
      final total = (row['total'] as num).toDouble();
      summary[resourceType] = total;
    }
    return summary;
  }

  @override
  Future<List<Map<String, dynamic>>> getDetailedResourceSummaryForIncident(String incidentId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        ${DatabaseConstants.colResourceType}, 
        SUM(${DatabaseConstants.colQuantity}) as total,
        ${DatabaseConstants.colUnit}
      FROM ${DatabaseConstants.tableResourceLogs}
      WHERE ${DatabaseConstants.colIncidentId} = ?
      GROUP BY ${DatabaseConstants.colResourceType}, ${DatabaseConstants.colUnit}
      ORDER BY total DESC
    ''', [incidentId]);
    return results;
  }

  // -------------------------------------------------------------
  // Activity Events
  // -------------------------------------------------------------
  @override
  Future<void> saveActivityEvent(ActivityEventModel event) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableActivityEvents,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _tableChangeController.add(DatabaseConstants.tableActivityEvents);
  }

  @override
  Future<List<ActivityEventModel>> getActivityTimeline(String incidentId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableActivityEvents,
      where: '${DatabaseConstants.colIncidentId} = ?',
      whereArgs: [incidentId],
      orderBy: '${DatabaseConstants.colTimestamp} ASC',
    );
    return results.map(ActivityEventModel.fromMap).toList();
  }

  // -------------------------------------------------------------
  // Sync Operations
  // -------------------------------------------------------------
  @override
  Future<void> enqueueSyncOperation(SyncOperationModel operation) async {
    final db = await _db;
    await db.insert(
      DatabaseConstants.tableSyncOperations,
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _tableChangeController.add(DatabaseConstants.tableSyncOperations);
  }

  @override
  Future<List<SyncOperationModel>> getPendingSyncOperations() async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableSyncOperations,
      where: '${DatabaseConstants.colSyncState} IN (?, ?)',
      whereArgs: ['PENDING', 'FAILED'],
      orderBy: '${DatabaseConstants.colCreatedAt} ASC',
    );
    return results.map(SyncOperationModel.fromMap).toList();
  }

  @override
  Future<void> updateSyncOperationState(
    String operationId,
    String newState, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final db = await _db;
    final values = <String, dynamic>{
      DatabaseConstants.colSyncState: newState,
    };
    if (errorMessage != null) {
      values[DatabaseConstants.colErrorMessage] = errorMessage;
    }
    if (retryCount != null) {
      values[DatabaseConstants.colRetryCount] = retryCount;
    }

    await db.update(
      DatabaseConstants.tableSyncOperations,
      values,
      where: '${DatabaseConstants.colOperationId} = ?',
      whereArgs: [operationId],
    );
  }

  @override
  Future<List<SyncOperationModel>> getAllSyncOperations() async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableSyncOperations,
      orderBy: '${DatabaseConstants.colCreatedAt} ASC',
    );
    return results.map(SyncOperationModel.fromMap).toList();
  }

  @override
  Future<int> getPendingSyncCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseConstants.tableSyncOperations} WHERE ${DatabaseConstants.colSyncState} = ?',
        ['PENDING'],
      ),
    );
    return count ?? 0;
  }

  @override
  Future<int> getFailedSyncCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseConstants.tableSyncOperations} WHERE ${DatabaseConstants.colSyncState} = ?',
        ['FAILED'],
      ),
    );
    return count ?? 0;
  }

  @override
  Future<void> removeSyncOperation(String operationId) async {
    final db = await _db;
    await db.delete(
      DatabaseConstants.tableSyncOperations,
      where: '${DatabaseConstants.colOperationId} = ?',
      whereArgs: [operationId],
    );
  }

  @override
  Future<void> clearSyncedOperations() async {
    final db = await _db;
    await db.delete(
      DatabaseConstants.tableSyncOperations,
      where: '${DatabaseConstants.colSyncState} = ?',
      whereArgs: ['SYNCED'],
    );
  }
}
