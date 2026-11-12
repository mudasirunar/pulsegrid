import 'package:equatable/equatable.dart';

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict;

  String get displayName {
    switch (this) {
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.failed:
        return 'Failed';
      case SyncStatus.conflict:
        return 'Conflict';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SYNCING':
        return SyncStatus.syncing;
      case 'SYNCED':
        return SyncStatus.synced;
      case 'FAILED':
        return SyncStatus.failed;
      case 'CONFLICT':
        return SyncStatus.conflict;
      case 'PENDING':
      default:
        return SyncStatus.pending;
    }
  }

  String toDbValue() {
    switch (this) {
      case SyncStatus.pending:
        return 'PENDING';
      case SyncStatus.syncing:
        return 'SYNCING';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.failed:
        return 'FAILED';
      case SyncStatus.conflict:
        return 'CONFLICT';
    }
  }
}

enum SyncOperationType {
  create,
  update,
  delete;

  static SyncOperationType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'UPDATE':
        return SyncOperationType.update;
      case 'DELETE':
        return SyncOperationType.delete;
      case 'CREATE':
      default:
        return SyncOperationType.create;
    }
  }

  String toDbValue() {
    switch (this) {
      case SyncOperationType.create:
        return 'CREATE';
      case SyncOperationType.update:
        return 'UPDATE';
      case SyncOperationType.delete:
        return 'DELETE';
    }
  }
}

enum SyncEntityType {
  incident,
  resource,
  assignment,
  activityEvent;

  static SyncEntityType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RESOURCE':
      case 'RESOURCE_LOG':
        return SyncEntityType.resource;
      case 'ASSIGNMENT':
        return SyncEntityType.assignment;
      case 'ACTIVITY_EVENT':
        return SyncEntityType.activityEvent;
      case 'INCIDENT':
      default:
        return SyncEntityType.incident;
    }
  }

  String toDbValue() {
    switch (this) {
      case SyncEntityType.incident:
        return 'INCIDENT';
      case SyncEntityType.resource:
        return 'RESOURCE_LOG';
      case SyncEntityType.assignment:
        return 'ASSIGNMENT';
      case SyncEntityType.activityEvent:
        return 'ACTIVITY_EVENT';
    }
  }
}

class SyncOperationEntity extends Equatable {
  final String operationId;
  final String entityId;
  final SyncEntityType entityType;
  final SyncOperationType operationType;
  final String payload;
  final int retryCount;
  final SyncStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  const SyncOperationEntity({
    required this.operationId,
    required this.entityId,
    required this.entityType,
    required this.operationType,
    required this.payload,
    this.retryCount = 0,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  SyncOperationEntity copyWith({
    String? operationId,
    String? entityId,
    SyncEntityType? entityType,
    SyncOperationType? operationType,
    String? payload,
    int? retryCount,
    SyncStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? createdAt,
  }) {
    return SyncOperationEntity(
      operationId: operationId ?? this.operationId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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
        status,
        errorMessage,
        createdAt,
      ];
}
