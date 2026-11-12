import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../../core/database/local_data_source.dart';
import '../../../../core/network/network_info.dart';
import '../../../incidents/data/models/activity_event_model.dart';
import '../../../incidents/data/models/incident_model.dart';
import '../../../resources/data/models/resource_log_model.dart';
import '../../data/datasources/firestore_remote_data_source.dart';
import '../entities/sync_operation_entity.dart';
import 'sync_queue_manager.dart';

class SyncEngine {
  final SyncQueueManager queueManager;
  final FirestoreRemoteDataSource remoteDataSource;
  final LocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  static const Uuid _uuid = Uuid();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  SyncEngine({
    required this.queueManager,
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Initializes the Sync Engine:
  /// 1. Binds queueManager remote dispatch handler
  /// 2. Listens to connectivity changes
  /// 3. Performs initial synchronization if online
  Future<void> initialize() async {
    // 1. Bind remote handler to the queue manager
    queueManager.setRemoteSyncHandler(dispatchOperation);

    // 2. Listen to network changes (e.g. Airplane mode toggled off)
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((hasConnection) async {
      if (hasConnection) {
        await syncAll();
      }
    });

    // 3. Check current connection and trigger initial sync if online
    final isOnline = await networkInfo.isConnected;
    if (isOnline) {
      await syncAll();
    }
  }

  /// Handles dispatching an individual queued mutation to Cloud Firestore.
  Future<void> dispatchOperation(SyncOperationEntity operation) async {
    final payloadMap = jsonDecode(operation.payload) as Map<String, dynamic>;

    switch (operation.entityType) {
      case SyncEntityType.incident:
        if (operation.operationType == SyncOperationType.delete) {
          await remoteDataSource.deleteIncident(operation.entityId);
        } else {
          await remoteDataSource.pushIncident(payloadMap);
        }
        break;

      case SyncEntityType.resource:
        await remoteDataSource.pushResourceLog(payloadMap);
        break;

      case SyncEntityType.activityEvent:
        await remoteDataSource.pushActivityEvent(payloadMap);
        break;

      case SyncEntityType.assignment:
        // Handled via incident update
        break;
    }
  }

  /// Performs full bidirectional sync:
  /// 1. Ensures any untracked local data is enqueued
  /// 2. Pushes all local queued mutations to Firestore
  /// 3. Pulls remote updates and updates local SQLite
  Future<void> syncAll() async {
    if (_isSyncing) return;
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return;

    _isSyncing = true;
    try {
      // 1. Enqueue any legacy/untracked local entities
      await _enqueueUnsyncedLocalEntities();

      // 2. Push local mutations
      await queueManager.processQueue();

      // 3. Pull remote updates
      await pullRemoteUpdates();
    } catch (_) {
      // Network interruption during sync: local data remains safely queued in SQLite
    } finally {
      _isSyncing = false;
    }
  }

  /// Checks local SQLite for incidents, resource logs, or activity events that
  /// do not currently exist in the sync queue, and enqueues them for remote sync.
  Future<void> _enqueueUnsyncedLocalEntities() async {
    try {
      final allOps = await localDataSource.getAllSyncOperations();
      final trackedEntityIds = allOps.map((op) => op.entityId).toSet();

      final allIncidents = await localDataSource.getAllIncidents();
      for (final incident in allIncidents) {
        if (!trackedEntityIds.contains(incident.id)) {
          final syncOp = SyncOperationEntity(
            operationId: _uuid.v4(),
            entityId: incident.id,
            entityType: SyncEntityType.incident,
            operationType: SyncOperationType.create,
            payload: jsonEncode(incident.toMap()),
            createdAt: incident.createdAt,
            status: SyncStatus.pending,
          );
          await queueManager.syncRepository.enqueueOperation(syncOp);
          trackedEntityIds.add(incident.id);
        }

        // Also check resource logs
        final resourceLogs = await localDataSource.getResourceLogsForIncident(incident.id);
        for (final log in resourceLogs) {
          if (!trackedEntityIds.contains(log.id)) {
            final syncOp = SyncOperationEntity(
              operationId: _uuid.v4(),
              entityId: log.id,
              entityType: SyncEntityType.resource,
              operationType: SyncOperationType.create,
              payload: jsonEncode(log.toMap()),
              createdAt: log.createdAt,
              status: SyncStatus.pending,
            );
            await queueManager.syncRepository.enqueueOperation(syncOp);
            trackedEntityIds.add(log.id);
          }
        }

        // Also check activity events
        final activityEvents = await localDataSource.getActivityTimeline(incident.id);
        for (final event in activityEvents) {
          if (!trackedEntityIds.contains(event.id)) {
            final syncOp = SyncOperationEntity(
              operationId: _uuid.v4(),
              entityId: event.id,
              entityType: SyncEntityType.activityEvent,
              operationType: SyncOperationType.create,
              payload: jsonEncode(event.toMap()),
              createdAt: event.timestamp,
              status: SyncStatus.pending,
            );
            await queueManager.syncRepository.enqueueOperation(syncOp);
            trackedEntityIds.add(event.id);
          }
        }
      }
    } catch (_) {
      // Ignored if local querying encounters an issue
    }
  }

  /// Pulls remote Firestore documents and reconciles local SQLite database
  Future<void> pullRemoteUpdates() async {
    try {
      final remoteIncidents = await remoteDataSource.pullIncidents();
      for (final incData in remoteIncidents) {
        try {
          final model = IncidentModel.fromMap(incData);
          final local = await localDataSource.getIncidentById(model.id);

          if (local == null) {
            // New remote incident: insert locally
            await localDataSource.saveIncident(model);
          } else if (model.version >= local.version) {
            // Remote is newer or equal: update local
            await localDataSource.saveIncident(model);
          }
        } catch (_) {}
      }

      // Pull resource logs
      final remoteResources = await remoteDataSource.pullResourceLogs();
      for (final resData in remoteResources) {
        try {
          final model = ResourceLogModel.fromMap(resData);
          await localDataSource.saveResourceLog(model);
        } catch (_) {}
      }

      // Pull activity events
      final remoteEvents = await remoteDataSource.pullActivityEvents();
      for (final eventData in remoteEvents) {
        try {
          final model = ActivityEventModel.fromMap(eventData);
          await localDataSource.saveActivityEvent(model);
        } catch (_) {}
      }
    } catch (_) {
      // Ignored if offline
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
