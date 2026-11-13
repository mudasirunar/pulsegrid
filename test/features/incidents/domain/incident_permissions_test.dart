import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/data/models/assignment_model.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/logic/incident_permissions.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 10, 0);

  const coordinator = UserEntity(
    id: 'coord-1',
    email: 'coord@pulsegrid.com',
    displayName: 'Sarah Chen',
    role: UserRole.coordinator,
  );

  const responder1 = UserEntity(
    id: 'resp-1',
    email: 'resp1@pulsegrid.com',
    displayName: 'Marcus Vance',
    role: UserRole.responder,
  );

  const responder2 = UserEntity(
    id: 'resp-2',
    email: 'resp2@pulsegrid.com',
    displayName: 'Ali Khan',
    role: UserRole.responder,
  );

  const viewer = UserEntity(
    id: 'view-1',
    email: 'viewer@pulsegrid.com',
    displayName: 'Auditor Evans',
    role: UserRole.viewer,
  );

  IncidentEntity makeIncident({
    String createdBy = 'Marcus Vance',
    IncidentStatus status = IncidentStatus.newIncident,
  }) {
    return IncidentEntity(
      id: 'inc-1',
      title: 'Transformer Fire',
      category: 'Fire',
      severity: IncidentSeverity.high,
      description: 'Substation fire',
      status: status,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('IncidentPermissions (Option B)', () {
    test('Coordinator can edit/delete any incident including Responder-created', () {
      final inc = makeIncident(createdBy: 'Marcus Vance');
      expect(
        IncidentPermissions.canEditOrDelete(incident: inc, user: coordinator),
        isTrue,
      );
    });

    test('Viewer cannot edit/delete any incident', () {
      final inc = makeIncident(createdBy: 'Auditor Evans');
      expect(
        IncidentPermissions.canEditOrDelete(incident: inc, user: viewer),
        isFalse,
      );
    });

    test('Responder can edit/delete own incident by displayName, email, or id', () {
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: makeIncident(createdBy: 'Marcus Vance'),
          user: responder1,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: makeIncident(createdBy: 'resp1@pulsegrid.com'),
          user: responder1,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: makeIncident(createdBy: 'resp-1'),
          user: responder1,
        ),
        isTrue,
      );
    });

    test('Responder CANNOT edit/delete another user incident even if status is Assigned without explicit AssignmentModel', () {
      final inc = makeIncident(
        createdBy: 'Sarah Chen',
        status: IncidentStatus.assigned,
      );
      expect(
        IncidentPermissions.canEditOrDelete(incident: inc, user: responder1),
        isFalse,
      );
    });

    test('Responder CAN edit/delete when explicit AssignmentModel targets them', () {
      final inc = makeIncident(
        createdBy: 'Sarah Chen',
        status: IncidentStatus.assigned,
      );
      final assignment = AssignmentModel(
        id: 'assign-1',
        incidentId: 'inc-1',
        responderId: 'resp-1',
        assignedBy: 'coord-1',
        assignedAt: now,
      );
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: inc,
          user: responder1,
          assignment: assignment,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: inc,
          user: responder2,
          assignment: assignment,
        ),
        isFalse,
      );
    });

    test('Strict Assignment Handoff: creator Responder loses edit/delete/act access once assigned to another Responder', () {
      final inc = makeIncident(
        createdBy: 'Marcus Vance',
        status: IncidentStatus.assigned,
      );
      final assignedToResp2 = AssignmentModel(
        id: 'assign-2',
        incidentId: 'inc-1',
        responderId: 'resp-2',
        assignedBy: 'coord-1',
        assignedAt: now,
      );

      // Creator (responder1) loses access
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: inc,
          user: responder1,
          assignment: assignedToResp2,
        ),
        isFalse,
      );
      expect(
        IncidentPermissions.canActOnIncident(
          incident: inc,
          user: responder1,
          assignment: assignedToResp2,
        ),
        isFalse,
      );

      // Assigned responder (responder2) gains full action & edit access
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: inc,
          user: responder2,
          assignment: assignedToResp2,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canActOnIncident(
          incident: inc,
          user: responder2,
          assignment: assignedToResp2,
        ),
        isTrue,
      );

      // Coordinator retains access regardless of assignment
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: inc,
          user: coordinator,
          assignment: assignedToResp2,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canActOnIncident(
          incident: inc,
          user: coordinator,
          assignment: assignedToResp2,
        ),
        isTrue,
      );

      // Viewer always read-only
      expect(
        IncidentPermissions.canActOnIncident(
          incident: inc,
          user: viewer,
          assignment: assignedToResp2,
        ),
        isFalse,
      );
    });

    test('Unassigned incident: Responder (even creator) cannot act/log/assign; only creator can edit/delete', () {
      final responderCreated = makeIncident(
        createdBy: 'Marcus Vance',
        status: IncidentStatus.newIncident,
      );
      final coordinatorCreated = makeIncident(
        createdBy: 'Sarah Chen',
        status: IncidentStatus.newIncident,
      );

      // Creator responder can edit/delete before assignment, but cannot act/log/assign
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: responderCreated,
          user: responder1,
        ),
        isTrue,
      );
      expect(
        IncidentPermissions.canActOnIncident(
          incident: responderCreated,
          user: responder1,
        ),
        isFalse,
      );

      // Non-creator responder has neither edit/delete nor act/log/assign
      expect(
        IncidentPermissions.canEditOrDelete(
          incident: coordinatorCreated,
          user: responder1,
        ),
        isFalse,
      );
      expect(
        IncidentPermissions.canActOnIncident(
          incident: coordinatorCreated,
          user: responder1,
        ),
        isFalse,
      );

      // Coordinator can always act/assign
      expect(
        IncidentPermissions.canActOnIncident(
          incident: coordinatorCreated,
          user: coordinator,
        ),
        isTrue,
      );
    });
  });
}

