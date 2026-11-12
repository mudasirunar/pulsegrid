import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:pulsegrid/features/sync/domain/repositories/sync_repository.dart';
import 'package:pulsegrid/features/sync/domain/services/sync_queue_manager.dart';
import 'package:pulsegrid/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:pulsegrid/features/sync/presentation/bloc/sync_event.dart';
import 'package:pulsegrid/features/sync/presentation/bloc/sync_state.dart';

class _FakeSyncRepository implements SyncRepository {
  final List<SyncOperationEntity> ops = [];

  @override
  Future<void> enqueueOperation(SyncOperationEntity operation) async {
    ops.add(operation);
  }

  @override
  Future<List<SyncOperationEntity>> getPendingOperations() async =>
      ops.where((o) => o.status == SyncStatus.pending || o.status == SyncStatus.failed).toList();

  @override
  Future<List<SyncOperationEntity>> getAllOperations() async => List.from(ops);

  @override
  Future<void> updateOperationStatus(
    String operationId,
    SyncStatus newStatus, {
    String? errorMessage,
    int? retryCount,
  }) async {
    final idx = ops.indexWhere((o) => o.operationId == operationId);
    if (idx != -1) {
      ops[idx] = ops[idx].copyWith(
        status: newStatus,
        errorMessage: errorMessage,
        retryCount: retryCount,
      );
    }
  }

  @override
  Future<int> getPendingCount() async => ops.where((o) => o.status == SyncStatus.pending).length;

  @override
  Future<int> getFailedCount() async => ops.where((o) => o.status == SyncStatus.failed).length;

  @override
  Future<void> removeOperation(String operationId) async {
    ops.removeWhere((o) => o.operationId == operationId);
  }

  @override
  Future<void> clearSyncedOperations() async {
    ops.removeWhere((o) => o.status == SyncStatus.synced);
  }
}

void main() {
  late _FakeSyncRepository fakeRepo;
  late SyncQueueManager queueManager;
  late SyncBloc syncBloc;

  setUp(() {
    fakeRepo = _FakeSyncRepository();
    queueManager = SyncQueueManager(syncRepository: fakeRepo);
    syncBloc = SyncBloc(syncQueueManager: queueManager);
  });

  tearDown(() {
    syncBloc.close();
    queueManager.dispose();
  });

  SyncOperationEntity makeOp(String id, {SyncStatus status = SyncStatus.pending}) {
    return SyncOperationEntity(
      operationId: id,
      entityId: 'inc-$id',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.create,
      payload: '{}',
      status: status,
      createdAt: DateTime.now(),
    );
  }

  test('initial state has default Synced status and 0 counts', () {
    expect(syncBloc.state, const SyncState());
    expect(syncBloc.state.status, SyncStatus.synced);
    expect(syncBloc.state.pendingCount, 0);
  });

  test('SyncStarted event queries queue metrics and updates state', () async {
    await fakeRepo.enqueueOperation(makeOp('op-1'));
    await fakeRepo.enqueueOperation(makeOp('op-2', status: SyncStatus.failed));

    syncBloc.add(const SyncStarted());
    await pumpEventQueue();

    expect(syncBloc.state.pendingCount, 1);
    expect(syncBloc.state.failedCount, 1);
    expect(syncBloc.state.status, SyncStatus.failed);
  });

  test('TriggerSyncEvent dispatches queue and emits Synced upon completion', () async {
    await fakeRepo.enqueueOperation(makeOp('op-1'));

    syncBloc.add(const TriggerSyncEvent());
    await pumpEventQueue();

    expect(syncBloc.state.pendingCount, 0);
    expect(syncBloc.state.failedCount, 0);
    expect(syncBloc.state.status, SyncStatus.synced);
  });

  test('RetryFailedSyncEvent triggers retry and resets failed count', () async {
    await fakeRepo.enqueueOperation(makeOp('op-fail', status: SyncStatus.failed));

    syncBloc.add(const RetryFailedSyncEvent());
    await pumpEventQueue();

    expect(syncBloc.state.failedCount, 0);
    expect(syncBloc.state.status, SyncStatus.synced);
  });
}
