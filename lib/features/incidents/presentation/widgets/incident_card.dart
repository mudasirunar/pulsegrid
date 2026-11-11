import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';

class IncidentCard extends StatelessWidget {
  final IncidentEntity incident;
  final VoidCallback? onTap;

  const IncidentCard({
    super.key,
    required this.incident,
    this.onTap,
  });

  Color _severityColor(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.critical:
        return AppColors.severityCritical;
      case IncidentSeverity.high:
        return AppColors.severityHigh;
      case IncidentSeverity.medium:
        return AppColors.severityMedium;
      case IncidentSeverity.low:
        return AppColors.severityLow;
    }
  }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppBadge(
                    text: incident.category.toUpperCase(),
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  const SizedBox(width: 8),
                  AppBadge(
                    text: incident.severity.displayName.toUpperCase(),
                    color: _severityColor(incident.severity),
                  ),
                  const Spacer(),
                  AppBadge(
                    text: incident.status.displayName.toUpperCase(),
                    color: _statusColor(incident.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                incident.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                incident.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (incident.latitude != null && incident.longitude != null) ...[
                    const Icon(Icons.location_on, size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 3),
                    const Text('GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                  ] else if (incident.manualLocationNotes != null && incident.manualLocationNotes!.isNotEmpty) ...[
                    const Icon(Icons.notes, size: 14, color: AppColors.severityMedium),
                    const SizedBox(width: 3),
                    const Text('Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                  ],
                  if (incident.photoPaths.isNotEmpty) ...[
                    const Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 3),
                    Text(
                      incident.photoPaths.length > 1 ? '${incident.photoPaths.length} Photos' : 'Photo',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                  ],
                  const Spacer(),
                  Text(
                    '${incident.createdAt.hour.toString().padLeft(2, '0')}:${incident.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

