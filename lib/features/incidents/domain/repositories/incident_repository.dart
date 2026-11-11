import '../../../auth/domain/entities/user_entity.dart';
import '../entities/activity_event_entity.dart';
import '../entities/incident_entity.dart';
import '../entities/incident_severity.dart';
import '../entities/incident_status.dart';

abstract class IncidentRepository {
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  });

  Future<IncidentEntity?> getIncidentById(String id);

  Future<IncidentEntity> createIncident(IncidentEntity incident);

  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  });

  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId);
}

