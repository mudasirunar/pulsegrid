import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../../core/network/network_info.dart';
import '../../../incidents/data/models/activity_event_model.dart';
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
  StreamSubscription<String>? _tableSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isSyncing = false;

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

  Future<void> _mergeAndSaveRemoteIncident(IncidentModel model) async {
    final local = await localDataSource.getIncidentById(model.id);
    if (local == null) {
      await localDataSource.saveIncident(model);
      return;
    }
    if (model.version < local.version) {
      return;
    }
    final effective = (model.photoPaths.isEmpty && local.photoPaths.isNotEmpty)
        ? model.copyWith(photoPaths: local.photoPaths)
        : model;
    if (effective != local) {
      await localDataSource.saveIncident(effective);
    }
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
  }

  void _stopListeningToRemote() {
    _remoteIncidentsSubscription?.cancel();
    _remoteIncidentsSubscription = null;
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
        if (incidentData == null) return;
        try {
          final model = IncidentModel.fromMap(incidentData);
          await _mergeAndSaveRemoteIncident(model);
        } catch (_) {}
      },
      onError: (_) {},
    );

    return ScopedIncidentSubscription([logSub, eventSub, incSub]);
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

      // Reconcile any local-only entities missing from both sync_operations and Firestore
      final allOps = await localDataSource.getAllSyncOperations();
      final trackedEntityIds = allOps.map((op) => op.entityId).toSet();
      bool enqueuedAny = false;

      final allIncidents = await localDataSource.getAllIncidents();
      for (final incident in allIncidents) {
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
    _tableSubscription?.cancel();
    _authSubscription?.cancel();
  }
}
