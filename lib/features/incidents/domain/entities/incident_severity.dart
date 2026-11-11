/// Validated Incident Severity levels
enum IncidentSeverity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  final String value;
  const IncidentSeverity(this.value);

  static IncidentSeverity fromString(String val) {
    final clean = val.trim().toLowerCase();
    return IncidentSeverity.values.firstWhere(
      (s) => s.value.toLowerCase() == clean,
      orElse: () => IncidentSeverity.medium,
    );
  }

  /// Numerical weight for priority sorting (Critical = 4, High = 3, Medium = 2, Low = 1)
  int get priorityWeight => switch (this) {
        IncidentSeverity.critical => 4,
        IncidentSeverity.high => 3,
        IncidentSeverity.medium => 2,
        IncidentSeverity.low => 1,
      };
}

