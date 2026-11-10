import 'package:equatable/equatable.dart';
import '../../../../core/database/database_constants.dart';

class SyncOperationModel extends Equatable {
  final String operationId;
  final String entityId;
  final String entityType;
  final String operationType; // CREATE, UPDATE, DELETE
  final String payload;
  final int retryCount;
  final String syncState; // PENDING, SYNCING, SYNCED, FAILED, CONFLICT
  final String? errorMessage;
  final DateTime createdAt;

  const SyncOperationModel({
    required this.operationId,
    required this.entityId,
    required this.entityType,
    required this.operationType,
    required this.payload,
    this.retryCount = 0,
    required this.syncState,
    this.errorMessage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colOperationId: operationId,
      DatabaseConstants.colEntityId: entityId,
      DatabaseConstants.colEntityType: entityType,
      DatabaseConstants.colOperationType: operationType,
      DatabaseConstants.colPayload: payload,
      DatabaseConstants.colRetryCount: retryCount,
      DatabaseConstants.colSyncState: syncState,
      DatabaseConstants.colErrorMessage: errorMessage,
      DatabaseConstants.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory SyncOperationModel.fromMap(Map<String, dynamic> map) {
    return SyncOperationModel(
      operationId: map[DatabaseConstants.colOperationId] as String,
      entityId: map[DatabaseConstants.colEntityId] as String,
      entityType: map[DatabaseConstants.colEntityType] as String,
      operationType: map[DatabaseConstants.colOperationType] as String,
      payload: map[DatabaseConstants.colPayload] as String,
      retryCount: (map[DatabaseConstants.colRetryCount] as num?)?.toInt() ?? 0,
      syncState: map[DatabaseConstants.colSyncState] as String,
      errorMessage: map[DatabaseConstants.colErrorMessage] as String?,
      createdAt: DateTime.parse(map[DatabaseConstants.colCreatedAt] as String),
    );
  }

  SyncOperationModel copyWith({
    String? operationId,
    String? entityId,
    String? entityType,
    String? operationType,
    String? payload,
    int? retryCount,
    String? syncState,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return SyncOperationModel(
      operationId: operationId ?? this.operationId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      syncState: syncState ?? this.syncState,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        operationId,
        entityId,
        entityType,
        operationType,
        payload,
        retryCount,
        syncState,
        errorMessage,
        createdAt,
      ];
}

