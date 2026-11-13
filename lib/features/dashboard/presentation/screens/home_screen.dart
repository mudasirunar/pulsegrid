import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/local_data_source.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/data/models/user_model.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/bloc/incident_event.dart';
import '../../../incidents/presentation/bloc/incident_state.dart';
import '../../../sync/domain/entities/sync_operation_entity.dart';
import '../../../sync/domain/services/sync_engine.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import '../widgets/dashboard_filter_sheet.dart';
import '../widgets/dashboard_filter_state.dart';
import '../widgets/dashboard_incident_list.dart';
import '../widgets/dashboard_metrics_grid.dart';
import '../widgets/dashboard_search_bar.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final ScrollController? scrollController;

  const HomeScreen({
    super.key,
    required this.user,
    this.scrollController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  DashboardFilterState _filterState = const DashboardFilterState();
  Map<String, String> _incidentAssignees = {};
  Map<String, String> _incidentAssigneeNames = {};
  Map<String, SyncStatus> _incidentSyncStates = {};
  StreamSubscription<Map<String, String>>? _userNamesSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardMetadata();
    if (di.sl.isRegistered<SyncEngine>()) {
      _userNamesSubscription = di.sl<SyncEngine>().onUserNamesUpdated.listen((_) {
        if (mounted) _loadDashboardMetadata();
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.displayName != widget.user.displayName) {
      _loadDashboardMetadata();
    }
  }

  @override
  void dispose() {
    _userNamesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardMetadata() async {
    if (!di.sl.isRegistered<LocalDataSource>()) return;
    try {
      final local = di.sl<LocalDataSource>();
      final assignments = await local.getAllAssignments();
      final syncOps = await local.getAllSyncOperations();

      final assignees = <String, String>{};
      for (final a in assignments) {
        assignees[a.incidentId] = a.responderId;
      }

      final responderNames = <String, String>{};
      if (di.sl.isRegistered<IncidentRepository>()) {
        final responders = await di.sl<IncidentRepository>().getResponders();
        for (final r in responders) {
          responderNames[r.id] = r.displayName;
        }
      }
      if (di.sl.isRegistered<SyncEngine>()) {
        responderNames.addAll(di.sl<SyncEngine>().latestUserNames);
      }
      responderNames[widget.user.id] = widget.user.displayName;

      final assigneeNames = <String, String>{};
      for (final entry in assignees.entries) {
        assigneeNames[entry.key] = responderNames[entry.value] ?? entry.value;
      }

      final syncMap = <String, SyncStatus>{};
      for (final op in syncOps) {
        if (op.entityType != 'INCIDENT') continue;
        final status = SyncStatus.fromString(op.syncState);
        if (status == SyncStatus.synced) continue;
        final existing = syncMap[op.entityId];
        if (existing == null ||
            _syncPriority(status) > _syncPriority(existing)) {
          syncMap[op.entityId] = status;
        }
      }

      if (mounted) {
        setState(() {
          _incidentAssignees = assignees;
          _incidentAssigneeNames = assigneeNames;
          _incidentSyncStates = syncMap;
        });
      }
    } catch (_) {
      // Safe fallback when LocalDataSource is not initialized (e.g. widget tests)
    }
  }

  int _syncPriority(SyncStatus status) {
    switch (status) {
      case SyncStatus.failed:
      case SyncStatus.conflict:
        return 3;
      case SyncStatus.syncing:
        return 2;
      case SyncStatus.pending:
        return 1;
      case SyncStatus.synced:
        return 0;
    }
  }

  List<IncidentEntity> _extractIncidents(IncidentState state) {
    if (state is IncidentLoaded) return state.incidents;
    if (state is IncidentCreatedSuccess) return state.incidents;
    if (state is IncidentOperating) return state.incidents;
    if (state is IncidentOperationSuccess) return state.incidents;
    if (state is IncidentDeletedSuccess) return state.incidents;
    return const [];
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() => _filterState = _filterState.cleared());
  }

  Future<void> _openFilterSheet() async {
    final updated = await showDashboardFilterSheet(
      context: context,
      initialState: _filterState,
      userRole: widget.user.role,
    );
    if (updated != null && mounted) {
      setState(() => _filterState = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<IncidentBloc, IncidentState>(
          listener: (_, _) => _loadDashboardMetadata(),
        ),
        BlocListener<SyncBloc, SyncState>(
          listener: (_, _) => _loadDashboardMetadata(),
        ),
      ],
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: defaultTargetPlatform == TargetPlatform.iOS
                ? ScrollViewKeyboardDismissBehavior.onDrag
                : ScrollViewKeyboardDismissBehavior.manual,
            padding: EdgeInsets.fromLTRB(
              20.0,
              14.0,
              20.0,
              math.max(
                120.0,
                math.max(
                  MediaQuery.viewPaddingOf(context).bottom + 96.0,
                  MediaQuery.viewInsetsOf(context).bottom + 24.0,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pulse Grid',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 18),
                BlocBuilder<IncidentBloc, IncidentState>(
                  builder: (context, incidentState) {
                    final allIncidents = _extractIncidents(incidentState);
                    return BlocBuilder<SyncBloc, SyncState>(
                      builder: (context, syncState) {
                        return DashboardMetricsGrid(
                          incidents: allIncidents,
                          incidentAssignees: _incidentAssignees,
                          currentUserId: widget.user.id,
                          userRole: widget.user.role,
                          syncState: syncState,
                          filterState: _filterState,
                          onFilterChanged: (updated) =>
                              setState(() => _filterState = updated),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                DashboardSearchBar(
                  controller: _searchController,
                  filterState: _filterState,
                  onSearchChanged: (value) => setState(
                    () => _filterState =
                        _filterState.copyWith(searchQuery: value),
                  ),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(
                      () => _filterState =
                          _filterState.copyWith(searchQuery: ''),
                    );
                  },
                  onOpenFilters: _openFilterSheet,
                  onFilterChanged: (updated) =>
                      setState(() => _filterState = updated),
                  onClearAllFilters: _clearAllFilters,
                ),
                const SizedBox(height: 18),
                BlocBuilder<IncidentBloc, IncidentState>(
                  builder: (context, state) {
                    final allIncidents = _extractIncidents(state);
                    final visibleIncidents = _filterState.apply(
                      allIncidents,
                      incidentAssignees: _incidentAssignees,
                      currentUserId: widget.user.id,
                    );
                    return DashboardIncidentList(
                      incidentState: state,
                      allIncidents: allIncidents,
                      visibleIncidents: visibleIncidents,
                      incidentAssigneeNames: _incidentAssigneeNames,
                      incidentSyncStates: _incidentSyncStates,
                      user: widget.user,
                      onRetryLoad: () => context
                          .read<IncidentBloc>()
                          .add(const LoadIncidentsEvent()),
                      onClearFilters: _clearAllFilters,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
