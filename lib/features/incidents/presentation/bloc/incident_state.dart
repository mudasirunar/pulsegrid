import 'package:equatable/equatable.dart';

import '../../domain/entities/incident_entity.dart';

abstract class IncidentState extends Equatable {
  const IncidentState();

  @override
  List<Object?> get props => [];
}

class IncidentInitial extends IncidentState {
  const IncidentInitial();
}

class IncidentLoading extends IncidentState {
  const IncidentLoading();
}

class IncidentLoaded extends IncidentState {
  final List<IncidentEntity> incidents;

  const IncidentLoaded(this.incidents);

  @override
  List<Object?> get props => [incidents];
}

class IncidentCreating extends IncidentState {
  const IncidentCreating();
}

class IncidentCreatedSuccess extends IncidentState {
  final IncidentEntity incident;
  final List<IncidentEntity> incidents;

  const IncidentCreatedSuccess(
    this.incident, {
    this.incidents = const [],
  });

  @override
  List<Object?> get props => [incident, incidents];
}

class IncidentOperating extends IncidentState {
  final List<IncidentEntity> incidents;

  const IncidentOperating([this.incidents = const []]);

  @override
  List<Object?> get props => [incidents];
}

class IncidentOperationSuccess extends IncidentState {
  final String message;
  final List<IncidentEntity> incidents;
  final IncidentEntity? incident;

  const IncidentOperationSuccess({
    required this.message,
    this.incidents = const [],
    this.incident,
  });

  @override
  List<Object?> get props => [message, incidents, incident];
}

class IncidentDeletedSuccess extends IncidentState {
  final String incidentId;
  final String message;
  final List<IncidentEntity> incidents;

  const IncidentDeletedSuccess({
    required this.incidentId,
    required this.message,
    this.incidents = const [],
  });

  @override
  List<Object?> get props => [incidentId, message, incidents];
}

class IncidentOperationFailure extends IncidentState {
  final String message;

  const IncidentOperationFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class IncidentError extends IncidentState {
  final String message;

  const IncidentError(this.message);

  @override
  List<Object?> get props => [message];
}

