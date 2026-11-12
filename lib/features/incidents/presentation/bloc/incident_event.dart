import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';

abstract class IncidentEvent extends Equatable {
  const IncidentEvent();

  @override
  List<Object?> get props => [];
}

class LoadIncidentsEvent extends IncidentEvent {
  final IncidentStatus? statusFilter;
  final IncidentSeverity? severityFilter;
  final String? searchQuery;
  final bool isQuiet;

  const LoadIncidentsEvent({
    this.statusFilter,
    this.severityFilter,
    this.searchQuery,
    this.isQuiet = false,
  });

  @override
  List<Object?> get props => [statusFilter, severityFilter, searchQuery, isQuiet];
}

class CreateIncidentEvent extends IncidentEvent {
  final String title;
  final String category;
  final IncidentSeverity severity;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? manualLocationNotes;
  final List<String> photoPaths;
  final String? photoPath;
  final UserEntity creator;

  const CreateIncidentEvent({
    required this.title,
    required this.category,
    required this.severity,
    required this.description,
    this.latitude,
    this.longitude,
    this.manualLocationNotes,
    this.photoPaths = const [],
    this.photoPath,
    required this.creator,
  });

  List<String> get allPhotoPaths =>
      photoPaths.isNotEmpty ? photoPaths : (photoPath != null ? [photoPath!] : const []);

  @override
  List<Object?> get props => [
        title,
        category,
        severity,
        description,
        latitude,
        longitude,
        manualLocationNotes,
        photoPaths,
        photoPath,
        creator,
      ];
}

class UpdateIncidentStatusEvent extends IncidentEvent {
  final String incidentId;
  final IncidentStatus targetStatus;
  final UserEntity actor;

  const UpdateIncidentStatusEvent({
    required this.incidentId,
    required this.targetStatus,
    required this.actor,
  });

  @override
  List<Object?> get props => [incidentId, targetStatus, actor];
}

