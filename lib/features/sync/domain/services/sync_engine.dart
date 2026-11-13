import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/photo_file_resolver.dart';
import '../../../incidents/data/models/activity_event_model.dart';
import '../../../incidents/data/models/assignment_model.dart';
import '../../../incidents/data/models/incident_model.dart';
import '../../../resources/data/models/resource_log_model.dart';
import '../../data/datasources/firestore_remote_data_source.dart';
import '../entities/sync_operation_entity.dart';
import 'sync_queue_manager.dart';

class ScopedIncidentSubscription {
  final List<StreamSubscription> _subscriptions;
  const ScopedIncidentSubscription(this._subscriptions);

  Future<void> cancel() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
  }
}

class SyncEngine {
  final SyncQueueManager queueManager;
  final FirestoreRemoteDataSource remoteDataSource;
  final LocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final FirebaseAuth? firebaseAuth;
  static const Uuid _uuid = Uuid();

  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteIncidentsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteAssignmentsSubscription;
  StreamSubscription<String>? _remoteRemovedSubscription;
  StreamSubscription<List<String>>? _remoteDeletedTombstoneSubscription;
  StreamSubscription<String>? _tableSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isSyncing = false;

  final StreamController<String> _deletedIncidentController =
      StreamController<String>.broadcast();
  final Set<String> _knownDeletedIds = {};
  final Set<String> _selfDeletingIds = {};

  /// Emits incident IDs that were deleted remotely by another user or device.
  Stream<String> get onIncidentDeletedRemote => _deletedIncidentController.stream;

  /// Marks an incident ID as being deleted by the current device so self-deletes
  /// do not trigger the "deleted by another user" alert dialog.
  void markSelfDeleting(String incidentId) {
    _selfDeletingIds.add(incidentId);
    _knownDeletedIds.add(incidentId);
  }

  SyncEngine({
    required this.queueManager,
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    this.firebaseAuth,
  });

  /// Initializes the Sync Engine:
  /// 1. Binds queueManager remote dispatch handler
  /// 2. Listens to connectivity changes
  /// 3. Listens to local SQLite table changes for immediate outbound push
  /// 4. Subscribes to live remote Firestore incident stream when authenticated
  Future<void> initialize() async {
    // 1. Bind remote handler to the queue manager
    queueManager.setRemoteSyncHandler(dispatchOperation);

    // 2. Listen to network changes (e.g. Airplane mode toggled off)
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((hasConnection) async {
      if (hasConnection) {
        await syncAll();
      }
    });

    // 3. Listen to local SQLite table changes: immediate push on new sync operation
    _tableSubscription = localDataSource.onTableChanged.listen((tableName) {
      if (tableName == DatabaseConstants.tableSyncOperations) {
        triggerPush();
      }
    });

    // 4. Live inbound Firestore WebSocket listener: active ONLY when authenticated
    if (firebaseAuth != null) {
      _authSubscription = firebaseAuth!.authStateChanges().listen((user) async {
        if (user != null) {
          _startListeningToRemote();
          final isOnline = await networkInfo.isConnected;
          if (isOnline) {
            await syncAll();
          }
        } else {
          _stopListeningToRemote();
        }
      });
    } else {
      // In test environments or when firebaseAuth is omitted
      _startListeningToRemote();
      final isOnline = await networkInfo.isConnected;
      if (isOnline) {
        await syncAll();
      }
    }
  }

  Future<void> _handleRemoteDeletion(String incidentId) async {
    _knownDeletedIds.add(incidentId);
    final existing = await localDataSource.getIncidentById(incidentId);
    if (existing != null) {
      await localDataSource.deleteIncident(incidentId);
      if (existing.photoPaths.isNotEmpty) {
        await _cleanupUnreferencedPhotos(existing.photoPaths);
      }
    }
    if (!_selfDeletingIds.contains(incidentId) &&
        !_deletedIncidentController.isClosed) {
      _deletedIncidentController.add(incidentId);
    }
  }

