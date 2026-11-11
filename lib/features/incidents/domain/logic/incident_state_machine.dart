import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/models/activity_event_model.dart';
import '../entities/activity_event_entity.dart';
import '../entities/incident_entity.dart';
import '../entities/incident_status.dart';

/// Result bundle returned upon a successful lifecycle transition
class TransitionResult {
  final IncidentEntity updatedIncident;
  final ActivityEventModel activityEvent;

  const TransitionResult({
    required this.updatedIncident,
    required this.activityEvent,
  });
}

/// Pure Domain Service enforcing the strict, unidirectional Incident Lifecycle:
/// New -> Assigned -> In Progress -> Resolved -> Closed
///
/// Rules enforced:
/// 1. Strict sequential progression: No skipping stages.
/// 2. Role Guarding:
///    - Coordinator: Can execute any valid sequential transition and is the ONLY role
///      allowed to Close an incident (Resolved -> Closed) or Reopen an incident.
///    - Responder: Can progress Assigned -> In Progress, and In Progress -> Resolved.
///      CANNOT Close an incident.
///    - Viewer: Read-only. Strictly prohibited from initiating transitions.
/// 3. Audit trail: Every transition automatically generates an immutable ActivityEvent (STATUS_CHANGE).
/// 4. Optimistic concurrency: Bumps incident version by +1 on each transition.
class IncidentStateMachine {
  static const _uuid = Uuid();

  const IncidentStateMachine._();

  /// Evaluates whether a transition from [current] to [target] is permitted for [role]
  static bool canTransition({
    required IncidentStatus current,
    required IncidentStatus target,
    required UserRole role,
  }) {
    // 1. Viewer is strictly read-only
    if (role.isReadOnly) {
      return false;
    }

    // 2. Redundant transition to same status is invalid
    if (current == target) {
      return false;
    }

    // 3. Coordinator-only Closure rule
    if (target == IncidentStatus.closed && !role.canAssignAndClose) {
      return false;
    }

    // 4. Standard sequential progression
    if (current == IncidentStatus.newIncident && target == IncidentStatus.assigned) {
      return role.canAssignAndClose;
    }

    if (current == IncidentStatus.assigned && target == IncidentStatus.inProgress) {
      return role.canUpdateIncidents;
    }

    if (current == IncidentStatus.inProgress && target == IncidentStatus.resolved) {
      return role.canUpdateIncidents;
    }

    if (current == IncidentStatus.resolved && target == IncidentStatus.closed) {
      return role.canAssignAndClose;
    }

    // 5. Coordinator Reopen capability (Resolved/Closed -> In Progress)
    if ((current == IncidentStatus.resolved || current == IncidentStatus.closed) &&
        target == IncidentStatus.inProgress &&
        role == UserRole.coordinator) {
      return true;
    }

    // All other transitions are illegal jumps
    return false;
  }

  /// Executes a validated state transition on [incident].
  ///
  /// Throws [PermissionDeniedException] if [actor.role] lacks authority.
  /// Throws [InvalidStateTransitionException] if [targetStatus] is an illegal leap.
  static TransitionResult transition({
    required IncidentEntity incident,
    required IncidentStatus targetStatus,
    required UserEntity actor,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final currentStatus = incident.status;

    // Guard 1: Viewer Role Check
    if (actor.role.isReadOnly) {
      throw const PermissionDeniedException(
        'Viewers have read-only access and cannot alter incident lifecycle states.',
      );
    }

    // Guard 2: Redundant Transition Check
    if (currentStatus == targetStatus) {
      throw InvalidStateTransitionException(
        'Incident "${incident.title}" is already in "${currentStatus.value}" status.',
      );
    }

    // Guard 3: Closure Authority Check (Only Coordinator can Close)
    if (targetStatus == IncidentStatus.closed && !actor.role.canAssignAndClose) {
      throw PermissionDeniedException(
        'Only Coordinators have permission to Close incidents. "${actor.displayName}" (${actor.role.displayName}) is not authorized.',
      );
    }

    // Guard 4: Sequential State Progression Check
    final isSequential = (currentStatus == IncidentStatus.newIncident && targetStatus == IncidentStatus.assigned) ||
        (currentStatus == IncidentStatus.assigned && targetStatus == IncidentStatus.inProgress) ||
        (currentStatus == IncidentStatus.inProgress && targetStatus == IncidentStatus.resolved) ||
        (currentStatus == IncidentStatus.resolved && targetStatus == IncidentStatus.closed);

    final isReopen = (currentStatus == IncidentStatus.resolved || currentStatus == IncidentStatus.closed) &&
        targetStatus == IncidentStatus.inProgress &&
        actor.role == UserRole.coordinator;

    if (!isSequential && !isReopen) {
      throw InvalidStateTransitionException(
        'Invalid status transition: Cannot transition incident from "${currentStatus.value}" to "${targetStatus.value}". Valid progression is: New -> Assigned -> In Progress -> Resolved -> Closed.',
      );
    }

    // Guard 5: Assignment Role Check (Only Coordinator can assign)
    if (currentStatus == IncidentStatus.newIncident &&
        targetStatus == IncidentStatus.assigned &&
        !actor.role.canAssignAndClose) {
      throw PermissionDeniedException(
        'Only Coordinators can assign incidents to responders.',
      );
    }

    // Build updated incident with bumped version and refreshed timestamp
    final updatedIncident = incident.copyWith(
      status: targetStatus,
      version: incident.version + 1,
      updatedAt: now,
    );

    // Build immutable audit ActivityEvent
    final activityEvent = ActivityEventModel(
      id: _uuid.v4(),
      incidentId: incident.id,
      actorId: actor.id,
      eventType: ActivityEventType.statusChange.value,
      oldValue: currentStatus.value,
      newValue: targetStatus.value,
      timestamp: now,
    );

    return TransitionResult(
      updatedIncident: updatedIncident,
      activityEvent: activityEvent,
    );
  }
}

