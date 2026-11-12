import '../entities/resource_log_entity.dart';
import '../entities/resource_summary_item.dart';

/// Contract for Resource Logging and Aggregation per PRD §4.2.
abstract class ResourceRepository {
  /// Emits whenever resource logs are created or updated.
  Stream<void> get onResourcesChanged;

  /// Records a new resource log for an incident.
  /// Validates quantity > 0 and required fields.
  /// Automatically logs an ActivityEvent and enqueues a SyncOperation.
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  });

  /// Retrieves all resource logs recorded for the specified incident.
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId);

  /// Retrieves aggregated summary totals grouped by resource type and unit.
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId);
}