  Future<void> _mergeAndSaveRemoteIncident(IncidentModel model) async {
    if (_knownDeletedIds.contains(model.id)) {
      return;
    }
    final local = await localDataSource.getIncidentById(model.id);
    if (local == null) {
      await localDataSource.saveIncident(model);
      return;
    }

    // Last-Write-Wins (LWW) by UTC updatedAt timestamp
    final remoteTime = model.updatedAt.toUtc();
    final localTime = local.updatedAt.toUtc();
    if (remoteTime.isBefore(localTime)) {
      return;
    }
    if (remoteTime.isAtSameMomentAs(localTime) && model.version < local.version) {
      return;
    }

    final effective = (model.photoPaths.isEmpty &&
            local.photoPaths.isNotEmpty &&
            remoteTime.isAtSameMomentAs(localTime))
        ? model.copyWith(photoPaths: local.photoPaths)
        : model;
    if (effective != local) {
      await localDataSource.saveIncident(effective);
      final removedPhotos = local.photoPaths
          .where((p) => !effective.photoPaths.contains(p))
          .toList();
      if (removedPhotos.isNotEmpty) {
        await _cleanupUnreferencedPhotos(removedPhotos);
      }
    }
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

  void _startListeningToRemote() {
    _remoteIncidentsSubscription?.cancel();
    _remoteIncidentsSubscription = remoteDataSource.watchIncidents().listen(
      (incidentsData) async {
        for (final incData in incidentsData) {
          try {
            final model = IncidentModel.fromMap(incData);
            await _mergeAndSaveRemoteIncident(model);
          } catch (_) {}
        }
      },
      onError: (_) {
        // Gracefully handle permission-denied or network dropouts with automatic retry
        _remoteIncidentsSubscription?.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (firebaseAuth == null || firebaseAuth?.currentUser != null) {
            _startListeningToRemote();
          }
        });
      },
    );

    _remoteRemovedSubscription?.cancel();
    _remoteRemovedSubscription = remoteDataSource.watchRemovedIncidentIds().listen(
      (removedId) async {
        await _handleRemoteDeletion(removedId);
      },
      onError: (_) {},
    );

    _remoteDeletedTombstoneSubscription?.cancel();
    _remoteDeletedTombstoneSubscription =
        remoteDataSource.watchDeletedIncidentIds().listen(
      (deletedIds) async {
        for (final id in deletedIds) {
          await _handleRemoteDeletion(id);
        }
      },
      onError: (_) {},
    );

