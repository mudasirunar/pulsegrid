import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../sync/domain/entities/sync_operation_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';

class IncidentCard extends StatelessWidget {
  final IncidentEntity incident;
  final String? assignedToName;
  final SyncStatus? syncStatus;
  final VoidCallback? onTap;

  const IncidentCard({
    super.key,
    required this.incident,
    this.assignedToName,
    this.syncStatus,
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
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final description = incident.description.trim();
    final manualLocation = incident.manualLocationNotes?.trim() ?? '';
    final hasGps = incident.latitude != null && incident.longitude != null;
    final hasLocation = manualLocation.isNotEmpty || hasGps;
    final assignee = assignedToName?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Badges Row: Category + Severity on left, Status on right
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: AppBadge(
                            text: incident.category.toUpperCase(),
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppBadge(
                          text: incident.severity.displayName.toUpperCase(),
                          color: _severityColor(incident.severity),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBadge(
                    text: incident.status.displayName.toUpperCase(),
                    color: _statusColor(incident.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Title
              Text(
                incident.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: primaryText,
                ),
              ),

              // 3. Description (only if non-empty)
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: secondaryText,
                  ),
                ),
              ],

              // 4. Location (manual notes priority, else GPS coordinates)
              if (hasLocation) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      manualLocation.isNotEmpty
                          ? Icons.location_on_outlined
                          : Icons.gps_fixed_rounded,
                      size: 15,
                      color: secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        manualLocation.isNotEmpty
                            ? manualLocation
                            : '${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 5. Bottom Row: Always-visible Assigned To on left, Sync + 12hr Time on right
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            assignee.isNotEmpty
                                ? 'Assigned to $assignee'
                                : 'Not assigned',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (syncStatus != null && syncStatus != SyncStatus.synced) ...[
                    _SyncIndicator(syncStatus: syncStatus!),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    DateTimeFormatter.time12Hour(incident.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryText,
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

class _SyncIndicator extends StatelessWidget {
  final SyncStatus syncStatus;

  const _SyncIndicator({required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (syncStatus) {
      SyncStatus.pending => (AppColors.syncPending, 'Pending'),
      SyncStatus.syncing => (AppColors.syncSyncing, 'Syncing'),
      SyncStatus.failed => (AppColors.syncFailed, 'Failed'),
      SyncStatus.conflict => (AppColors.syncFailed, 'Conflict'),
      SyncStatus.synced => (AppColors.syncSynced, 'Synced'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
