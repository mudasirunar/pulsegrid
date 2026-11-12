import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pulsegrid/core/database/app_database.dart';
import 'package:pulsegrid/core/database/local_data_source.dart';
import 'package:pulsegrid/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:pulsegrid/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:pulsegrid/features/sync/domain/repositories/sync_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase database;
  late LocalDataSource localDataSource;
  late SyncRepository syncRepository;

  setUp(() async {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    localDataSource = LocalDataSourceImpl(database);
    syncRepository = SyncRepositoryImpl(localDataSource: localDataSource);
  });

  tearDown(() async {
    await database.close();
  });

  SyncOperationEntity makeOp({
    required String id,
    SyncStatus status = SyncStatus.pending,
    int retryCount = 0,
    String? error,
  }) {
    return SyncOperationEntity(
      operationId: id,
      entityId: 'entity-$id',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.create,
      payload: '{"id":"entity-$id"}',
      retryCount: retryCount,
      status: status,
      errorMessage: error,
      createdAt: DateTime.now(),
    );
  }

  test('enqueues, queries, and counts pending and failed sync operations', () async {
    expect(await syncRepository.getPendingCount(), 0);
    expect(await syncRepository.getFailedCount(), 0);

    final op1 = makeOp(id: 'op-1', status: SyncStatus.pending);
    final op2 = makeOp(id: 'op-2', status: SyncStatus.failed, retryCount: 1, error: 'Network');
    final op3 = makeOp(id: 'op-3', status: SyncStatus.synced);

    await syncRepository.enqueueOperation(op1);
    await syncRepository.enqueueOperation(op2);
    await syncRepository.enqueueOperation(op3);

    expect(await syncRepository.getPendingCount(), 1);
    expect(await syncRepository.getFailedCount(), 1);

    final all = await syncRepository.getAllOperations();
    expect(all.length, 3);

    // Pending operations includes both PENDING and FAILED
    final pendingOps = await syncRepository.getPendingOperations();
    expect(pendingOps.length, 2);
    expect(pendingOps.map((o) => o.operationId), containsAll(['op-1', 'op-2']));
  });

  test('updates operation status and clears synced operations', () async {
    final op = makeOp(id: 'op-1', status: SyncStatus.pending);
    await syncRepository.enqueueOperation(op);

    await syncRepository.updateOperationStatus(
      'op-1',
      SyncStatus.syncing,
    );
    var updated = (await syncRepository.getAllOperations()).first;
    expect(updated.status, SyncStatus.syncing);

    await syncRepository.updateOperationStatus(
      'op-1',
      SyncStatus.synced,
    );
    updated = (await syncRepository.getAllOperations()).first;
    expect(updated.status, SyncStatus.synced);

    await syncRepository.clearSyncedOperations();
    final remaining = await syncRepository.getAllOperations();
    expect(remaining, isEmpty);
  });

  test('removes individual operation by ID', () async {
    final op1 = makeOp(id: 'op-1');
    final op2 = makeOp(id: 'op-2');
    await syncRepository.enqueueOperation(op1);
    await syncRepository.enqueueOperation(op2);

    await syncRepository.removeOperation('op-1');

    final all = await syncRepository.getAllOperations();
    expect(all.length, 1);
    expect(all.first.operationId, 'op-2');
  });
}

