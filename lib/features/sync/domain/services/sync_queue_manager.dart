import 'dart:async';
import 'dart:math';

import '../entities/sync_operation_entity.dart';
import '../repositories/sync_repository.dart';

typedef RemoteSyncHandler = Future<void> Function(SyncOperationEntity operation);

class SyncQueueMetrics {
  final int pendingCount;
  final int failedCount;
  final bool isSyncing;
  final DateTime? lastSyncedAt;

  const SyncQueueMetrics({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.lastSyncedAt,
  });

  SyncStatus get overallStatus {
    if (isSyncing) return SyncStatus.syncing;
    if (failedCount > 0) return SyncStatus.failed;
    if (pendingCount > 0) return SyncStatus.pending;
    return SyncStatus.synced;
  }
}

class SyncQueueManager {
  final SyncRepository syncRepository;
  RemoteSyncHandler? remoteSyncHandler;
  final int maxRetries;
  final Duration baseBackoff;

  bool _isProcessing = false;
  DateTime? _lastSyncedAt;
  final StreamController<SyncQueueMetrics> _metricsController =
      StreamController<SyncQueueMetrics>.broadcast();

  SyncQueueManager({
    required this.syncRepository,
    this.remoteSyncHandler,
    this.maxRetries = 5,
    this.baseBackoff = const Duration(seconds: 1),
  });

  void setRemoteSyncHandler(RemoteSyncHandler handler) {
    remoteSyncHandler = handler;
  }

  Stream<SyncQueueMetrics> get metricsStream => _metricsController.stream;
  bool get isProcessing => _isProcessing;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Calculates exponential backoff duration based on retry count.
  /// backoff = min(baseBackoff * 2^(retryCount - 1), 60 seconds)
  Duration calculateBackoff(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    final exponent = min(retryCount - 1, 6);
    final multiplier = pow(2, exponent).toInt();
    final totalSeconds = baseBackoff.inSeconds * multiplier;
    return Duration(seconds: min(totalSeconds, 60));
  }

  /// Processes queued pending and failed operations sequentially in FIFO order.
  /// If [force] is true, ignores exponential backoff and retry limits.
  Future<SyncQueueMetrics> processQueue({bool force = false}) async {
    if (_isProcessing) {
      return await getMetrics();
    }

    _isProcessing = true;
    _emitMetrics();

    try {
      final operations = await syncRepository.getPendingOperations();

      for (final operation in operations) {
        // Enforce retry limits unless forced
        if (!force && operation.retryCount >= maxRetries) {
          continue;
        }

        // Enforce exponential backoff unless forced
        if (!force && operation.status == SyncStatus.failed) {
          final backoff = calculateBackoff(operation.retryCount);
          final nextAllowedAttempt = operation.createdAt.add(backoff);
          if (DateTime.now().isBefore(nextAllowedAttempt)) {
            continue;
          }
        }

        // Mark operation as SYNCING
        await syncRepository.updateOperationStatus(
          operation.operationId,
          SyncStatus.syncing,
        );
        _emitMetrics();

        try {
          if (remoteSyncHandler != null) {
            await remoteSyncHandler!(operation);
          }
          // Mark SYNCED on success
          await syncRepository.updateOperationStatus(
            operation.operationId,
            SyncStatus.synced,
          );
          _lastSyncedAt = DateTime.now();
        } catch (e) {
          final newRetryCount = operation.retryCount + 1;
          await syncRepository.updateOperationStatus(
            operation.operationId,
            SyncStatus.failed,
            errorMessage: e.toString(),
            retryCount: newRetryCount,
          );
        }
      }
    } finally {
      _isProcessing = false;
      _emitMetrics();
    }

    return await getMetrics();
  }

  /// Manually retries all failed operations by resetting them to PENDING and triggering sync.
  Future<SyncQueueMetrics> retryFailedOperations() async {
    final operations = await syncRepository.getAllOperations();
    final failedOps = operations.where((op) => op.status == SyncStatus.failed);

    for (final op in failedOps) {
      await syncRepository.updateOperationStatus(
        op.operationId,
        SyncStatus.pending,
        retryCount: 0,
        errorMessage: null,
      );
    }

    return await processQueue(force: true);
  }

  /// Fetches current snapshot of sync queue metrics.
  Future<SyncQueueMetrics> getMetrics() async {
    final pending = await syncRepository.getPendingCount();
    final failed = await syncRepository.getFailedCount();
    return SyncQueueMetrics(
      pendingCount: pending,
      failedCount: failed,
      isSyncing: _isProcessing,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<void> _emitMetrics() async {
    if (!_metricsController.isClosed) {
      final metrics = await getMetrics();
      _metricsController.add(metrics);
    }
  }

  void dispose() {
    _metricsController.close();
  }
}