    _remoteAssignmentsSubscription?.cancel();
    _remoteAssignmentsSubscription =
        remoteDataSource.watchAllAssignments().listen(
      (assignmentsData) async {
        for (final data in assignmentsData) {
          try {
            final model = AssignmentModel.fromMap(data);
            await _mergeAndSaveRemoteAssignment(model);
          } catch (_) {}
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _mergeAndSaveRemoteAssignment(AssignmentModel model) async {
    if (_knownDeletedIds.contains(model.incidentId)) return;
    final local =
        await localDataSource.getAssignmentByIncidentId(model.incidentId);
    if (local != null &&
        model.assignedAt.toUtc().isBefore(local.assignedAt.toUtc())) {
      return;
    }
    if (local != model) {
      await localDataSource.saveAssignment(model);
    }
  }

  void _stopListeningToRemote() {
    _remoteIncidentsSubscription?.cancel();
    _remoteIncidentsSubscription = null;
    _remoteRemovedSubscription?.cancel();
    _remoteRemovedSubscription = null;
    _remoteDeletedTombstoneSubscription?.cancel();
    _remoteDeletedTombstoneSubscription = null;
    _remoteAssignmentsSubscription?.cancel();
    _remoteAssignmentsSubscription = null;
  }

  /// Triggers an immediate background push of queued operations without blocking the caller.
  void triggerPush() {
    unawaited(_safePush());
  }

  Future<void> _safePush() async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return;
    try {
      await queueManager.processQueue(force: false);
    } catch (_) {}
  }

  /// Scoped live listener for Incident Details: watches remote incident, resource logs, and
  /// activity events for a specific incident and mirrors changes into SQLite.
  ScopedIncidentSubscription watchIncidentDetails(String incidentId) {
    final logSub = remoteDataSource.watchResourceLogs(incidentId).listen(
      (logsData) async {
        try {
          final existingLogs = await localDataSource.getResourceLogsForIncident(incidentId);
          final existingById = {for (final l in existingLogs) l.id: l};
          for (final logData in logsData) {
            try {
              final model = ResourceLogModel.fromMap(logData);
              if (existingById[model.id] != model) {
                await localDataSource.saveResourceLog(model);
              }
            } catch (_) {}
          }
        } catch (_) {}
      },
      onError: (_) {},
    );

    final eventSub = remoteDataSource.watchActivityEvents(incidentId).listen(
      (eventsData) async {
        try {
          final existingEvents = await localDataSource.getActivityTimeline(incidentId);
          final existingById = {for (final e in existingEvents) e.id: e};
          for (final eventData in eventsData) {
            try {
              final model = ActivityEventModel.fromMap(eventData);
              if (existingById[model.id] != model) {
                await localDataSource.saveActivityEvent(model);
              }
            } catch (_) {}
          }
        } catch (_) {}
      },
      onError: (_) {},
    );

    final incSub = remoteDataSource.watchIncident(incidentId).listen(
      (incidentData) async {
        if (incidentData == null) {
          // Only treat null (!doc.exists) as remote deletion if it is not a
          // freshly created offline incident waiting to be uploaded.
          final allOps = await localDataSource.getAllSyncOperations();
          final hasPendingCreate = allOps.any(
            (op) =>
                op.entityId == incidentId &&
                op.entityType == 'INCIDENT' &&
                op.operationType == 'CREATE',
          );
          if (!hasPendingCreate) {
            await _handleRemoteDeletion(incidentId);
          }
          return;
        }
        try {
          final model = IncidentModel.fromMap(incidentData);
          await _mergeAndSaveRemoteIncident(model);
        } catch (_) {}
      },
      onError: (_) {},
    );

    final assignSub = remoteDataSource.watchAssignments(incidentId).listen(
      (assignmentsData) async {
        for (final data in assignmentsData) {
          try {
            final model = AssignmentModel.fromMap(data);
            await _mergeAndSaveRemoteAssignment(model);
          } catch (_) {}
        }
      },
      onError: (_) {},
    );

    return ScopedIncidentSubscription([logSub, eventSub, incSub, assignSub]);
  }

  /// Handles dispatching an individual queued mutation to Cloud Firestore.
  Future<void> dispatchOperation(SyncOperationEntity operation) async {
    final payloadMap = jsonDecode(operation.payload) as Map<String, dynamic>;

    switch (operation.entityType) {
      case SyncEntityType.incident:
        if (operation.operationType == SyncOperationType.delete) {
          _selfDeletingIds.add(operation.entityId);
          await remoteDataSource.deleteIncident(operation.entityId);
        } else {
          final isUpdate = operation.operationType == SyncOperationType.update;
          try {
            await remoteDataSource.pushIncident(payloadMap, isUpdate: isUpdate);
          } on IncidentRemotelyDeletedException {
            // Delete Always Wins: purge local copy & complete op without retrying
            await _handleRemoteDeletion(operation.entityId);
          }
        }
        break;

      case SyncEntityType.resource:
        await remoteDataSource.pushResourceLog(payloadMap);
        break;

      case SyncEntityType.activityEvent:
        await remoteDataSource.pushActivityEvent(payloadMap);
        break;

      case SyncEntityType.assignment:
        await remoteDataSource.pushAssignment(payloadMap);
        break;
    }
  }

  /// Performs full bidirectional sync:
  /// 1. Resets any failed operations and pushes all local queued mutations to Firestore
  /// 2. Pulls remote updates and updates local SQLite
  Future<void> syncAll() async {
    if (_isSyncing) return;
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return;

    _isSyncing = true;
    try {
      // 1. Reset any failed operations and flush the local queue immediately
      await queueManager.retryFailedOperations();

      // 2. Pull remote updates and reconcile any untracked local-only records
      await pullRemoteUpdates();
    } catch (_) {
      // Network interruption during sync: local data remains safely queued in SQLite
    } finally {
      _isSyncing = false;
    }
  }

  /// Pulls remote Firestore documents, merges changes into local SQLite database,
  /// and enqueues any local-only records that were never tracked in sync_operations.
  Future<void> pullRemoteUpdates() async {
    try {
      // 0. Pull deleted tombstones first so deleted incidents are purged and never resurrected
      final deletedIds = await remoteDataSource.pullDeletedIncidentIds();
      _knownDeletedIds.addAll(deletedIds);
      for (final deletedId in deletedIds) {
        await _handleRemoteDeletion(deletedId);
      }

      final remoteIncidents = await remoteDataSource.pullIncidents();
      final remoteIncidentIds = <String>{};
      for (final incData in remoteIncidents) {
        try {
          final model = IncidentModel.fromMap(incData);
          remoteIncidentIds.add(model.id);
          await _mergeAndSaveRemoteIncident(model);
        } catch (_) {}
      }

      // Pull resource logs
      final remoteResources = await remoteDataSource.pullResourceLogs();
      final remoteResourceIds = <String>{};
      for (final resData in remoteResources) {
        try {
          final model = ResourceLogModel.fromMap(resData);
          remoteResourceIds.add(model.id);
          await localDataSource.saveResourceLog(model);
        } catch (_) {}
      }

      // Pull activity events
      final remoteEvents = await remoteDataSource.pullActivityEvents();
      final remoteEventIds = <String>{};
      for (final eventData in remoteEvents) {
        try {
          final model = ActivityEventModel.fromMap(eventData);
          remoteEventIds.add(model.id);
          await localDataSource.saveActivityEvent(model);
        } catch (_) {}
      }

      // Pull assignments
      final remoteAssignments = await remoteDataSource.pullAssignments();
      for (final assignData in remoteAssignments) {
        try {
          final model = AssignmentModel.fromMap(assignData);
          await _mergeAndSaveRemoteAssignment(model);
        } catch (_) {}
      }

      // Reconcile any local-only entities missing from both sync_operations and Firestore
      final allOps = await localDataSource.getAllSyncOperations();
      final trackedEntityIds = allOps.map((op) => op.entityId).toSet();
      bool enqueuedAny = false;

      final allIncidents = await localDataSource.getAllIncidents();
      for (final incident in allIncidents) {
        if (_knownDeletedIds.contains(incident.id)) {
          continue;
        }
        if (!trackedEntityIds.contains(incident.id) &&
            !remoteIncidentIds.contains(incident.id)) {
          final syncOp = SyncOperationEntity(
            operationId: _uuid.v4(),
            entityId: incident.id,
            entityType: SyncEntityType.incident,
            operationType: SyncOperationType.create,
            payload: jsonEncode(incident.toMap()),
            createdAt: DateTime.now(),
            status: SyncStatus.pending,
          );
          await queueManager.syncRepository.enqueueOperation(syncOp);
          trackedEntityIds.add(incident.id);
          enqueuedAny = true;
        }

        final resourceLogs =
            await localDataSource.getResourceLogsForIncident(incident.id);
        for (final log in resourceLogs) {
          if (!trackedEntityIds.contains(log.id) &&
              !remoteResourceIds.contains(log.id)) {
            final syncOp = SyncOperationEntity(
              operationId: _uuid.v4(),
              entityId: log.id,
              entityType: SyncEntityType.resource,
              operationType: SyncOperationType.create,
              payload: jsonEncode(log.toMap()),
              createdAt: DateTime.now(),
              status: SyncStatus.pending,
            );
            await queueManager.syncRepository.enqueueOperation(syncOp);
            trackedEntityIds.add(log.id);
            enqueuedAny = true;
          }
        }

        final activityEvents =
            await localDataSource.getActivityTimeline(incident.id);
        for (final event in activityEvents) {
          if (!trackedEntityIds.contains(event.id) &&
              !remoteEventIds.contains(event.id)) {
            final syncOp = SyncOperationEntity(
              operationId: _uuid.v4(),
              entityId: event.id,
              entityType: SyncEntityType.activityEvent,
              operationType: SyncOperationType.create,
              payload: jsonEncode(event.toMap()),
              createdAt: DateTime.now(),
              status: SyncStatus.pending,
            );
            await queueManager.syncRepository.enqueueOperation(syncOp);
            trackedEntityIds.add(event.id);
            enqueuedAny = true;
          }
        }
      }

      if (enqueuedAny) {
        await queueManager.processQueue(force: false);
      }
    } catch (_) {
      // Ignored if offline
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _remoteIncidentsSubscription?.cancel();
    _remoteAssignmentsSubscription?.cancel();
    _remoteRemovedSubscription?.cancel();
    _remoteDeletedTombstoneSubscription?.cancel();
    _tableSubscription?.cancel();
    _authSubscription?.cancel();
    _deletedIncidentController.close();
  }
}
