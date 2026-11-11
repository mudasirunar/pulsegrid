import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/incident_status.dart';

class IncidentLifecycleStepper extends StatelessWidget {
  final IncidentStatus currentStatus;

  const IncidentLifecycleStepper({
    super.key,
    required this.currentStatus,
  });

  Color _statusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.newIncident:
        return AppColors.statusNew;
      case IncidentStatus.assigned:
        return AppColors.statusAssigned;
      case IncidentStatus.inProgress:
        return AppColors.statusInProgress;
      case IncidentStatus.resolved:
        return AppColors.statusResolved;
      case IncidentStatus.closed:
        return AppColors.statusClosed;
    }
  }

  @override
  Widget build(BuildContext context) {
    const statuses = [
      IncidentStatus.newIncident,
      IncidentStatus.assigned,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.closed,
    ];
    final currentIndex = statuses.indexOf(currentStatus);

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted ? AppColors.primaryLight : Colors.grey.withValues(alpha: 0.3),
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final status = statuses[stepIndex];
        final isActive = stepIndex == currentIndex;
        final isPassed = stepIndex < currentIndex;

        return Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isActive
                  ? _statusColor(status)
                  : isPassed
                      ? AppColors.primaryLight
                      : Colors.grey.withValues(alpha: 0.3),
              child: isPassed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              status.displayName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _statusColor(status) : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

