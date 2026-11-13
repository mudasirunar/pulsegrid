import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/profile/domain/entities/profile_stats.dart';

void main() {
  final now = DateTime(2026, 11, 13, 12, 0);

  IncidentEntity makeIncident({
    required String id,
    required String createdBy,
    required IncidentStatus status,
  }) {
    return IncidentEntity(
      id: id,
      title: 'Incident $id',
      category: 'Fire',
      severity: IncidentSeverity.high,
      description: 'Desc',
      status: status,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('computes Coordinator Reported, Assigned Out, and Closed counts', () {
    final incidents = [
      makeIncident(id: '1', createdBy: 'coord-1', status: IncidentStatus.newIncident),
      makeIncident(id: '2', createdBy: 'coord-1', status: IncidentStatus.inProgress),
      makeIncident(id: '3', createdBy: 'coord-2', status: IncidentStatus.closed),
    ];
    final assignees = {
      '1': 'resp-1',
      '3': 'resp-2',
      'deleted-id': 'resp-1', // ignored since not in incidents
    };

    final stats = ProfileStats.compute(
      role: UserRole.coordinator,
      currentUserId: 'coord-1',
      incidents: incidents,
      incidentAssignees: assignees,
    );

    expect(stats.primaryCount, 2); // Reported
    expect(stats.secondaryCount, 2); // Assigned Out
    expect(stats.tertiaryCount, 1); // Closed
  });

  test('computes Responder Assigned, In Progress, and Resolved counts', () {
    final incidents = [
      makeIncident(id: '1', createdBy: 'coord-1', status: IncidentStatus.newIncident),
      makeIncident(id: '2', createdBy: 'coord-1', status: IncidentStatus.inProgress),
      makeIncident(id: '3', createdBy: 'coord-1', status: IncidentStatus.resolved),
      makeIncident(id: '4', createdBy: 'coord-1', status: IncidentStatus.closed),
      makeIncident(id: '5', createdBy: 'coord-1', status: IncidentStatus.inProgress),
    ];
    final assignees = {
      '1': 'resp-1',
      '2': 'resp-1',
      '3': 'resp-1',
      '4': 'resp-1',
      '5': 'resp-2', // different responder
    };

    final stats = ProfileStats.compute(
      role: UserRole.responder,
      currentUserId: 'resp-1',
      incidents: incidents,
      incidentAssignees: assignees,
    );

    expect(stats.primaryCount, 4); // Assigned
    expect(stats.secondaryCount, 1); // In Progress
    expect(stats.tertiaryCount, 2); // Resolved + Closed
  });

  test('Viewer always computes zero stats and serializes cleanly', () {
    const original = ProfileStats(
      primaryCount: 5,
      secondaryCount: 3,
      tertiaryCount: 2,
    );
    expect(ProfileStats.fromMap(original.toMap()), original);

    final viewerStats = ProfileStats.compute(
      role: UserRole.viewer,
      currentUserId: 'viewer-1',
      incidents: const [],
      incidentAssignees: const {},
    );
    expect(viewerStats, const ProfileStats());
  });
}

