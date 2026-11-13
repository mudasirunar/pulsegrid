import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/database/local_data_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_overflow_menu.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../resources/domain/entities/resource_log_entity.dart';
import '../../../resources/domain/entities/resource_summary_item.dart';
import '../../../resources/domain/repositories/resource_repository.dart';
import '../../../resources/presentation/cubit/resource_cubit.dart';
import '../../../resources/presentation/widgets/incident_resource_summary_card.dart';
import '../../../sync/domain/services/sync_engine.dart';
import '../../data/models/assignment_model.dart';
import '../../domain/entities/activity_event_entity.dart';
import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/logic/incident_permissions.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';
import 'create_incident_screen.dart';
import '../widgets/incident_details_skeleton.dart';
import '../widgets/incident_lifecycle_stepper.dart';
import '../widgets/incident_location_display.dart';
import '../widgets/incident_photo_preview.dart';
import '../widgets/incident_status_actions.dart';
import '../widgets/incident_timeline_view.dart';
import '../widgets/responder_picker_bottom_sheet.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentEntity? incident;
  final String? incidentId;
  final UserEntity currentUser;
  final bool isLoading;
  final ResourceCubit? resourceCubit;

  const IncidentDetailsScreen({
    super.key,
    this.incident,
    this.incidentId,
    required this.currentUser,
    this.isLoading = false,
    this.resourceCubit,
  }) : assert(
          incident != null || incidentId != null,
          'Either incident or incidentId must be provided',
        );

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _FallbackResourceRepository implements ResourceRepository {
  const _FallbackResourceRepository();

  @override
  Stream<void> get onResourcesChanged => const Stream.empty();

  @override
  Future<ResourceLogEntity> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ResourceLogEntity>> getResourceLogs(String incidentId) async => const [];

  @override
  Future<List<ResourceSummaryItem>> getResourceSummary(String incidentId) async => const [];
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  IncidentEntity? _incident;
  AssignmentModel? _assignment;
  Map<String, String> _responderNames = const {};
  bool _isLoadingIncident = false;
  List<ActivityEventEntity> _timeline = [];
  bool _isLoadingTimeline = true;
  late final ResourceCubit _resourceCubit;
  bool _ownsCubit = false;
  ScopedIncidentSubscription? _scopedSyncSubscription;
  StreamSubscription<String>? _tableSubscription;
  StreamSubscription<String>? _remoteDeleteSubscription;
  bool _hasShownRemoteDeleteDialog = false;
  bool _isDeletingSelf = false;

  final AppOverflowMenuController _overflowMenuController =
      AppOverflowMenuController();

  @override
  void initState() {
    super.initState();
    if (widget.resourceCubit != null) {
      _resourceCubit = widget.resourceCubit!;
      _ownsCubit = false;
    } else if (di.sl.isRegistered<ResourceCubit>()) {
      _resourceCubit = di.sl<ResourceCubit>();
      _ownsCubit = true;
    } else if (di.sl.isRegistered<ResourceRepository>()) {
      _resourceCubit = ResourceCubit(resourceRepository: di.sl<ResourceRepository>());
      _ownsCubit = true;
    } else {
      _resourceCubit = ResourceCubit(resourceRepository: const _FallbackResourceRepository());
      _ownsCubit = true;
    }

    _incident = widget.incident;
    _isLoadingIncident = widget.isLoading || _incident == null;
    final incId = widget.incident?.id ?? widget.incidentId;

    if (!_isLoadingIncident && _incident != null) {
      _fetchTimeline();
      _resourceCubit.loadResources(_incident!.id);
    } else if (widget.incidentId != null) {
      _fetchIncidentById(widget.incidentId!);
    }

    if (incId != null && di.sl.isRegistered<LocalDataSource>()) {
      _loadAssignment(incId);
    }
    _loadResponderNames();

    // Scoped live WebSocket listener: mirrors remote resource logs & events into SQLite
    if (incId != null && di.sl.isRegistered<SyncEngine>()) {
      final syncEngine = di.sl<SyncEngine>();
      _scopedSyncSubscription = syncEngine.watchIncidentDetails(incId);
      _remoteDeleteSubscription = syncEngine.onIncidentDeletedRemote.listen((deletedId) {
        if (!mounted || _isDeletingSelf || _hasShownRemoteDeleteDialog) return;
        if (deletedId == incId) {
          _showRemoteDeletedDialog();
        }
      });
    }

    // Local reactive listener: re-renders timeline or incident quietly on SQLite updates
    if (di.sl.isRegistered<LocalDataSource>()) {
      _tableSubscription = di.sl<LocalDataSource>().onTableChanged.listen((table) {
        if (!mounted) return;
        if (table == DatabaseConstants.tableActivityEvents) {
          _fetchTimelineQuietly();
        } else if (table == DatabaseConstants.tableIncidents && incId != null) {
          _refreshIncidentQuietly(incId);
        } else if (table == DatabaseConstants.tableAssignments && incId != null) {
          _loadAssignment(incId);
        }
      });
    }
  }

  Future<void> _loadAssignment(String incidentId) async {
    try {
      final assignment =
          await di.sl<LocalDataSource>().getAssignmentByIncidentId(incidentId);
      if (mounted && assignment != _assignment) {
        setState(() => _assignment = assignment);
      }
    } catch (_) {}
  }

  Future<void> _loadResponderNames() async {
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final responders = await repo.getResponders();
      if (!mounted) return;
      setState(() {
        _responderNames = {
          for (final r in responders) r.id: r.displayName,
        };
      });
    } catch (_) {}
  }

  void _openResponderPicker(IncidentEntity currentIncident) {
    final repo = context.read<IncidentBloc>().incidentRepository;
    ResponderPickerBottomSheet.show(
      context,
      incidentId: currentIncident.id,
      currentUser: widget.currentUser,
      currentResponderId: _assignment?.responderId,
      repository: repo,
      onAssigned: () {
        if (di.sl.isRegistered<LocalDataSource>()) {
          _loadAssignment(currentIncident.id);
        }
        _fetchTimelineQuietly();
      },
    );
  }

  String? _resolveAssignedResponderName() {
    final assignment = _assignment;
    if (assignment == null) return null;
    final known = _responderNames[assignment.responderId];
    if (known != null && known.trim().isNotEmpty) return known;

    for (final event in _timeline) {
      if (event.eventType == ActivityEventType.assignmentChange &&
          event.newValue != null &&
          event.newValue!.trim().isNotEmpty) {
        return event.newValue!.trim();
      }
    }

    if (assignment.responderId == widget.currentUser.id &&
        widget.currentUser.displayName.trim().isNotEmpty) {
      return widget.currentUser.displayName;
    }
    return 'Responder';
  }

  void _showRemoteDeletedDialog() {
    if (_hasShownRemoteDeleteDialog || !mounted) return;
    _hasShownRemoteDeleteDialog = true;
    _overflowMenuController.closeImmediate();
    AppDialog.show<void>(
      context: context,
      title: 'Incident Deleted',
      message:
          'This incident was deleted by another user or device and is no longer available.',
      icon: Icons.delete_forever_outlined,
      isDestructive: true,
      barrierDismissible: false,
      cancelText: null,
      confirmText: 'Go Back',
      onConfirm: () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  Future<void> _onEditPressed() async {
    final currentIncident = _incident;
    if (currentIncident == null) return;
    final bloc = context.read<IncidentBloc>();
    final result = await Navigator.of(context).push<IncidentEntity?>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: CreateIncidentScreen(
            currentUser: widget.currentUser,
            existingIncident: currentIncident,
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _incident = result);
      _fetchTimeline();
    }
  }

  void _onDeletePressed() {
    final currentIncident = _incident;
    if (currentIncident == null) return;
    final bloc = context.read<IncidentBloc>();
    bool didDeleteSucceed = false;
    String? errorMsg;

    AppDialog.show<void>(
      context: context,
      title: 'Delete Incident',
      message:
          'Are you sure you want to permanently delete "${currentIncident.title}"? This action cannot be undone.',
      icon: Icons.delete_outline_rounded,
      isDestructive: true,
      confirmText: 'Delete',
      onAsyncConfirm: () async {
        _isDeletingSelf = true;
        if (di.sl.isRegistered<SyncEngine>()) {
          di.sl<SyncEngine>().markSelfDeleting(currentIncident.id);
        }

        final futureResult = bloc.stream.firstWhere(
          (s) => s is IncidentDeletedSuccess || s is IncidentOperationFailure,
        );
        bloc.add(
          DeleteIncidentEvent(
            incidentId: currentIncident.id,
            actor: widget.currentUser,
          ),
        );

        final resState = await futureResult;
        if (resState is IncidentDeletedSuccess) {
          didDeleteSucceed = true;
          if (di.sl.isRegistered<SyncEngine>()) {
            di.sl<SyncEngine>().triggerPush();
          }
        } else if (resState is IncidentOperationFailure) {
          _isDeletingSelf = false;
          errorMsg = resState.message;
        }
      },
    ).then((_) {
      if (!mounted) return;
      if (didDeleteSucceed) {
        AppSnackBar.showSuccess(
          context,
          'Incident deleted',
          title: 'Deleted',
        );
        Navigator.of(context).pop();
      } else if (errorMsg != null) {
        AppSnackBar.showError(context, errorMsg!);
      }
    });
  }

  @override
  void dispose() {
    _overflowMenuController.closeImmediate();
    _remoteDeleteSubscription?.cancel();
    _scopedSyncSubscription?.cancel();
    _tableSubscription?.cancel();
    if (_ownsCubit) {
      _resourceCubit.close();
    }
    super.dispose();
  }

  Future<void> _fetchTimelineQuietly() async {
    final currentIncident = _incident;
    if (currentIncident == null) return;
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final events = await repo.getActivityTimeline(currentIncident.id);
      if (mounted) {
        setState(() {
          _timeline = events;
          _isLoadingTimeline = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshIncidentQuietly(String id) async {
    try {
      final repo = context.read<IncidentBloc>().incidentRepository;
      final fetched = await repo.getIncidentById(id);
      if (mounted && fetched != null) {
        setState(() {
          _incident = fetched;
        });
      }
    } catch (_) {}
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
          _resourceCubit.loadResources(fetched.id);
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
    if (targetStatus == IncidentStatus.assigned) {
      _openResponderPicker(currentIncident);
      return;
    }
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
    final canModify = IncidentPermissions.canEditOrDelete(
      incident: currentIncident,
      user: widget.currentUser,
      assignment: _assignment,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          if (canModify)
            AppOverflowMenu(
              controller: _overflowMenuController,
              items: [
                AppOverflowMenuItem(
                  label: 'Edit',
                  onTap: _onEditPressed,
                ),
                AppOverflowMenuItem(
                  label: 'Delete',
                  isDestructive: true,
                  onTap: _onDeletePressed,
                ),
              ],
            ),
        ],
      ),
      body: BlocProvider.value(
        value: _resourceCubit,
        child: BlocConsumer<IncidentBloc, IncidentState>(
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
          } else if (state is IncidentLoaded) {
            final updated = state.incidents.firstWhere(
              (inc) => inc.id == currentIncident.id,
              orElse: () => currentIncident,
            );
            if (updated != _incident) {
              setState(() => _incident = updated);
            }
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
                // 1. Top Eyebrow Badges: Category & Severity on the left, Status on the right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Category + Severity Pills
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Category Pill
                          Flexible(
                            child: Container(
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
                                    size: 14,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      currentIncident.category,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                                  size: 14,
                                  color: _severityColor(currentIncident.severity),
                                ),
                                const SizedBox(width: 5),
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
                    ),
                    const SizedBox(width: 8),

                    // Right: Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Incident Title
                Text(
                  currentIncident.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Metadata Lines
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
                const SizedBox(height: 24),

                // 3. Location Details
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
                const SizedBox(height: 24),

                // 4. Evidence Photo Preview
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

                // 5. Description
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
                  currentIncident.description.trim().isEmpty
                      ? 'No description provided'
                      : currentIncident.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: currentIncident.description.trim().isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: currentIncident.description.trim().isEmpty
                        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

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
                if (IncidentPermissions.canActOnIncident(
                  incident: currentIncident,
                  user: widget.currentUser,
                  assignment: _assignment,
                )) ...[
                  IncidentStatusActions(
                    status: currentIncident.status,
                    currentUser: widget.currentUser,
                    isOperating: isOperating,
                    onTransition: _onTransitionStatus,
                  ),
                  if (_assignment != null) const SizedBox(height: 12),
                ],
                if (_assignment != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Assigned to ${_resolveAssignedResponderName() ?? 'Responder'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.currentUser.role == UserRole.coordinator)
                        TextButton(
                          onPressed: isOperating
                              ? null
                              : () => _openResponderPicker(currentIncident),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 24),

                // 8. Allocated Emergency Resources
                IncidentResourceSummaryCard(
                  incidentId: currentIncident.id,
                  currentUser: widget.currentUser,
                  canLogResources: IncidentPermissions.canActOnIncident(
                    incident: currentIncident,
                    user: widget.currentUser,
                    assignment: _assignment,
                  ),
                  onResourceLogged: _fetchTimeline,
                ),
                const SizedBox(height: 24),

                // 9. Activity Timeline
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
