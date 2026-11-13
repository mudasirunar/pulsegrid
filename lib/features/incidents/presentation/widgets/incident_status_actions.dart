import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/incident_status.dart';

class IncidentStatusActions extends StatelessWidget {
  final IncidentStatus status;
  final UserEntity currentUser;
  final bool isOperating;
  final ValueChanged<IncidentStatus> onTransition;

  const IncidentStatusActions({
    super.key,
    required this.status,
    required this.currentUser,
    required this.isOperating,
    required this.onTransition,
  });

  @override
  Widget build(BuildContext context) {
    final isReadOnly = currentUser.role.isReadOnly;
    final isCoordinator = currentUser.role == UserRole.coordinator;

    if (isReadOnly) {
      return const SizedBox.shrink();
    }

    // 1. Standard forward advancement statuses (New -> Assigned -> In Progress -> Resolved)
    final nextStatus = _nextAdvancementStatus;
    if (nextStatus != null) {
      if (nextStatus == IncidentStatus.assigned && !isCoordinator) {
        return const SizedBox.shrink();
      }
      return AppButton(
        text: 'Advance Status',
        borderRadius: 24.0,
        height: 50.0,
        isLoading: isOperating,
        isDisabled: isOperating,
        onPressed: () => onTransition(nextStatus),
      );
    }

    // 2. Terminal state: Resolved (Awaiting coordinator close or reopen)
    if (status == IncidentStatus.resolved) {
      if (isCoordinator) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              text: 'Close Incident',
              variant: AppButtonVariant.destructive,
              borderRadius: 24.0,
              height: 50.0,
              isLoading: isOperating,
              isDisabled: isOperating,
              onPressed: () => onTransition(IncidentStatus.closed),
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'Reopen Incident',
              variant: AppButtonVariant.outlined,
              borderRadius: 24.0,
              height: 50.0,
              isLoading: isOperating,
              isDisabled: isOperating,
              onPressed: () => onTransition(IncidentStatus.inProgress),
            ),
          ],
        );
      } else {
        return const SizedBox.shrink();
      }
    }

    // 3. Terminal state: Closed (Coordinator-only reopen)
    if (status == IncidentStatus.closed) {
      if (isCoordinator) {
        return AppButton(
          text: 'Reopen Incident',
          variant: AppButtonVariant.outlined,
          borderRadius: 24.0,
          height: 50.0,
          isLoading: isOperating,
          isDisabled: isOperating,
          onPressed: () => onTransition(IncidentStatus.inProgress),
        );
      } else {
        return const SizedBox.shrink();
      }
    }

    return const SizedBox.shrink();
  }

  IncidentStatus? get _nextAdvancementStatus => switch (status) {
    IncidentStatus.newIncident => IncidentStatus.assigned,
    IncidentStatus.assigned => IncidentStatus.inProgress,
    IncidentStatus.inProgress => IncidentStatus.resolved,
    _ => null,
  };
}
