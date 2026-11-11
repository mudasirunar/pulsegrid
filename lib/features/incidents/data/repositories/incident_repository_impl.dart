import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/logic/incident_state_machine.dart';
import '../../domain/repositories/incident_repository.dart';
import '../../../sync/data/models/sync_operation_model.dart';
import '../models/activity_event_model.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  final LocalDataSource localDataSource;
  static const _uuid = Uuid();

  IncidentRepositoryImpl({required this.localDataSource});

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async {
    final models = await localDataSource.getAllIncidents(
      query: searchQuery,
      status: statusFilter?.value,
      severity: severityFilter?.value,
      sortBy: 'updatedAt',
    );
    return models.map((m) => IncidentEntity.fromModel(m)).toList();
  }

  @override
  Future<IncidentEntity?> getIncidentById(String id) async {
    final model = await localDataSource.getIncidentById(id);
    if (model == null) return null;
    return IncidentEntity.fromModel(model);
  }

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async {
    // 1. Persist incident locally (SQLite Single Source of Truth)
    await localDataSource.saveIncident(incident.toModel());

    // 2. Record initial lifecycle ActivityEvent
    final createEvent = ActivityEventModel(
      id: _uuid.v4(),
      incidentId: incident.id,
      actorId: incident.createdBy,
      eventType: ActivityEventType.incidentCreated.value,
      oldValue: null,
      newValue: incident.status.value,
      timestamp: incident.createdAt,
    );
    await localDataSource.saveActivityEvent(createEvent);

    // 3. Queue offline sync operation
    final syncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: incident.id,
      entityType: 'INCIDENT',
      operationType: 'INSERT',
      payload: jsonEncode(incident.toModel().toMap()),
      createdAt: incident.createdAt,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(syncOp);

    return incident;
  }

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async {
    // 1. Fetch current incident
    final current = await getIncidentById(incidentId);
    if (current == null) {
      throw DatabaseException('Incident "$incidentId" not found in local database.');
    }

    // 2. Execute strict state machine rules
    final transitionResult = IncidentStateMachine.transition(
      incident: current,
      targetStatus: targetStatus,
      actor: actor,
    );

    // 3. Persist updated incident
    await localDataSource.saveIncident(transitionResult.updatedIncident.toModel());

    // 4. Persist audit activity event
    await localDataSource.saveActivityEvent(transitionResult.activityEvent);

    // 5. Queue sync operation for status change
    final syncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: incidentId,
      entityType: 'INCIDENT',
      operationType: 'UPDATE',
      payload: jsonEncode(transitionResult.updatedIncident.toModel().toMap()),
      createdAt: DateTime.now(),
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(syncOp);

    return transitionResult.updatedIncident;
  }

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async {
    final events = await localDataSource.getActivityTimeline(incidentId);
    return events.map((e) => ActivityEventEntity.fromModel(e)).toList();
  }
}
