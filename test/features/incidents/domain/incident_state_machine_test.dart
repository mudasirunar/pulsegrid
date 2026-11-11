import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/errors/exceptions.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/logic/incident_state_machine.dart';

void main() {
  const coordinator = UserEntity(
    id: 'user-coord-01',
    email: 'coordinator@pulsegrid.org',
    displayName: 'Incident Commander Sarah',
    role: UserRole.coordinator,
  );

  const responder = UserEntity(
    id: 'user-resp-01',
    email: 'responder@pulsegrid.org',
    displayName: 'Field Medic Marcus',
    role: UserRole.responder,
  );

  const viewer = UserEntity(
    id: 'user-view-01',
    email: 'viewer@pulsegrid.org',
    displayName: 'Auditor Evans',
    role: UserRole.viewer,
  );

  late IncidentEntity baseIncident;
  final initialTime = DateTime(2026, 11, 11, 10, 0);

  setUp(() {
    baseIncident = IncidentEntity(
      id: 'inc-test-001',
      title: 'Chemical Spill - Sector 4',
      category: 'Hazmat',
      severity: IncidentSeverity.critical,
      description: 'Containment vessel breached.',
      status: IncidentStatus.newIncident,
      version: 1,
      createdBy: coordinator.id,
      createdAt: initialTime,
      updatedAt: initialTime,
    );
  });

  group('IncidentStateMachine — Sequential Happy Path Flow', () {
    test('Strict sequential progression: New -> Assigned -> In Progress -> Resolved -> Closed', () {
      final t1 = DateTime(2026, 11, 11, 10, 15);
      final t2 = DateTime(2026, 11, 11, 10, 30);
      final t3 = DateTime(2026, 11, 11, 11, 0);
      final t4 = DateTime(2026, 11, 11, 12, 0);

      // Step 1: New -> Assigned (by Coordinator)
      final step1 = IncidentStateMachine.transition(
        incident: baseIncident,
        targetStatus: IncidentStatus.assigned,
        actor: coordinator,
        timestamp: t1,
      );

      expect(step1.updatedIncident.status, IncidentStatus.assigned);
      expect(step1.updatedIncident.version, 2);
      expect(step1.updatedIncident.updatedAt, t1);
      expect(step1.activityEvent.eventType, 'STATUS_CHANGE');
      expect(step1.activityEvent.oldValue, 'New');
      expect(step1.activityEvent.newValue, 'Assigned');
      expect(step1.activityEvent.actorId, coordinator.id);

      // Step 2: Assigned -> In Progress (by Responder)
      final step2 = IncidentStateMachine.transition(
        incident: step1.updatedIncident,
        targetStatus: IncidentStatus.inProgress,
        actor: responder,
        timestamp: t2,
      );

      expect(step2.updatedIncident.status, IncidentStatus.inProgress);
      expect(step2.updatedIncident.version, 3);
      expect(step2.updatedIncident.updatedAt, t2);
      expect(step2.activityEvent.oldValue, 'Assigned');
      expect(step2.activityEvent.newValue, 'In Progress');
      expect(step2.activityEvent.actorId, responder.id);

      // Step 3: In Progress -> Resolved (by Responder)
      final step3 = IncidentStateMachine.transition(
        incident: step2.updatedIncident,
        targetStatus: IncidentStatus.resolved,
        actor: responder,
        timestamp: t3,
      );

      expect(step3.updatedIncident.status, IncidentStatus.resolved);
      expect(step3.updatedIncident.version, 4);
      expect(step3.updatedIncident.updatedAt, t3);
      expect(step3.activityEvent.oldValue, 'In Progress');
      expect(step3.activityEvent.newValue, 'Resolved');

      // Step 4: Resolved -> Closed (by Coordinator)
      final step4 = IncidentStateMachine.transition(
        incident: step3.updatedIncident,
        targetStatus: IncidentStatus.closed,
        actor: coordinator,
        timestamp: t4,
      );

      expect(step4.updatedIncident.status, IncidentStatus.closed);
      expect(step4.updatedIncident.version, 5);
      expect(step4.updatedIncident.updatedAt, t4);
      expect(step4.activityEvent.oldValue, 'Resolved');
      expect(step4.activityEvent.newValue, 'Closed');
      expect(step4.activityEvent.actorId, coordinator.id);
    });
  });

  group('IncidentStateMachine — Illegal Jump Protection', () {
    test('Cannot jump from New directly to In Progress', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.inProgress,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Cannot jump from New directly to Resolved', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.resolved,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Cannot jump from New directly to Closed', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.closed,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Cannot jump from Assigned directly to Closed', () {
      final assigned = baseIncident.copyWith(status: IncidentStatus.assigned);
      expect(
        () => IncidentStateMachine.transition(
          incident: assigned,
          targetStatus: IncidentStatus.closed,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Cannot jump from In Progress directly to Closed', () {
      final inProgress = baseIncident.copyWith(status: IncidentStatus.inProgress);
      expect(
        () => IncidentStateMachine.transition(
          incident: inProgress,
          targetStatus: IncidentStatus.closed,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Redundant transition to same status throws InvalidStateTransitionException', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.newIncident,
          actor: coordinator,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });

  group('IncidentStateMachine — Role Permission Enforcement', () {
    test('Responder CANNOT Close an incident (throws PermissionDeniedException)', () {
      final resolved = baseIncident.copyWith(status: IncidentStatus.resolved);
      expect(
        () => IncidentStateMachine.transition(
          incident: resolved,
          targetStatus: IncidentStatus.closed,
          actor: responder,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('Responder CANNOT Assign an incident (throws PermissionDeniedException)', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.assigned,
          actor: responder,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('Viewer CANNOT execute any lifecycle transition (throws PermissionDeniedException)', () {
      expect(
        () => IncidentStateMachine.transition(
          incident: baseIncident,
          targetStatus: IncidentStatus.assigned,
          actor: viewer,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      final inProgress = baseIncident.copyWith(status: IncidentStatus.inProgress);
      expect(
        () => IncidentStateMachine.transition(
          incident: inProgress,
          targetStatus: IncidentStatus.resolved,
          actor: viewer,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('IncidentStateMachine — Reopening Capability', () {
    test('Coordinator CAN reopen a Resolved incident back to In Progress', () {
      final resolved = baseIncident.copyWith(status: IncidentStatus.resolved, version: 4);
      final result = IncidentStateMachine.transition(
        incident: resolved,
        targetStatus: IncidentStatus.inProgress,
        actor: coordinator,
      );

      expect(result.updatedIncident.status, IncidentStatus.inProgress);
      expect(result.updatedIncident.version, 5);
      expect(result.activityEvent.oldValue, 'Resolved');
      expect(result.activityEvent.newValue, 'In Progress');
    });

    test('Coordinator CAN reopen a Closed incident back to In Progress', () {
      final closed = baseIncident.copyWith(status: IncidentStatus.closed, version: 5);
      final result = IncidentStateMachine.transition(
        incident: closed,
        targetStatus: IncidentStatus.inProgress,
        actor: coordinator,
      );

      expect(result.updatedIncident.status, IncidentStatus.inProgress);
      expect(result.updatedIncident.version, 6);
      expect(result.activityEvent.oldValue, 'Closed');
      expect(result.activityEvent.newValue, 'In Progress');
    });

    test('Responder CANNOT reopen a Closed or Resolved incident', () {
      final resolved = baseIncident.copyWith(status: IncidentStatus.resolved);
      expect(
        () => IncidentStateMachine.transition(
          incident: resolved,
          targetStatus: IncidentStatus.inProgress,
          actor: responder,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });

  group('IncidentStateMachine — canTransition Helper Queries', () {
    test('Evaluates allowed and forbidden transitions accurately', () {
      // Coordinator
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.newIncident, target: IncidentStatus.assigned, role: UserRole.coordinator), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.assigned, target: IncidentStatus.inProgress, role: UserRole.coordinator), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.inProgress, target: IncidentStatus.resolved, role: UserRole.coordinator), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.resolved, target: IncidentStatus.closed, role: UserRole.coordinator), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.newIncident, target: IncidentStatus.closed, role: UserRole.coordinator), isFalse);

      // Responder
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.newIncident, target: IncidentStatus.assigned, role: UserRole.responder), isFalse);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.assigned, target: IncidentStatus.inProgress, role: UserRole.responder), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.inProgress, target: IncidentStatus.resolved, role: UserRole.responder), isTrue);
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.resolved, target: IncidentStatus.closed, role: UserRole.responder), isFalse);

      // Viewer
      expect(IncidentStateMachine.canTransition(current: IncidentStatus.assigned, target: IncidentStatus.inProgress, role: UserRole.viewer), isFalse);
    });
  });
}

