import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/entities/incident_severity.dart';
import '../../../incidents/domain/entities/incident_status.dart';

enum DashboardStatusFilter {
  all('All'),
  open('Open'),
  newIncident('New'),
  assigned('Assigned'),
  inProgress('In Progress'),
  resolved('Resolved'),
  closed('Closed');

  final String label;
  const DashboardStatusFilter(this.label);
}

enum DashboardAssignmentFilter { all, assignedToMe, assigned, unassigned }

enum DashboardSort { recent, severity }

class DashboardFilterState {
  final String searchQuery;
  final DashboardStatusFilter statusFilter;
  final IncidentSeverity? severityFilter;
  final DashboardAssignmentFilter assignmentFilter;
  final DashboardSort sortBy;

  const DashboardFilterState({
    this.searchQuery = '',
    this.statusFilter = DashboardStatusFilter.all,
    this.severityFilter,
    this.assignmentFilter = DashboardAssignmentFilter.all,
    this.sortBy = DashboardSort.recent,
  });

  int get activeCount {
    int count = 0;
    if (statusFilter != DashboardStatusFilter.all) count++;
    if (severityFilter != null) count++;
    if (assignmentFilter != DashboardAssignmentFilter.all) count++;
    if (sortBy != DashboardSort.recent) count++;
    return count;
  }

  DashboardFilterState copyWith({
    String? searchQuery,
    DashboardStatusFilter? statusFilter,
    IncidentSeverity? severityFilter,
    bool clearSeverity = false,
    DashboardAssignmentFilter? assignmentFilter,
    DashboardSort? sortBy,
  }) {
    return DashboardFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      severityFilter:
          clearSeverity ? null : (severityFilter ?? this.severityFilter),
      assignmentFilter: assignmentFilter ?? this.assignmentFilter,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  DashboardFilterState cleared() => const DashboardFilterState();

  List<IncidentEntity> apply(
    List<IncidentEntity> source, {
    required Map<String, String> incidentAssignees,
    required String currentUserId,
  }) {
    final query = searchQuery.trim().toLowerCase();

    final filtered = source.where((incident) {
      if (query.isNotEmpty) {
        final matchesTitle = incident.title.toLowerCase().contains(query);
        final matchesId = incident.id.toLowerCase().contains(query);
        if (!matchesTitle && !matchesId) return false;
      }

      switch (statusFilter) {
        case DashboardStatusFilter.all:
          break;
        case DashboardStatusFilter.open:
          if (incident.status == IncidentStatus.closed) return false;
        case DashboardStatusFilter.newIncident:
          if (incident.status != IncidentStatus.newIncident) return false;
        case DashboardStatusFilter.assigned:
          if (incident.status != IncidentStatus.assigned) return false;
        case DashboardStatusFilter.inProgress:
          if (incident.status != IncidentStatus.inProgress) return false;
        case DashboardStatusFilter.resolved:
          if (incident.status != IncidentStatus.resolved) return false;
        case DashboardStatusFilter.closed:
          if (incident.status != IncidentStatus.closed) return false;
      }

      if (severityFilter != null && incident.severity != severityFilter) {
        return false;
      }

      final assigneeId = incidentAssignees[incident.id];
      switch (assignmentFilter) {
        case DashboardAssignmentFilter.all:
          break;
        case DashboardAssignmentFilter.assignedToMe:
          if (assigneeId != currentUserId) return false;
        case DashboardAssignmentFilter.assigned:
          if (assigneeId == null || assigneeId.isEmpty) return false;
        case DashboardAssignmentFilter.unassigned:
          if (assigneeId != null && assigneeId.isNotEmpty) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      if (sortBy == DashboardSort.severity) {
        final sevCompare =
            b.severity.priorityWeight.compareTo(a.severity.priorityWeight);
        if (sevCompare != 0) return sevCompare;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return filtered;
  }
}

