import '../../../../core/database/local_data_source.dart';
import '../../domain/entities/sync_operation_entity.dart';
import '../../domain/repositories/sync_repository.dart';
import '../models/sync_operation_model.dart';

class SyncRepositoryImpl implements SyncRepository {
  final LocalDataSource localDataSource;

  SyncRepositoryImpl({required this.localDataSource});

  @override
  Future<void> enqueueOperation(SyncOperationEntity operation) async {
    final model = SyncOperationModel.fromEntity(operation);
    await localDataSource.enqueueSyncOperation(model);
  }

  @override
  Future<List<SyncOperationEntity>> getPendingOperations() async {
    final models = await localDataSource.getPendingSyncOperations();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<SyncOperationEntity>> getAllOperations() async {
    final models = await localDataSource.getAllSyncOperations();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> updateOperationStatus(
    String operationId,
    SyncStatus newStatus, {
    String? errorMessage,
    int? retryCount,
  }) async {
    await localDataSource.updateSyncOperationState(
      operationId,
      newStatus.toDbValue(),
      errorMessage: errorMessage,
      retryCount: retryCount,
    );
  }

  @override
  Future<int> getPendingCount() async {
    return await localDataSource.getPendingSyncCount();
  }

  @override
  Future<int> getFailedCount() async {
    return await localDataSource.getFailedSyncCount();
  }

  @override
  Future<void> removeOperation(String operationId) async {
    await localDataSource.removeSyncOperation(operationId);
  }

  @override
  Future<void> clearSyncedOperations() async {
    await localDataSource.clearSyncedOperations();
  }
}

