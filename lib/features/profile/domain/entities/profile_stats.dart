import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user_role.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/entities/incident_status.dart';

/// Role-aware operational stats coupled to a user profile (synced locally + remotely).
class ProfileStats extends Equatable {
  final int primaryCount; // Coordinator: Reported | Responder: Assigned
  final int secondaryCount; // Coordinator: Assigned Out | Responder: In Progress
  final int tertiaryCount; // Coordinator: Closed | Responder: Resolved

  const ProfileStats({
    this.primaryCount = 0,
    this.secondaryCount = 0,
    this.tertiaryCount = 0,
  });

  factory ProfileStats.compute({
    required UserRole role,
    required String currentUserId,
    required List<IncidentEntity> incidents,
    required Map<String, String> incidentAssignees,
  }) {
    if (role == UserRole.viewer) {
      return const ProfileStats();
    }

    final validIncidentIds = {for (final i in incidents) i.id};

    if (role == UserRole.coordinator) {
      final reported =
          incidents.where((i) => i.createdBy == currentUserId).length;
      final assignedOut = incidentAssignees.keys
          .where((id) => validIncidentIds.contains(id))
          .length;
      final closed =
          incidents.where((i) => i.status == IncidentStatus.closed).length;
      return ProfileStats(
        primaryCount: reported,
        secondaryCount: assignedOut,
        tertiaryCount: closed,
      );
    }

    // Responder
    final assignedIncidents = incidents
        .where((i) => incidentAssignees[i.id] == currentUserId)
        .toList();
    final inProgress = assignedIncidents
        .where((i) => i.status == IncidentStatus.inProgress)
        .length;
    final resolved = assignedIncidents
        .where(
          (i) =>
              i.status == IncidentStatus.resolved ||
              i.status == IncidentStatus.closed,
        )
        .length;

    return ProfileStats(
      primaryCount: assignedIncidents.length,
      secondaryCount: inProgress,
      tertiaryCount: resolved,
    );
  }

  Map<String, dynamic> toMap() => {
        'primaryCount': primaryCount,
        'secondaryCount': secondaryCount,
        'tertiaryCount': tertiaryCount,
      };

  factory ProfileStats.fromMap(Map<String, dynamic> map) {
    return ProfileStats(
      primaryCount: (map['primaryCount'] as num?)?.toInt() ?? 0,
      secondaryCount: (map['secondaryCount'] as num?)?.toInt() ?? 0,
      tertiaryCount: (map['tertiaryCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [primaryCount, secondaryCount, tertiaryCount];
}

