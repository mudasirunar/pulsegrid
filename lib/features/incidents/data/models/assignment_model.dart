import 'package:equatable/equatable.dart';
import '../../../../core/database/database_constants.dart';

class AssignmentModel extends Equatable {
  final String id;
  final String incidentId;
  final String responderId;
  final String assignedBy;
  final DateTime assignedAt;

  const AssignmentModel({
    required this.id,
    required this.incidentId,
    required this.responderId,
    required this.assignedBy,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colId: id,
      DatabaseConstants.colIncidentId: incidentId,
      DatabaseConstants.colResponderId: responderId,
      DatabaseConstants.colAssignedBy: assignedBy,
      DatabaseConstants.colAssignedAt: assignedAt.toIso8601String(),
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map[DatabaseConstants.colId] as String,
      incidentId: map[DatabaseConstants.colIncidentId] as String,
      responderId: map[DatabaseConstants.colResponderId] as String,
      assignedBy: map[DatabaseConstants.colAssignedBy] as String,
      assignedAt: DateTime.parse(map[DatabaseConstants.colAssignedAt] as String),
    );
  }

  @override
  List<Object?> get props => [id, incidentId, responderId, assignedBy, assignedAt];
}

