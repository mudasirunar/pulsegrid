import 'package:equatable/equatable.dart';

import '../../data/models/activity_event_model.dart';

enum ActivityEventType {
  statusChange('STATUS_CHANGE'),
  assignmentChange('ASSIGNMENT_CHANGE'),
  resourceLogged('RESOURCE_LOGGED'),
  conflictResolved('CONFLICT_RESOLVED'),
  incidentCreated('INCIDENT_CREATED'),
  incidentEdited('INCIDENT_EDITED');

  final String value;
  const ActivityEventType(this.value);

  static ActivityEventType fromString(String val) {
    final clean = val.trim().toUpperCase();
    return ActivityEventType.values.firstWhere(
      (e) => e.value == clean,
      orElse: () => ActivityEventType.statusChange,
    );
  }
}

/// Pure Domain Entity representing an audit log entry on the incident activity timeline.
/// Minimum fields enforced by Section 4 (Important Data Rules):
/// [id, incidentId, actorId, eventType, oldValue, newValue, timestamp]
class ActivityEventEntity extends Equatable {
  final String id;
  final String incidentId;
  final String actorId;
  final ActivityEventType eventType;
  final String? oldValue;
  final String? newValue;
  final DateTime timestamp;

  const ActivityEventEntity({
    required this.id,
    required this.incidentId,
    required this.actorId,
    required this.eventType,
    this.oldValue,
    this.newValue,
    required this.timestamp,
  });

  ActivityEventModel toModel() {
    return ActivityEventModel(
      id: id,
      incidentId: incidentId,
      actorId: actorId,
      eventType: eventType.value,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: timestamp,
    );
  }

  factory ActivityEventEntity.fromModel(ActivityEventModel model) {
    return ActivityEventEntity(
      id: model.id,
      incidentId: model.incidentId,
      actorId: model.actorId,
      eventType: ActivityEventType.fromString(model.eventType),
      oldValue: model.oldValue,
      newValue: model.newValue,
      timestamp: model.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        id,
        incidentId,
        actorId,
        eventType,
        oldValue,
        newValue,
        timestamp,
      ];
}

