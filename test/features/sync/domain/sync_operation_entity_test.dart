import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/sync/data/models/sync_operation_model.dart';
import 'package:pulsegrid/features/sync/domain/entities/sync_operation_entity.dart';

void main() {
  group('SyncEnums Tests', () {
    test('SyncStatus converts properly between string and db values', () {
      expect(SyncStatus.fromString('PENDING'), SyncStatus.pending);
      expect(SyncStatus.fromString('SYNCING'), SyncStatus.syncing);
      expect(SyncStatus.fromString('SYNCED'), SyncStatus.synced);
      expect(SyncStatus.fromString('FAILED'), SyncStatus.failed);
      expect(SyncStatus.fromString('CONFLICT'), SyncStatus.conflict);
      expect(SyncStatus.fromString('UNKNOWN'), SyncStatus.pending);

      expect(SyncStatus.pending.toDbValue(), 'PENDING');
      expect(SyncStatus.syncing.toDbValue(), 'SYNCING');
      expect(SyncStatus.synced.toDbValue(), 'SYNCED');
      expect(SyncStatus.failed.toDbValue(), 'FAILED');
      expect(SyncStatus.conflict.toDbValue(), 'CONFLICT');

      expect(SyncStatus.pending.displayName, 'Pending');
      expect(SyncStatus.syncing.displayName, 'Syncing');
      expect(SyncStatus.synced.displayName, 'Synced');
      expect(SyncStatus.failed.displayName, 'Failed');
      expect(SyncStatus.conflict.displayName, 'Conflict');
    });

    test('SyncOperationType converts properly between string and db values', () {
      expect(SyncOperationType.fromString('CREATE'), SyncOperationType.create);
      expect(SyncOperationType.fromString('UPDATE'), SyncOperationType.update);
      expect(SyncOperationType.fromString('DELETE'), SyncOperationType.delete);
      expect(SyncOperationType.fromString('UNKNOWN'), SyncOperationType.create);

      expect(SyncOperationType.create.toDbValue(), 'CREATE');
      expect(SyncOperationType.update.toDbValue(), 'UPDATE');
      expect(SyncOperationType.delete.toDbValue(), 'DELETE');
    });

    test('SyncEntityType converts properly between string and db values', () {
      expect(SyncEntityType.fromString('INCIDENT'), SyncEntityType.incident);
      expect(SyncEntityType.fromString('RESOURCE'), SyncEntityType.resource);
      expect(SyncEntityType.fromString('RESOURCE_LOG'), SyncEntityType.resource);
      expect(SyncEntityType.fromString('ASSIGNMENT'), SyncEntityType.assignment);
      expect(SyncEntityType.fromString('ACTIVITY_EVENT'), SyncEntityType.activityEvent);
      expect(SyncEntityType.fromString('UNKNOWN'), SyncEntityType.incident);

      expect(SyncEntityType.incident.toDbValue(), 'INCIDENT');
      expect(SyncEntityType.resource.toDbValue(), 'RESOURCE_LOG');
      expect(SyncEntityType.assignment.toDbValue(), 'ASSIGNMENT');
      expect(SyncEntityType.activityEvent.toDbValue(), 'ACTIVITY_EVENT');
    });
  });

  group('SyncOperationEntity & Model Mappings', () {
    final now = DateTime.parse('2026-10-24T12:00:00.000Z');

    final entity = SyncOperationEntity(
      operationId: 'op-101',
      entityId: 'inc-500',
      entityType: SyncEntityType.incident,
      operationType: SyncOperationType.create,
      payload: '{"title":"Chemical Spill"}',
      retryCount: 2,
      status: SyncStatus.failed,
      errorMessage: 'Network timeout',
      createdAt: now,
    );

    test('toEntity and fromEntity convert losslessly', () {
      final model = SyncOperationModel.fromEntity(entity);
      expect(model.operationId, 'op-101');
      expect(model.entityId, 'inc-500');
      expect(model.entityType, 'INCIDENT');
      expect(model.operationType, 'CREATE');
      expect(model.payload, '{"title":"Chemical Spill"}');
      expect(model.retryCount, 2);
      expect(model.syncState, 'FAILED');
      expect(model.errorMessage, 'Network timeout');
      expect(model.createdAt, now);

      final convertedEntity = model.toEntity();
      expect(convertedEntity, entity);
    });

    test('copyWith updates specified fields correctly', () {
      final updated = entity.copyWith(
        status: SyncStatus.synced,
        retryCount: 0,
        clearErrorMessage: true,
      );

      expect(updated.status, SyncStatus.synced);
      expect(updated.retryCount, 0);
      expect(updated.errorMessage, isNull);
      expect(updated.operationId, entity.operationId);
    });
  });
}
