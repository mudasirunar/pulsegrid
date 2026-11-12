import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../incidents/data/models/activity_event_model.dart';
import '../../../incidents/domain/entities/activity_event_entity.dart';
import '../../../sync/data/models/sync_operation_model.dart';
import '../../domain/entities/resource_log_entity.dart';
import '../../domain/entities/resource_summary_item.dart';
import '../../domain/repositories/resource_repository.dart';
import '../models/resource_log_model.dart';

class ResourceRepositoryImpl implements ResourceRepository {
  final LocalDataSource localDataSource;
  static const _uuid = Uuid();

  ResourceRepositoryImpl({required this.localDataSource});

  @override
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async {
    // 1. Strict input validation per PRD §4.2 (quantity must be > 0)
    ResourceLogEntity.validate(
      incidentId: incidentId,
      resourceType: resourceType,
      quantity: quantity,
      unit: unit,
      loggedBy: loggedBy,
    );

    final id = _uuid.v4();
    final now = DateTime.now();

    final model = ResourceLogModel(
      id: id,
      incidentId: incidentId,
      resourceType: resourceType.trim(),
      quantity: quantity,
      unit: unit.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      loggedBy: loggedBy.trim(),
      createdAt: now,
    );

    // 2. Persist to local SQLite Single Source of Truth
    await localDataSource.saveResourceLog(model);

    // 3. Record ActivityEvent for the incident timeline
    final qtyFormatted = quantity.truncateToDouble() == quantity
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    final event = ActivityEventModel(
      id: _uuid.v4(),
      incidentId: incidentId,
      actorId: loggedBy.trim(),
      eventType: ActivityEventType.resourceLogged.value,
      oldValue: null,
      newValue: '$qtyFormatted ${unit.trim()} of ${resourceType.trim()}',
      timestamp: now,
    );
    await localDataSource.saveActivityEvent(event);

    // 4. Enqueue write-ahead SyncOperation
    final syncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: id,
      entityType: 'RESOURCE_LOG',
      operationType: 'INSERT',
      payload: jsonEncode(model.toMap()),
      createdAt: now,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(syncOp);

    return ResourceLogEntity.fromModel(model);
  }

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async {
    final models = await localDataSource.getResourceLogsForIncident(incidentId);
    return models.map((m) => ResourceLogEntity.fromModel(m)).toList();
  }

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async {
    final rows = await localDataSource.getDetailedResourceSummaryForIncident(incidentId);
    return rows.map((row) {
      return ResourceSummaryItem(
        resourceType: row[DatabaseConstants.colResourceType] as String,
        totalQuantity: (row['total'] as num).toDouble(),
        unit: row[DatabaseConstants.colUnit] as String,
      );
    }).toList();
  }
}

