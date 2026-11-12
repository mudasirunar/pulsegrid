import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:pulsegrid/features/sync/domain/repositories/sync_repository.dart';
import 'package:pulsegrid/features/sync/domain/services/sync_queue_manager.dart';

class _FakeSyncRepository implements SyncRepository {
  final List<SyncOperationEntity> operations = [];

  @override
  Future<void> enqueueOperation(SyncOperationEntity operation) async {
    operations.add(operation);
  }

  @override
  Future<List<SyncOperationEntity>> getPendingOperations() async {
    return operations
        .where((o) => o.status == SyncStatus.pending || o.status == SyncStatus.failed)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<SyncOperationEntity>> getAllOperations() async {
    return List.from(operations);
  }

  @override
  Future<void> updateOperationStatus(
    String operationId,
    SyncStatus newStatus, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final idx = operations.indexWhere((o) => o.operationId == operationId);
    if (idx != -1) {
      operations[idx] = operations[idx].copyWith(
        status: newStatus,
        errorMessage: errorMessage,
        retryCount: retryCount,
      );
    }
  }

  @override
  Future<int> getPendingCount() async {
    return operations.where((o) => o.status == SyncStatus.pending).length;
  }

  @override
  Future<int> getFailedCount() async {
    return operations.where((o) => o.status == SyncStatus.failed).length;
  }

  @override
  Future<void> removeOperation(String operationId) async {
    operations.removeWhere((o) => o.operationId == operationId);
  }

  @override
  Future<void> clearSyncedOperations() async {
    operations.removeWhere((o) => o.status == SyncStatus.synced);
  }
}

void main() {
  late _FakeSyncRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeSyncRepository();
  });

  SyncOperationEntity makeOp({
    required String id,
    DateTime? createdAt,
    SyncStatus status = SyncStatus.pending,
    int retryCount = 0,
  }) {
    return SyncOperationEntity(
      operationId: id,
      entityId: 'inc-$id',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.create,
      payload: '{"title":"Test"}',
      retryCount: retryCount,
      status: status,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  test('calculateBackoff scales exponentially and caps at 60 seconds', () {
    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      baseBackoff: const Duration(seconds: 2),
    );

    expect(manager.calculateBackoff(0), Duration.zero);
    expect(manager.calculateBackoff(1), const Duration(seconds: 2)); // 2 * 2^0 = 2
    expect(manager.calculateBackoff(2), const Duration(seconds: 4)); // 2 * 2^1 = 4
    expect(manager.calculateBackoff(3), const Duration(seconds: 8)); // 2 * 2^2 = 8
    expect(manager.calculateBackoff(6), const Duration(seconds: 60)); // capped at 60s
  });

  test('processes queued operations in FIFO order and marks SYNCED on success', () async {
    final dispatchedIds = <String>[];
    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      remoteSyncHandler: (op) async {
        dispatchedIds.add(op.operationId);
      },
    );

    final op1 = makeOp(id: 'op-1', createdAt: DateTime.now().subtract(const Duration(minutes: 5)));
    final op2 = makeOp(id: 'op-2', createdAt: DateTime.now().subtract(const Duration(minutes: 2)));
    final op3 = makeOp(id: 'op-3', createdAt: DateTime.now());

    await fakeRepo.enqueueOperation(op2);
    await fakeRepo.enqueueOperation(op3);
    await fakeRepo.enqueueOperation(op1);

    final metrics = await manager.processQueue();

    // Dispatched in FIFO chronological order
    expect(dispatchedIds, ['op-1', 'op-2', 'op-3']);
    expect(fakeRepo.operations.every((o) => o.status == SyncStatus.synced), isTrue);
    expect(metrics.pendingCount, 0);
    expect(metrics.failedCount, 0);
    expect(metrics.overallStatus, SyncStatus.synced);
    expect(manager.lastSyncedAt, isNotNull);
  });

  test('marks operation FAILED and increments retryCount on handler error', () async {
    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      remoteSyncHandler: (op) async {
        if (op.operationId == 'op-fail') {
          throw Exception('Remote server unreachable');
        }
      },
    );

    await fakeRepo.enqueueOperation(makeOp(id: 'op-fail'));
    await fakeRepo.enqueueOperation(makeOp(id: 'op-success'));

    final metrics = await manager.processQueue();

    final failed = fakeRepo.operations.firstWhere((o) => o.operationId == 'op-fail');
    expect(failed.status, SyncStatus.failed);
    expect(failed.retryCount, 1);
    expect(failed.errorMessage, contains('Remote server unreachable'));

    final success = fakeRepo.operations.firstWhere((o) => o.operationId == 'op-success');
    expect(success.status, SyncStatus.synced);

    expect(metrics.failedCount, 1);
    expect(metrics.overallStatus, SyncStatus.failed);
  });

  test('skips failed operations during backoff window unless forced', () async {
    final dispatched = <String>[];
    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      baseBackoff: const Duration(seconds: 10),
      remoteSyncHandler: (op) async {
        dispatched.add(op.operationId);
      },
    );

    // op created just 2 seconds ago with retryCount 1 (needs 10s backoff)
    final recentlyFailedOp = makeOp(
      id: 'op-backoff',
      createdAt: DateTime.now().subtract(const Duration(seconds: 2)),
      status: SyncStatus.failed,
      retryCount: 1,
    );
    await fakeRepo.enqueueOperation(recentlyFailedOp);

    // Regular processQueue skips it because backoff window is still active
    await manager.processQueue(force: false);
    expect(dispatched, isEmpty);

    // Forced processQueue dispatches it regardless of backoff
    await manager.processQueue(force: true);
    expect(dispatched, ['op-backoff']);
  });

  test('retryFailedOperations resets failed ops and forces processing', () async {
    var shouldFail = true;
    final dispatched = <String>[];

    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      remoteSyncHandler: (op) async {
        dispatched.add(op.operationId);
        if (shouldFail) {
          throw Exception('Transient error');
        }
      },
    );

    await fakeRepo.enqueueOperation(makeOp(id: 'op-retry'));

    // First attempt fails
    await manager.processQueue();
    expect(fakeRepo.operations.first.status, SyncStatus.failed);
    expect(fakeRepo.operations.first.retryCount, 1);

    // Remote recovery: now it will succeed
    shouldFail = false;
    dispatched.clear();

    final metrics = await manager.retryFailedOperations();
    expect(dispatched, ['op-retry']);
    expect(fakeRepo.operations.first.status, SyncStatus.synced);
    expect(metrics.failedCount, 0);
  });

  test('prevents concurrent queue runs via isProcessing lock', () async {
    final completer = Completer<void>();
    final manager = SyncQueueManager(
      syncRepository: fakeRepo,
      remoteSyncHandler: (op) async {
        await completer.future;
      },
    );

    await fakeRepo.enqueueOperation(makeOp(id: 'op-1'));

    // Start first run (will wait on completer)
    final firstRun = manager.processQueue();
    expect(manager.isProcessing, isTrue);

    // Second run should return immediately without waiting or running twice
    final secondRun = await manager.processQueue();
    expect(secondRun.isSyncing, isTrue);

    // Unblock first run
    completer.complete();
    await firstRun;
    expect(manager.isProcessing, isFalse);
  });
}

