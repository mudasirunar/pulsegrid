import 'package:equatable/equatable.dart';
import '../../../../core/database/database_constants.dart';

class ActivityEventModel extends Equatable {
  final String id;
  final String incidentId;
  final String actorId;
  final String eventType;
  final String? oldValue;
  final String? newValue;
  final DateTime timestamp;

  const ActivityEventModel({
    required this.id,
    required this.incidentId,
    required this.actorId,
    required this.eventType,
    this.oldValue,
    this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colId: id,
      DatabaseConstants.colIncidentId: incidentId,
      DatabaseConstants.colActorId: actorId,
      DatabaseConstants.colEventType: eventType,
      DatabaseConstants.colOldValue: oldValue,
      DatabaseConstants.colNewValue: newValue,
      DatabaseConstants.colTimestamp: timestamp.toIso8601String(),
    };
  }

  factory ActivityEventModel.fromMap(Map<String, dynamic> map) {
    return ActivityEventModel(
      id: map[DatabaseConstants.colId] as String,
      incidentId: map[DatabaseConstants.colIncidentId] as String,
      actorId: map[DatabaseConstants.colActorId] as String,
      eventType: map[DatabaseConstants.colEventType] as String,
      oldValue: map[DatabaseConstants.colOldValue] as String?,
      newValue: map[DatabaseConstants.colNewValue] as String?,
      timestamp: DateTime.parse(map[DatabaseConstants.colTimestamp] as String),
    );
  }

  @override
  List<Object?> get props => [id, incidentId, actorId, eventType, oldValue, newValue, timestamp];
}

