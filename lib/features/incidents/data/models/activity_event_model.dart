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
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        try {
          final dynamic dyn = val;
          return dyn.toDate() as DateTime;
        } catch (_) {}
        try {
          return DateTime.parse(val.toString());
        } catch (_) {}
      }
      return DateTime.now();
    }

    return ActivityEventModel(
      id: (map[DatabaseConstants.colId] ?? '').toString(),
      incidentId: (map[DatabaseConstants.colIncidentId] ?? '').toString(),
      actorId: (map[DatabaseConstants.colActorId] ?? '').toString(),
      eventType: (map[DatabaseConstants.colEventType] ?? '').toString(),
      oldValue: map[DatabaseConstants.colOldValue]?.toString(),
      newValue: map[DatabaseConstants.colNewValue]?.toString(),
      timestamp: parseDate(map[DatabaseConstants.colTimestamp]),
    );
  }

  @override
  List<Object?> get props => [id, incidentId, actorId, eventType, oldValue, newValue, timestamp];
}

