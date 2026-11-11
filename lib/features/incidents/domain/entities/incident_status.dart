/// Validated Lifecycle Statuses for Pulse Grid Incidents
/// Enforces the strict unidirectional state flow:
/// New -> Assigned -> In Progress -> Resolved -> Closed
enum IncidentStatus {
  newIncident('New'),
  assigned('Assigned'),
  inProgress('In Progress'),
  resolved('Resolved'),
  closed('Closed');

  final String value;
  const IncidentStatus(this.value);

  static IncidentStatus fromString(String val) {
    final clean = val.trim().toLowerCase();
    return IncidentStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == clean,
      orElse: () {
        if (clean == 'new') return IncidentStatus.newIncident;
        if (clean == 'in_progress' || clean == 'in-progress') {
          return IncidentStatus.inProgress;
        }
        return IncidentStatus.newIncident;
      },
    );
  }

  /// Returns the strictly expected next status in the normal operational flow
  IncidentStatus? get nextStatus => switch (this) {
        IncidentStatus.newIncident => IncidentStatus.assigned,
        IncidentStatus.assigned => IncidentStatus.inProgress,
        IncidentStatus.inProgress => IncidentStatus.resolved,
        IncidentStatus.resolved => IncidentStatus.closed,
        IncidentStatus.closed => null,
      };

  bool get isTerminal => this == IncidentStatus.closed;
}

