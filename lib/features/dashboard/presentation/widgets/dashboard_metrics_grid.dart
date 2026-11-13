import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/entities/incident_severity.dart';
import '../../../incidents/domain/entities/incident_status.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_event.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import 'dashboard_filter_state.dart';

/// Flat 2x2 interactive dashboard metrics grid.
class DashboardMetricsGrid extends StatelessWidget {
  final List<IncidentEntity> incidents;
  final Map<String, String> incidentAssignees;
  final String currentUserId;
  final bool isReadOnly;
  final SyncState syncState;
  final DashboardFilterState filterState;
  final ValueChanged<DashboardFilterState> onFilterChanged;

  const DashboardMetricsGrid({
    super.key,
    required this.incidents,
    required this.incidentAssignees,
    required this.currentUserId,
    required this.isReadOnly,
    required this.syncState,
    required this.filterState,
    required this.onFilterChanged,
  });

  void _toggleStatus(DashboardStatusFilter target) {
    onFilterChanged(
      filterState.copyWith(
        statusFilter: filterState.statusFilter == target
            ? DashboardStatusFilter.all
            : target,
      ),
    );
  }

  void _toggleCritical() {
    onFilterChanged(
      filterState.severityFilter == IncidentSeverity.critical
          ? filterState.copyWith(clearSeverity: true)
          : filterState.copyWith(severityFilter: IncidentSeverity.critical),
    );
  }

  void _toggleAssignedToMe() {
    onFilterChanged(
      filterState.copyWith(
        assignmentFilter:
            filterState.assignmentFilter == DashboardAssignmentFilter.assignedToMe
                ? DashboardAssignmentFilter.all
                : DashboardAssignmentFilter.assignedToMe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openCount =
        incidents.where((i) => i.status != IncidentStatus.closed).length;
    final criticalCount = incidents
        .where(
          (i) =>
              i.severity == IncidentSeverity.critical &&
              i.status != IncidentStatus.closed,
        )
        .length;

    if (isReadOnly) {
      final inProgressCount = incidents
          .where((i) => i.status == IncidentStatus.inProgress)
          .length;
      final resolvedCount =
          incidents.where((i) => i.status == IncidentStatus.resolved).length;

      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Open',
                  value: '$openCount',
                  isSelected:
                      filterState.statusFilter == DashboardStatusFilter.open,
                  onTap: () => _toggleStatus(DashboardStatusFilter.open),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Critical',
                  value: '$criticalCount',
                  accentDotColor:
                      criticalCount > 0 ? AppColors.severityCritical : null,
                  isSelected:
                      filterState.severityFilter == IncidentSeverity.critical,
                  onTap: _toggleCritical,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'In Progress',
                  value: '$inProgressCount',
                  isSelected: filterState.statusFilter ==
                      DashboardStatusFilter.inProgress,
                  onTap: () => _toggleStatus(DashboardStatusFilter.inProgress),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Resolved',
                  value: '$resolvedCount',
                  isSelected: filterState.statusFilter ==
                      DashboardStatusFilter.resolved,
                  onTap: () => _toggleStatus(DashboardStatusFilter.resolved),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final assignedToMeCount = incidents
        .where(
          (i) =>
              incidentAssignees[i.id] == currentUserId &&
              i.status != IncidentStatus.closed,
        )
        .length;
    final pendingTotal = syncState.pendingCount + syncState.failedCount;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Open',
                value: '$openCount',
                isSelected:
                    filterState.statusFilter == DashboardStatusFilter.open,
                onTap: () => _toggleStatus(DashboardStatusFilter.open),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Critical',
                value: '$criticalCount',
                accentDotColor:
                    criticalCount > 0 ? AppColors.severityCritical : null,
                isSelected:
                    filterState.severityFilter == IncidentSeverity.critical,
                onTap: _toggleCritical,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Assigned to Me',
                value: '$assignedToMeCount',
                isSelected: filterState.assignmentFilter ==
                    DashboardAssignmentFilter.assignedToMe,
                onTap: _toggleAssignedToMe,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label:
                    syncState.failedCount > 0 ? 'Sync Failed' : 'Pending Sync',
                value: '$pendingTotal',
                accentDotColor: syncState.failedCount > 0
                    ? AppColors.syncFailed
                    : (pendingTotal > 0 ? AppColors.syncPending : null),
                isSelected: false,
                onTap: () {
                  if (syncState.failedCount > 0) {
                    context.read<SyncBloc>().add(const RetryFailedSyncEvent());
                  } else {
                    context
                        .read<SyncBloc>()
                        .add(const TriggerSyncEvent(force: true));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentDotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    this.accentDotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final activeBorder = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBorder.withValues(alpha: isDark ? 0.12 : 0.08)
              : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBorder : borderColor,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (accentDotColor != null) ...[
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accentDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeBorder : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

