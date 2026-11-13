import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/models/assignment_model.dart';
import '../entities/incident_entity.dart';

/// Role-based access control helper for Incident Edit, Delete, Status, and Resource operations.
///
/// Rules (Strict Assignment Handoff):
/// - [UserRole.viewer]: Read-only, never permitted.
/// - [UserRole.coordinator]: Permitted on any incident (including Responder-created).
/// - [UserRole.responder]:
///   - Before assignment (`assignment == null`): Only the creator can edit/delete.
///   - After assignment (`assignment != null`): Strictly depends on
///     `assignment.responderId == user.id` (creator loses access if reassigned
///     to another responder).
class IncidentPermissions {
  const IncidentPermissions._();

  static bool isCreator({
    required IncidentEntity incident,
    required UserEntity user,
  }) {
    return incident.createdBy == user.id ||
        (user.displayName.trim().isNotEmpty &&
            incident.createdBy == user.displayName.trim()) ||
        (user.email.trim().isNotEmpty &&
            incident.createdBy == user.email.trim());
  }

  static bool canEditOrDelete({
    required IncidentEntity incident,
    required UserEntity user,
    AssignmentModel? assignment,
  }) {
    if (user.role == UserRole.viewer) {
      return false;
    }

    if (user.role == UserRole.coordinator) {
      return true;
    }

    // Strict Assignment Handoff:
    // Once assigned, ownership belongs strictly to the assigned responder.
    if (assignment != null) {
      return assignment.responderId == user.id;
    }

    // Before assignment, only the creator responder can edit/delete.
    return isCreator(incident: incident, user: user);
  }

  /// Whether [user] can advance status or log resources on [incident].
  static bool canActOnIncident({
    required IncidentEntity incident,
    required UserEntity user,
    AssignmentModel? assignment,
  }) {
    if (user.role == UserRole.viewer) {
      return false;
    }

    if (user.role == UserRole.coordinator) {
      return true;
    }

    if (assignment != null) {
      return assignment.responderId == user.id;
    }

    // Before assignment, Responders cannot advance status or log resources
    // (only Coordinators can assign or log resources before assignment).
    return false;
  }
}
