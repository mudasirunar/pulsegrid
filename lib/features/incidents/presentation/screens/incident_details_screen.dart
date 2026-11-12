import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import '../widgets/incident_details_skeleton.dart';
import '../widgets/incident_lifecycle_stepper.dart';
import '../widgets/incident_location_display.dart';
import '../widgets/incident_photo_preview.dart';
import '../widgets/incident_status_actions.dart';
import '../widgets/incident_timeline_view.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentEntity? incident;
  final String? incidentId;
  final UserEntity currentUser;
  final bool isLoading;

  const IncidentDetailsScreen({
    super.key,
    this.incident,
    this.incidentId,
    required this.currentUser,
    this.isLoading = false,
  }) : assert(
          incident != null || incidentId != null,
          'Either incident or incidentId must be provided',
        );

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  IncidentEntity? _incident;
  bool _isLoadingIncident = false;
  List<ActivityEventEntity> _timeline = [];
  bool _isLoadingTimeline = true;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    _isLoadingIncident = widget.isLoading || _incident == null;
    if (!_isLoadingIncident && _incident != null) {
      _fetchTimeline();
    } else if (widget.incidentId != null) {
      _fetchIncidentById(widget.incidentId!);
    }
  }

  Future<void> _fetchIncidentById(String id) async {
    setState(() => _isLoadingIncident = true);
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final fetched = await repo.getIncidentById(id);
      if (mounted) {
        setState(() {
          _incident = fetched;
          _isLoadingIncident = false;
        });
        if (fetched != null) {
          _fetchTimeline();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingIncident = false);
      }
    }
  }

  Future<void> _fetchTimeline() async {
    final currentIncident = _incident;
    if (currentIncident == null) return;
    setState(() => _isLoadingTimeline = true);
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final events = await repo.getActivityTimeline(currentIncident.id);
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
    final currentIncident = _incident;
    if (currentIncident == null) return;
    context.read<IncidentBloc>().add(
          UpdateIncidentStatusEvent(
            incidentId: currentIncident.id,
            targetStatus: targetStatus,
            actor: widget.currentUser,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // While loading or before data is available: render smooth skeleton with NO status chip in AppBar!
    if (_isLoadingIncident || _incident == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Incident Details'),
          actions: const [],
        ),
        body: const IncidentDetailsSkeleton(),
      );
    }

    final currentIncident = _incident!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(currentIncident.status).withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusColor(currentIncident.status).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor(currentIncident.status),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentIncident.status.displayName.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(currentIncident.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
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
              (inc) => inc.id == currentIncident.id,
              orElse: () => currentIncident,
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
                // 1. Incident Title
                Text(
                  currentIncident.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Metadata Lines
                // Line 1: Reported by [Reporter Name] • [Relative Time]
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reported by ${_resolveReporterName(currentIncident.createdBy)} • ${_formatTimeAgo(currentIncident.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Line 2: Clock Icon + Exact Timestamp
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(currentIncident.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Category & Severity Badges
                Row(
                  children: [
                    // Category Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcon(currentIncident.category),
                            size: 15,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentIncident.category,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Severity Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _severityColor(currentIncident.severity).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _severityColor(currentIncident.severity).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.crisis_alert_rounded,
                            size: 15,
                            color: _severityColor(currentIncident.severity),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentIncident.severity.displayName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _severityColor(currentIncident.severity),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Evidence Photo Preview
                if (currentIncident.photoPaths.isNotEmpty) ...[
                  Text(
                    'ATTACHED EVIDENCE PHOTOS (${currentIncident.photoPaths.length})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IncidentPhotoPreview(photoPaths: currentIncident.photoPaths),
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
                  currentIncident.description,
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
                  latitude: currentIncident.latitude,
                  longitude: currentIncident.longitude,
                  manualLocationNotes: currentIncident.manualLocationNotes,
                ),
                const SizedBox(height: 28),

                // 6. Sequential Lifecycle Stepper
                Text(
                  'LIFECYCLE STATE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                IncidentLifecycleStepper(currentStatus: currentIncident.status),
                const SizedBox(height: 18),

                // 7. Status Transition Actions
                IncidentStatusActions(
                  status: currentIncident.status,
                  currentUser: widget.currentUser,
                  isOperating: isOperating,
                  onTransition: _onTransitionStatus,
                ),
                const SizedBox(height: 28),

                // 8. Activity Timeline
                Text(
                  'ACTIVITY TIMELINE',
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
                  currentUser: widget.currentUser,
                  incident: currentIncident,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _resolveReporterName(String createdBy) {
    if (createdBy == widget.currentUser.id && widget.currentUser.displayName.trim().isNotEmpty) {
      return widget.currentUser.displayName;
    }
    if (createdBy == 'user-coordinator-01') return 'Sarah Chen';
    if (createdBy == 'user-responder-01') return 'Marcus Vance';
    if (createdBy == 'user-viewer-01') return 'Auditor Evans';

    final isRawId = RegExp(r'^[0-9a-fA-F-]{28,}$').hasMatch(createdBy) ||
        (createdBy.length >= 20 && !createdBy.contains(' '));
    if (isRawId) {
      return widget.currentUser.displayName.trim().isNotEmpty
          ? widget.currentUser.displayName
          : widget.currentUser.role.displayName;
    }
    return createdBy;
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm • $day-$month-$year';
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day-$month-${dt.year}';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Medical':
        return Icons.medical_services_outlined;
      case 'Fire':
        return Icons.local_fire_department_outlined;
      case 'Hazmat':
        return Icons.warning_amber_rounded;
      case 'Structural Collapse':
        return Icons.domain_disabled_outlined;
      case 'Search & Rescue':
        return Icons.person_search_outlined;
      case 'Infrastructure':
        return Icons.electrical_services_outlined;
      case 'Evacuation':
        return Icons.directions_run_outlined;
      case 'Other':
      default:
        return Icons.more_horiz_rounded;
    }
  }
}
