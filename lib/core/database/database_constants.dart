abstract class DatabaseConstants {
  static const String databaseName = 'pulsegrid.db';
  static const int databaseVersion = 1;

  // Table Names
  static const String tableIncidents = 'incidents';
  static const String tableAssignments = 'assignments';
  static const String tableResourceLogs = 'resource_logs';
  static const String tableActivityEvents = 'activity_events';
  static const String tableSyncOperations = 'sync_operations';

  // Common Columns
  static const String colId = 'id';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';

  // Incident Columns
  static const String colTitle = 'title';
  static const String colCategory = 'category';
  static const String colSeverity = 'severity';
  static const String colDescription = 'description';
  static const String colStatus = 'status';
  static const String colVersion = 'version';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colManualLocationNotes = 'manualLocationNotes';
  static const String colPhotoPath = 'photoPath';
  static const String colCreatedBy = 'createdBy';

  // Assignment Columns
  static const String colIncidentId = 'incidentId';
  static const String colResponderId = 'responderId';
  static const String colAssignedBy = 'assignedBy';
  static const String colAssignedAt = 'assignedAt';

  // ResourceLog Columns
  static const String colResourceType = 'resourceType';
  static const String colQuantity = 'quantity';
  static const String colUnit = 'unit';
  static const String colNotes = 'notes';
  static const String colLoggedBy = 'loggedBy';

  // ActivityEvent Columns
  static const String colActorId = 'actorId';
  static const String colEventType = 'eventType';
  static const String colOldValue = 'oldValue';
  static const String colNewValue = 'newValue';
  static const String colTimestamp = 'timestamp';

  // SyncOperation Columns
  static const String colOperationId = 'operationId';
  static const String colEntityId = 'entityId';
  static const String colEntityType = 'entityType';
  static const String colOperationType = 'operationType';
  static const String colPayload = 'payload';
  static const String colRetryCount = 'retryCount';
  static const String colSyncState = 'syncState';
  static const String colErrorMessage = 'errorMessage';
}

