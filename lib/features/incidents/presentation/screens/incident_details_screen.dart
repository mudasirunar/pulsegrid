import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import '../widgets/incident_lifecycle_stepper.dart';
import '../widgets/incident_location_display.dart';
import '../widgets/incident_photo_preview.dart';
import '../widgets/incident_status_actions.dart';
import '../widgets/incident_timeline_view.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentEntity incident;
  final UserEntity currentUser;

  const IncidentDetailsScreen({
    super.key,
    required this.incident,
    required this.currentUser,
  });

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  late IncidentEntity _incident;
  List<ActivityEventEntity> _timeline = [];
  bool _isLoadingTimeline = true;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    setState(() => _isLoadingTimeline = true);
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final events = await repo.getActivityTimeline(_incident.id);
      if (mounted) {
        setState(() {
          _timeline = events;
          _isLoadingTimeline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTimeline = false);
      }
    }
  }

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

  void _onTransitionStatus(IncidentStatus targetStatus) {
    context.read<IncidentBloc>().add(
          UpdateIncidentStatusEvent(
            incidentId: _incident.id,
            targetStatus: targetStatus,
            actor: widget.currentUser,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: AppBadge(
                text: 'v${_incident.version}',
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
      body: BlocConsumer<IncidentBloc, IncidentState>(
        listener: (context, state) {
          if (state is IncidentOperationSuccess) {
            AppSnackBar.show(
              context,
              message: state.message,
              type: AppSnackBarType.success,
            );
            final updated = state.incidents.firstWhere(
              (inc) => inc.id == _incident.id,
              orElse: () => _incident,
            );
            setState(() => _incident = updated);
            _fetchTimeline();
          } else if (state is IncidentOperationFailure) {
            AppSnackBar.show(
              context,
              message: state.message,
              type: AppSnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          final isOperating = state is IncidentOperating;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Chips (Category, Severity, Status)
                Row(
                  children: [
                    AppBadge(
                      text: _incident.category.toUpperCase(),
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      text: _incident.severity.displayName.toUpperCase(),
                      color: _severityColor(_incident.severity),
                    ),
                    const Spacer(),
                    AppBadge(
                      text: _incident.status.displayName.toUpperCase(),
                      color: _statusColor(_incident.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Title & Metadata
                Text(
                  _incident.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(
                                Icons.person_outline,
                                size: 14,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: 'Reported by ${_incident.createdBy == widget.currentUser.id && widget.currentUser.displayName.trim().isNotEmpty ? widget.currentUser.displayName : _incident.createdBy}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      softWrap: true,
                      maxLines: 2,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 14,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(_incident.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Divider
                Divider(
                  height: 32,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),

                // 3. Evidence Photo Preview
                if (_incident.photoPaths.isNotEmpty) ...[
                  Text(
                    'ATTACHED EVIDENCE PHOTOS (${_incident.photoPaths.length})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IncidentPhotoPreview(photoPaths: _incident.photoPaths),
                  const SizedBox(height: 24),
                ],

                // 4. Description
                Text(
                  'INCIDENT DESCRIPTION',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _incident.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Location Details
                Text(
                  'LOCATION & GEODATA',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                IncidentLocationDisplay(
                  latitude: _incident.latitude,
                  longitude: _incident.longitude,
                  manualLocationNotes: _incident.manualLocationNotes,
                ),

                // Divider
                Divider(
                  height: 36,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),

                // 6. Sequential Lifecycle Stepper
                Text(
                  'LIFECYCLE STATE MACHINE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                IncidentLifecycleStepper(currentStatus: _incident.status),
                const SizedBox(height: 18),

                // 7. Status Transition Actions
                IncidentStatusActions(
                  status: _incident.status,
                  currentUser: widget.currentUser,
                  isOperating: isOperating,
                  onTransition: _onTransitionStatus,
                ),

                // Divider
                Divider(
                  height: 40,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),

                // 8. Chronological Activity Timeline
                Text(
                  'CHRONOLOGICAL ACTIVITY TIMELINE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                IncidentTimelineView(
                  timeline: _timeline,
                  isLoading: _isLoadingTimeline,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
