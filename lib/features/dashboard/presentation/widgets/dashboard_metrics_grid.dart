import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/entities/incident_severity.dart';
import '../../../incidents/domain/entities/incident_status.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_event.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import 'dashboard_filter_state.dart';

/// Flat 2x2 interactive dashboard metrics grid with real operational context.
class DashboardMetricsGrid extends StatelessWidget {
  final List<IncidentEntity> incidents;
  final Map<String, String> incidentAssignees;
  final String currentUserId;
  final UserRole userRole;
  final SyncState syncState;
  final DashboardFilterState filterState;
  final ValueChanged<DashboardFilterState> onFilterChanged;

  const DashboardMetricsGrid({
    super.key,
    required this.incidents,
    required this.incidentAssignees,
    required this.currentUserId,
    required this.userRole,
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

  void _toggleAssignmentFilter(DashboardAssignmentFilter target) {
    onFilterChanged(
      filterState.copyWith(
        assignmentFilter: filterState.assignmentFilter == target
            ? DashboardAssignmentFilter.all
            : target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openIncidents =
        incidents.where((i) => i.status != IncidentStatus.closed).toList();
    final openCount = openIncidents.length;
    final newCount = openIncidents
        .where((i) => i.status == IncidentStatus.newIncident)
        .length;
    final inProgressIncidents = openIncidents
        .where((i) => i.status == IncidentStatus.inProgress)
        .toList();
    final inProgressCount = inProgressIncidents.length;

    final criticalIncidents = openIncidents
        .where((i) => i.severity == IncidentSeverity.critical)
        .toList();
    final criticalCount = criticalIncidents.length;
    final criticalUnassignedCount = criticalIncidents
        .where((i) => (incidentAssignees[i.id] ?? '').isEmpty)
        .length;

    final openTile = _MetricTile(
      label: 'Open',
      value: '$openCount',
      hintText: incidents.isNotEmpty ? 'of ${incidents.length}' : null,
      subtitle: openCount == 0
          ? 'No open incidents'
          : '$newCount New · $inProgressCount In Progress',
      isSelected: filterState.statusFilter == DashboardStatusFilter.open,
      onTap: () => _toggleStatus(DashboardStatusFilter.open),
    );

    final criticalTile = _MetricTile(
      label: 'Critical',
      value: '$criticalCount',
      accentDotColor: criticalCount > 0 ? AppColors.severityCritical : null,
      subtitle: criticalCount == 0
          ? 'None active'
          : (criticalUnassignedCount > 0
              ? '$criticalUnassignedCount Unassigned'
              : 'All assigned'),
      isSelected: filterState.severityFilter == IncidentSeverity.critical,
      onTap: _toggleCritical,
    );

    if (userRole.isReadOnly) {
      final inProgressCritical = inProgressIncidents
          .where((i) => i.severity == IncidentSeverity.critical)
          .length;
      final resolvedCount =
          incidents.where((i) => i.status == IncidentStatus.resolved).length;
      final closedCount =
          incidents.where((i) => i.status == IncidentStatus.closed).length;

      return Column(
        children: [
          Row(
            children: [
              Expanded(child: openTile),
              const SizedBox(width: 10),
              Expanded(child: criticalTile),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'In Progress',
                  value: '$inProgressCount',
                  hintText: openCount > 0 ? 'of $openCount open' : null,
                  subtitle: inProgressCount == 0
                      ? 'None active'
                      : (inProgressCritical > 0
                          ? '$inProgressCritical Critical active'
                          : 'Active response'),
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
                  hintText:
                      incidents.isNotEmpty ? 'of ${incidents.length}' : null,
                  subtitle: closedCount > 0
                      ? '$closedCount Closed'
                      : (resolvedCount > 0
                          ? 'Awaiting close'
                          : 'None resolved yet'),
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

    final unassignedIncidents = openIncidents
        .where((i) => (incidentAssignees[i.id] ?? '').isEmpty)
        .toList();
    final unassignedCritical = unassignedIncidents
        .where((i) => i.severity == IncidentSeverity.critical)
        .length;

    final myOpenIncidents = openIncidents
        .where((i) => incidentAssignees[i.id] == currentUserId)
        .toList();
    final myInProgress = myOpenIncidents
        .where((i) => i.status == IncidentStatus.inProgress)
        .length;
    final myCritical = myOpenIncidents
        .where((i) => i.severity == IncidentSeverity.critical)
        .length;

    final Widget thirdTile;
    if (userRole == UserRole.coordinator) {
      final String unassignedSubtitle;
      if (openCount == 0) {
        unassignedSubtitle = 'No open incidents';
      } else if (unassignedIncidents.isEmpty) {
        unassignedSubtitle = 'All open assigned';
      } else if (unassignedCritical > 0) {
        unassignedSubtitle = '$unassignedCritical Critical · Needs responder';
      } else {
        unassignedSubtitle = 'Needs responder';
      }

      thirdTile = _MetricTile(
        label: 'Unassigned',
        value: '${unassignedIncidents.length}',
        hintText: openCount > 0 ? 'of $openCount open' : null,
        accentDotColor:
            unassignedIncidents.isNotEmpty ? AppColors.syncPending : null,
        subtitle: unassignedSubtitle,
        isSelected:
            filterState.assignmentFilter == DashboardAssignmentFilter.unassigned,
        onTap: () =>
            _toggleAssignmentFilter(DashboardAssignmentFilter.unassigned),
      );
    } else {
      thirdTile = _MetricTile(
        label: 'Assigned to Me',
        value: '${myOpenIncidents.length}',
        hintText: openCount > 0 ? 'of $openCount open' : null,
        subtitle: myOpenIncidents.isEmpty
            ? 'None active'
            : '$myInProgress In Progress · $myCritical Critical',
        isSelected: filterState.assignmentFilter ==
            DashboardAssignmentFilter.assignedToMe,
        onTap: () =>
            _toggleAssignmentFilter(DashboardAssignmentFilter.assignedToMe),
      );
    }

    final pendingTotal = syncState.pendingCount + syncState.failedCount;
    final Color syncDotColor;
    final String syncSubtitle;

    if (syncState.isSyncing) {
      syncDotColor = AppColors.syncSyncing;
      syncSubtitle = 'Syncing now...';
    } else if (syncState.failedCount > 0) {
      syncDotColor = AppColors.syncFailed;
      syncSubtitle = '${syncState.failedCount} failed · Tap to retry';
    } else if (syncState.pendingCount > 0) {
      syncDotColor = AppColors.syncPending;
      syncSubtitle = '${syncState.pendingCount} queued · Tap to sync';
    } else {
      syncDotColor = AppColors.syncSynced;
      syncSubtitle = syncState.lastSyncedAt != null
          ? 'Synced · ${DateTimeFormatter.compactTimeAgo(syncState.lastSyncedAt!)}'
          : 'All synced';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: openTile),
            const SizedBox(width: 10),
            Expanded(child: criticalTile),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: thirdTile),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label:
                    syncState.failedCount > 0 ? 'Sync Failed' : 'Pending Sync',
                value: '$pendingTotal',
                accentDotColor: syncDotColor,
                subtitle: syncSubtitle,
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
  final String? hintText;
  final String subtitle;
  final Color? accentDotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    this.hintText,
    required this.subtitle,
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const Spacer(),
                if (hintText != null)
                  Text(
                    hintText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryText.withValues(alpha: 0.8),
                    ),
                  ),
                if (accentDotColor != null) ...[
                  if (hintText != null) const SizedBox(width: 6),
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
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? activeBorder
                    : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
