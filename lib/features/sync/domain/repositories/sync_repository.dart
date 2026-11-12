import '../entities/sync_operation_entity.dart';

abstract class SyncRepository {
  Future<void> enqueueOperation(SyncOperationEntity operation);
  Future<List<SyncOperationEntity>> getPendingOperations();
  Future<List<SyncOperationEntity>> getAllOperations();
  Future<void> updateOperationStatus(
    String operationId,
    SyncStatus newStatus, {
    String? errorMessage,
    int? retryCount,
  });
  Future<int> getPendingCount();
  Future<int> getFailedCount();
  Future<void> removeOperation(String operationId);
  Future<void> clearSyncedOperations();
}

