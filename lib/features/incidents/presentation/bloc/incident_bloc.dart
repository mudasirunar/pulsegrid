import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/incident_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/repositories/incident_repository.dart';
import 'incident_event.dart';
import 'incident_state.dart';

class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final IncidentRepository incidentRepository;
  static const _uuid = Uuid();
  StreamSubscription<void>? _incidentsSubscription;

  IncidentStatus? _lastStatusFilter;
  IncidentSeverity? _lastSeverityFilter;
  String? _lastSearchQuery;

  IncidentBloc({
    required this.incidentRepository,
    IncidentState initialState = const IncidentInitial(),
  }) : super(initialState) {
    on<LoadIncidentsEvent>(_onLoadIncidents);
    on<CreateIncidentEvent>(_onCreateIncident);
    on<UpdateIncidentStatusEvent>(_onUpdateIncidentStatus);
    on<UpdateIncidentEvent>(_onUpdateIncident);
    on<DeleteIncidentEvent>(_onDeleteIncident);
    on<AssignResponderEvent>(_onAssignResponder);

    _incidentsSubscription = incidentRepository.onIncidentsChanged.listen((_) {
      if (state is! IncidentCreating && state is! IncidentOperating) {
        add(LoadIncidentsEvent(
          statusFilter: _lastStatusFilter,
          severityFilter: _lastSeverityFilter,
          searchQuery: _lastSearchQuery,
          isQuiet: true,
        ));
      }
    });
  }

  Future<void> _onLoadIncidents(
    LoadIncidentsEvent event,
    Emitter<IncidentState> emit,
  ) async {
    _lastStatusFilter = event.statusFilter;
    _lastSeverityFilter = event.severityFilter;
    _lastSearchQuery = event.searchQuery;

    if (!event.isQuiet) {
      emit(const IncidentLoading());
    }
    try {
      final incidents = await incidentRepository.getIncidents(
        statusFilter: event.statusFilter,
        severityFilter: event.severityFilter,
        searchQuery: event.searchQuery,
      );
      emit(IncidentLoaded(incidents));
    } catch (e) {
      if (!event.isQuiet) {
        emit(IncidentError(e.toString()));
      }
    }
  }

  Future<void> _onCreateIncident(
    CreateIncidentEvent event,
    Emitter<IncidentState> emit,
  ) async {
    emit(const IncidentCreating());
    try {
      final now = DateTime.now().toUtc();
      final incident = IncidentEntity(
        id: 'inc-${_uuid.v4().substring(0, 8)}',
        title: event.title.trim(),
        category: event.category.trim(),
        severity: event.severity,
        description: event.description.trim(),
        status: IncidentStatus.newIncident,
        version: 1,
        latitude: event.latitude,
        longitude: event.longitude,
        manualLocationNotes: event.manualLocationNotes?.trim(),
        photoPaths: event.allPhotoPaths,
        createdBy: event.creator.id,
        createdAt: now,
        updatedAt: now,
      );

      final created = await incidentRepository.createIncident(incident);
      final refreshed = await incidentRepository.getIncidents(
        statusFilter: _lastStatusFilter,
        severityFilter: _lastSeverityFilter,
        searchQuery: _lastSearchQuery,
      );
      emit(IncidentCreatedSuccess(created, incidents: refreshed));
    } catch (e) {
      emit(IncidentError(e.toString()));
    }
  }

  Future<void> _onUpdateIncidentStatus(
    UpdateIncidentStatusEvent event,
    Emitter<IncidentState> emit,
  ) async {
    final currentList = state is IncidentLoaded
        ? (state as IncidentLoaded).incidents
        : state is IncidentCreatedSuccess
            ? (state as IncidentCreatedSuccess).incidents
            : state is IncidentOperationSuccess
                ? (state as IncidentOperationSuccess).incidents
                : <IncidentEntity>[];
    emit(IncidentOperating(currentList));
    try {
      final updated = await incidentRepository.updateIncidentStatus(
        incidentId: event.incidentId,
        targetStatus: event.targetStatus,
        actor: event.actor,
      );
      final refreshed = await incidentRepository.getIncidents(
        statusFilter: _lastStatusFilter,
        severityFilter: _lastSeverityFilter,
        searchQuery: _lastSearchQuery,
      );
      emit(IncidentOperationSuccess(
        message: 'Status updated to ${event.targetStatus.displayName}',
        incidents: refreshed,
        incident: updated,
      ));
    } catch (e) {
      emit(IncidentOperationFailure(e.toString().replaceAll('Exception: ', '')));
      emit(IncidentLoaded(currentList));
    }
  }

  List<IncidentEntity> _extractCurrentList() {
    final s = state;
    if (s is IncidentLoaded) return s.incidents;
    if (s is IncidentCreatedSuccess) return s.incidents;
    if (s is IncidentOperationSuccess) return s.incidents;
    if (s is IncidentDeletedSuccess) return s.incidents;
    if (s is IncidentOperating) return s.incidents;
    return <IncidentEntity>[];
  }

  Future<void> _onUpdateIncident(
    UpdateIncidentEvent event,
    Emitter<IncidentState> emit,
  ) async {
    final currentList = _extractCurrentList();
    emit(IncidentOperating(currentList));
    try {
      final updated = await incidentRepository.updateIncident(
        updatedIncident: event.updatedIncident,
        actor: event.actor,
      );
      final refreshed = await incidentRepository.getIncidents(
        statusFilter: _lastStatusFilter,
        severityFilter: _lastSeverityFilter,
        searchQuery: _lastSearchQuery,
      );
      emit(IncidentOperationSuccess(
        message: 'Incident updated successfully',
        incidents: refreshed,
        incident: updated,
      ));
    } catch (e) {
      emit(IncidentOperationFailure(e.toString().replaceAll('Exception: ', '')));
      emit(IncidentLoaded(currentList));
    }
  }

  Future<void> _onDeleteIncident(
    DeleteIncidentEvent event,
    Emitter<IncidentState> emit,
  ) async {
    final currentList = _extractCurrentList();
    emit(IncidentOperating(currentList));
    try {
      await incidentRepository.deleteIncident(
        incidentId: event.incidentId,
        actor: event.actor,
      );
      final refreshed = await incidentRepository.getIncidents(
        statusFilter: _lastStatusFilter,
        severityFilter: _lastSeverityFilter,
        searchQuery: _lastSearchQuery,
      );
      emit(IncidentDeletedSuccess(
        incidentId: event.incidentId,
        message: 'Incident deleted',
        incidents: refreshed,
      ));
    } catch (e) {
      emit(IncidentOperationFailure(e.toString().replaceAll('Exception: ', '')));
      emit(IncidentLoaded(currentList));
    }
  }

  Future<void> _onAssignResponder(
    AssignResponderEvent event,
    Emitter<IncidentState> emit,
  ) async {
    final currentList = _extractCurrentList();
    emit(IncidentOperating(currentList));
    try {
      final updated = await incidentRepository.assignResponder(
        incidentId: event.incidentId,
        responder: event.responder,
        actor: event.actor,
      );
      final refreshed = await incidentRepository.getIncidents(
        statusFilter: _lastStatusFilter,
        severityFilter: _lastSeverityFilter,
        searchQuery: _lastSearchQuery,
      );
      final responderName = event.responder.displayName.trim().isNotEmpty
          ? event.responder.displayName.trim()
          : event.responder.email;
      emit(IncidentOperationSuccess(
        message: 'Assigned to $responderName',
        incidents: refreshed,
        incident: updated,
      ));
    } catch (e) {
      emit(IncidentOperationFailure(e.toString().replaceAll('Exception: ', '')));
      emit(IncidentLoaded(currentList));
    }
  }

  @override
  Future<void> close() {
    _incidentsSubscription?.cancel();
    return super.close();
  }
}

