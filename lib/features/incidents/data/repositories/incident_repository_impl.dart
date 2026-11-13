import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../../core/utils/photo_file_resolver.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../sync/data/datasources/firestore_remote_data_source.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/logic/incident_permissions.dart';
import '../../domain/logic/incident_state_machine.dart';
import '../../domain/repositories/incident_repository.dart';
import '../../../sync/data/models/sync_operation_model.dart';
import '../models/activity_event_model.dart';
import '../models/assignment_model.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  final LocalDataSource localDataSource;
  final FirestoreRemoteDataSource? remoteDataSource;
  final SharedPreferences? sharedPreferences;
  static const _uuid = Uuid();
  static const _cachedRespondersKey = 'cached_responders_list';

  IncidentRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
    this.sharedPreferences,
  });

  @override
  Stream<void> get onIncidentsChanged => localDataSource.onTableChanged
      .where((t) => t == DatabaseConstants.tableIncidents);

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

    // 3. Queue offline sync operation for incident
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

    // 4. Queue offline sync operation for initial creation activity event
    final eventSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: createEvent.id,
      entityType: 'ACTIVITY_EVENT',
      operationType: 'CREATE',
      payload: jsonEncode(createEvent.toMap()),
      createdAt: incident.createdAt,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(eventSyncOp);

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

    // 5. Queue sync operation for activity event
    final eventSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: transitionResult.activityEvent.id,
      entityType: 'ACTIVITY_EVENT',
      operationType: 'CREATE',
      payload: jsonEncode(transitionResult.activityEvent.toMap()),
      createdAt: DateTime.now(),
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(eventSyncOp);

    // 6. Queue sync operation for status change
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
  Future<IncidentEntity> updateIncident({
    required IncidentEntity updatedIncident,
    required UserEntity actor,
  }) async {
    final current = await getIncidentById(updatedIncident.id);
    if (current == null) {
      throw DatabaseException(
        'Incident "${updatedIncident.id}" not found in local database.',
      );
    }

    final assignment =
        await localDataSource.getAssignmentByIncidentId(updatedIncident.id);
    if (!IncidentPermissions.canEditOrDelete(
      incident: current,
      user: actor,
      assignment: assignment,
    )) {
      throw PermissionDeniedException(
        'You do not have permission to edit this incident.',
      );
    }

    final now = DateTime.now().toUtc();
    final saved = updatedIncident.copyWith(
      version: current.version + 1,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      updatedAt: now,
    );

    final changedFields = <String>[];
    if (saved.title != current.title) changedFields.add('title');
    if (saved.category != current.category) changedFields.add('category');
    if (saved.severity != current.severity) changedFields.add('severity');
    if (saved.description != current.description) changedFields.add('description');
    if (saved.latitude != current.latitude ||
        saved.longitude != current.longitude ||
        saved.manualLocationNotes != current.manualLocationNotes) {
      changedFields.add('location');
    }
    if (saved.photoPaths.join('|') != current.photoPaths.join('|')) {
      changedFields.add('photos');
    }

    final summary = changedFields.isNotEmpty
        ? 'Updated ${changedFields.join(', ')}'
        : 'Details updated';

    final actorName = actor.displayName.trim().isNotEmpty
        ? actor.displayName.trim()
        : (actor.email.trim().isNotEmpty ? actor.email.trim() : actor.id);

    final editEvent = ActivityEventModel(
      id: _uuid.v4(),
      incidentId: saved.id,
      actorId: actorName,
      eventType: ActivityEventType.incidentEdited.value,
      oldValue: null,
      newValue: summary,
      timestamp: now,
    );

    await localDataSource.saveIncident(saved.toModel());
    await localDataSource.saveActivityEvent(editEvent);

    final eventSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: editEvent.id,
      entityType: 'ACTIVITY_EVENT',
      operationType: 'CREATE',
      payload: jsonEncode(editEvent.toMap()),
      createdAt: now,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(eventSyncOp);

    final incidentSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: saved.id,
      entityType: 'INCIDENT',
      operationType: 'UPDATE',
      payload: jsonEncode(saved.toModel().toMap()),
      createdAt: now,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(incidentSyncOp);

    final removedPhotos = current.photoPaths
        .where((p) => !saved.photoPaths.contains(p))
        .toList();
    if (removedPhotos.isNotEmpty) {
      await _cleanupUnreferencedPhotos(removedPhotos);
    }

    return saved;
  }

  Future<void> _cleanupUnreferencedPhotos(List<String> candidatePaths) async {
    if (candidatePaths.isEmpty) return;
    final allIncidents = await localDataSource.getAllIncidents();
    final stillReferenced = allIncidents.expand((i) => i.photoPaths);
    await PhotoFileResolver.deleteUnreferencedPhotos(
      candidatePaths: candidatePaths,
      stillReferencedPaths: stillReferenced,
    );
  }

  @override
  Future<void> deleteIncident({
    required String incidentId,
    required UserEntity actor,
  }) async {
    final current = await getIncidentById(incidentId);
    if (current == null) {
      return;
    }

    final assignment =
        await localDataSource.getAssignmentByIncidentId(incidentId);
    if (!IncidentPermissions.canEditOrDelete(
      incident: current,
      user: actor,
      assignment: assignment,
    )) {
      throw PermissionDeniedException(
        'You do not have permission to delete this incident.',
      );
    }

    await localDataSource.deleteIncident(incidentId);
    if (current.photoPaths.isNotEmpty) {
      await _cleanupUnreferencedPhotos(current.photoPaths);
    }

    final deleteSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: incidentId,
      entityType: 'INCIDENT',
      operationType: 'DELETE',
      payload: jsonEncode({'id': incidentId}),
      createdAt: DateTime.now().toUtc(),
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(deleteSyncOp);
  }

  String _userDisplayName(UserEntity user) {
    if (user.displayName.trim().isNotEmpty) return user.displayName.trim();
    if (user.email.trim().isNotEmpty) return user.email.trim();
    return user.id;
  }

  @override
  Future<IncidentEntity> assignResponder({
    required String incidentId,
    required UserEntity responder,
    required UserEntity actor,
  }) async {
    if (actor.role != UserRole.coordinator) {
      throw PermissionDeniedException(
        'Only Coordinators can assign or reassign responders.',
      );
    }

    final current = await getIncidentById(incidentId);
    if (current == null) {
      throw DatabaseException(
        'Incident "$incidentId" not found in local database.',
      );
    }

    final now = DateTime.now().toUtc();
    final oldAssignment =
        await localDataSource.getAssignmentByIncidentId(incidentId);

    String? oldResponderName;
    if (oldAssignment != null && oldAssignment.responderId != responder.id) {
      final cachedResponders = await getResponders(forceRefresh: false);
      final match = cachedResponders.where((r) => r.id == oldAssignment.responderId);
      if (match.isNotEmpty) {
        oldResponderName = _userDisplayName(match.first);
      } else {
        final timeline = await localDataSource.getActivityTimeline(incidentId);
        final lastAssign = timeline.where(
          (e) => e.eventType == ActivityEventType.assignmentChange.value,
        );
        if (lastAssign.isNotEmpty && lastAssign.first.newValue != null) {
          oldResponderName = lastAssign.first.newValue;
        } else {
          oldResponderName = oldAssignment.responderId;
        }
      }
    }

    final newAssignment = AssignmentModel(
      id: oldAssignment?.id ?? 'assign-$incidentId',
      incidentId: incidentId,
      responderId: responder.id,
      assignedBy: actor.id,
      assignedAt: now,
    );

    await localDataSource.saveAssignment(newAssignment);

    final assignSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: newAssignment.id,
      entityType: 'ASSIGNMENT',
      operationType: 'CREATE',
      payload: jsonEncode(newAssignment.toMap()),
      createdAt: now,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(assignSyncOp);

    IncidentEntity updatedIncident = current;
    if (current.status == IncidentStatus.newIncident) {
      updatedIncident = current.copyWith(
        status: IncidentStatus.assigned,
        version: current.version + 1,
        updatedAt: now,
      );
      await localDataSource.saveIncident(updatedIncident.toModel());
      final incSyncOp = SyncOperationModel(
        operationId: _uuid.v4(),
        entityId: incidentId,
        entityType: 'INCIDENT',
        operationType: 'UPDATE',
        payload: jsonEncode(updatedIncident.toModel().toMap()),
        createdAt: now,
        syncState: 'PENDING',
      );
      await localDataSource.enqueueSyncOperation(incSyncOp);
    }

    final assignEvent = ActivityEventModel(
      id: _uuid.v4(),
      incidentId: incidentId,
      actorId: _userDisplayName(actor),
      eventType: ActivityEventType.assignmentChange.value,
      oldValue: oldResponderName,
      newValue: _userDisplayName(responder),
      timestamp: now,
    );
    await localDataSource.saveActivityEvent(assignEvent);

    final evtSyncOp = SyncOperationModel(
      operationId: _uuid.v4(),
      entityId: assignEvent.id,
      entityType: 'ACTIVITY_EVENT',
      operationType: 'CREATE',
      payload: jsonEncode(assignEvent.toMap()),
      createdAt: now,
      syncState: 'PENDING',
    );
    await localDataSource.enqueueSyncOperation(evtSyncOp);

    return updatedIncident;
  }

  List<UserEntity> _readCachedResponders(SharedPreferences prefs) {
    final cachedRaw = prefs.getString(_cachedRespondersKey);
    if (cachedRaw == null || cachedRaw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(cachedRaw) as List<dynamic>;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (m) => UserEntity(
              id: (m['id'] ?? '').toString(),
              email: (m['email'] ?? '').toString(),
              displayName: (m['displayName'] ?? '').toString(),
              role: UserRole.responder,
              rank: m['rank'] as String?,
            ),
          )
          .where((u) => u.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<UserEntity>> getResponders({bool forceRefresh = false}) async {
    final remote = remoteDataSource ??
        (di.sl.isRegistered<FirestoreRemoteDataSource>()
            ? di.sl<FirestoreRemoteDataSource>()
            : null);
    final prefs = sharedPreferences ??
        (di.sl.isRegistered<SharedPreferences>()
            ? di.sl<SharedPreferences>()
            : null);

    if (!forceRefresh && prefs != null) {
      final cached = _readCachedResponders(prefs);
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    if (remote != null) {
      try {
        final rawList = await remote.fetchResponders();
        final users = rawList.map((m) {
          final id = (m['id'] ?? m['uid'] ?? '').toString();
          final email = (m['email'] ?? '').toString();
          final displayName = (m['displayName'] ?? m['name'] ?? '').toString();
          final rank = m['rank'] as String?;
          return UserEntity(
            id: id,
            email: email,
            displayName: displayName.isNotEmpty ? displayName : email,
            role: UserRole.responder,
            rank: rank,
          );
        }).where((u) => u.id.isNotEmpty).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        if (prefs != null && users.isNotEmpty) {
          final encoded = jsonEncode(
            users
                .map((u) => {
                      'id': u.id,
                      'email': u.email,
                      'displayName': u.displayName,
                      'rank': u.rank,
                    })
                .toList(),
          );
          await prefs.setString(_cachedRespondersKey, encoded);
        }
        if (users.isNotEmpty || forceRefresh) {
          return users;
        }
      } catch (_) {
        // Offline or network error: fall back to cached responders below
      }
    }

    if (prefs != null) {
      final cachedRaw = prefs.getString(_cachedRespondersKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedRaw) as List<dynamic>;
          return decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map(
                (m) => UserEntity(
                  id: (m['id'] ?? '').toString(),
                  email: (m['email'] ?? '').toString(),
                  displayName: (m['displayName'] ?? '').toString(),
                  role: UserRole.responder,
                  rank: m['rank'] as String?,
                ),
              )
              .toList();
        } catch (_) {}
      }
    }

    return const [];
  }

  @override
  Future<Map<String, int>> getResponderActiveCounts() async {
    return localDataSource.getActiveIncidentCountsByResponder();
  }

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async {
    final events = await localDataSource.getActivityTimeline(incidentId);
    return events.map((e) => ActivityEventEntity.fromModel(e)).toList();
  }
}
