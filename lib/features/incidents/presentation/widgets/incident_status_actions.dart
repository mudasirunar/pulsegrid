import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReadOnly = currentUser.role.isReadOnly;
    final isCoordinator = currentUser.role == UserRole.coordinator;

    if (isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewer Role: Status transitions and assignments are read-only.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    switch (status) {
      case IncidentStatus.newIncident:
        return AppButton(
          text: 'Advance Status: Mark as Assigned',
          leadingIcon: Icons.assignment_ind_outlined,
          isLoading: isOperating,
          isDisabled: isOperating,
          onPressed: () => onTransition(IncidentStatus.assigned),
        );

      case IncidentStatus.assigned:
        return AppButton(
          text: 'Advance Status: Start Incident Response',
          leadingIcon: Icons.play_arrow_outlined,
          isLoading: isOperating,
          isDisabled: isOperating,
          onPressed: () => onTransition(IncidentStatus.inProgress),
        );

      case IncidentStatus.inProgress:
        return AppButton(
          text: 'Advance Status: Mark Incident Resolved',
          leadingIcon: Icons.check_circle_outline,
          isLoading: isOperating,
          isDisabled: isOperating,
          onPressed: () => onTransition(IncidentStatus.resolved),
        );

      case IncidentStatus.resolved:
        if (isCoordinator) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                text: 'Coordinator Sign-off: Close Incident',
                leadingIcon: Icons.lock_outline,
                variant: AppButtonVariant.destructive,
                isLoading: isOperating,
                isDisabled: isOperating,
                onPressed: () => onTransition(IncidentStatus.closed),
              ),
              const SizedBox(height: 8),
              AppButton(
                text: 'Reopen Incident to In-Progress',
                leadingIcon: Icons.refresh_outlined,
                variant: AppButtonVariant.outlined,
                isLoading: isOperating,
                isDisabled: isOperating,
                onPressed: () => onTransition(IncidentStatus.inProgress),
              ),
            ],
          );
        } else {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.statusResolved.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.statusResolved.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top, size: 16, color: AppColors.statusResolved),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Incident is Resolved. Awaiting Coordinator approval to permanently Close.',
                    style: TextStyle(fontSize: 12, color: AppColors.statusResolved),
                  ),
                ),
              ],
            ),
          );
        }

      case IncidentStatus.closed:
        if (isCoordinator) {
          return AppButton(
            text: 'Coordinator Action: Reopen Incident',
            leadingIcon: Icons.replay_outlined,
            variant: AppButtonVariant.outlined,
            isLoading: isOperating,
            isDisabled: isOperating,
            onPressed: () => onTransition(IncidentStatus.inProgress),
          );
        } else {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.statusClosed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.statusClosed),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Incident is Closed. Only a Coordinator can reopen it.',
                    style: TextStyle(fontSize: 12, color: AppColors.statusClosed),
                  ),
                ),
              ],
            ),
          );
        }
    }
  }
}
