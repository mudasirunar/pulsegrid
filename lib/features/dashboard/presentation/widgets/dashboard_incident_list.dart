import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/presentation/bloc/incident_state.dart';
import '../../../incidents/presentation/screens/incident_details_screen.dart';
import '../../../incidents/presentation/widgets/incident_card.dart';
import '../../../sync/domain/entities/sync_operation_entity.dart';

/// Renders the dashboard incident feed with loading, error, empty,
/// and filtered-empty states.
class DashboardIncidentList extends StatelessWidget {
  final IncidentState incidentState;
  final List<IncidentEntity> allIncidents;
  final List<IncidentEntity> visibleIncidents;
  final Map<String, SyncStatus> incidentSyncStates;
  final UserModel user;
  final VoidCallback onRetryLoad;
  final VoidCallback onClearFilters;

  const DashboardIncidentList({
    super.key,
    required this.incidentState,
    required this.allIncidents,
    required this.visibleIncidents,
    required this.incidentSyncStates,
    required this.user,
    required this.onRetryLoad,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (incidentState is IncidentLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (incidentState is IncidentError) {
      final error = incidentState as IncidentError;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          children: [
            Text(
              'Could not load incidents',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetryLoad,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (allIncidents.isEmpty) {
      return _EmptyFeedState(
        title: 'No incidents reported yet',
        subtitle: user.role.isReadOnly
            ? 'Reported field incidents will appear here.'
            : 'Tap + below to report a new field incident.',
        secondaryText: secondaryText,
      );
    }

    if (visibleIncidents.isEmpty) {
      return _EmptyFeedState(
        title: 'No matching incidents',
        subtitle: 'Try adjusting your search or filters.',
        secondaryText: secondaryText,
        actionLabel: 'Clear Filters',
        onAction: onClearFilters,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'INCIDENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: secondaryText,
              ),
            ),
            Text(
              '${visibleIncidents.length} of ${allIncidents.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleIncidents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final incident = visibleIncidents[index];
            return IncidentCard(
              incident: incident,
              syncStatus: incidentSyncStates[incident.id],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailsScreen(
                      incident: incident,
                      currentUser: user,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color secondaryText;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyFeedState({
    required this.title,
    required this.subtitle,
    required this.secondaryText,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondaryText),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

