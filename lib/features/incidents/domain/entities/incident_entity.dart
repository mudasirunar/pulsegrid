import 'package:equatable/equatable.dart';

import '../../data/models/incident_model.dart';
import 'incident_severity.dart';
import 'incident_status.dart';

/// Pure Domain Entity representing an Incident.
/// Minimum fields enforced by Section 4 (Important Data Rules) of the PRD:
/// [id, title, category, severity, description, status, createdAt, updatedAt, version, latitude, longitude]
class IncidentEntity extends Equatable {
  final String id;
  final String title;
  final String category;
  final IncidentSeverity severity;
  final String description;
  final IncidentStatus status;
  final int version;
  final double? latitude;
  final double? longitude;
  final String? manualLocationNotes;
  final String? photoPath;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.description,
    required this.status,
    this.version = 1,
    this.latitude,
    this.longitude,
    this.manualLocationNotes,
    this.photoPath,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  IncidentEntity copyWith({
    String? id,
    String? title,
    String? category,
    IncidentSeverity? severity,
    String? description,
    IncidentStatus? status,
    int? version,
    double? latitude,
    double? longitude,
    String? manualLocationNotes,
    String? photoPath,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncidentEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      status: status ?? this.status,
      version: version ?? this.version,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      manualLocationNotes: manualLocationNotes ?? this.manualLocationNotes,
      photoPath: photoPath ?? this.photoPath,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  IncidentModel toModel() {
    return IncidentModel(
      id: id,
      title: title,
      category: category,
      severity: severity.value,
      description: description,
      status: status.value,
      version: version,
      latitude: latitude,
      longitude: longitude,
      manualLocationNotes: manualLocationNotes,
      photoPath: photoPath,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory IncidentEntity.fromModel(IncidentModel model) {
    return IncidentEntity(
      id: model.id,
      title: model.title,
      category: model.category,
      severity: IncidentSeverity.fromString(model.severity),
      description: model.description,
      status: IncidentStatus.fromString(model.status),
      version: model.version,
      latitude: model.latitude,
      longitude: model.longitude,
      manualLocationNotes: model.manualLocationNotes,
      photoPath: model.photoPath,
      createdBy: model.createdBy,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        severity,
        description,
        status,
        version,
        latitude,
        longitude,
        manualLocationNotes,
        photoPath,
        createdBy,
        createdAt,
        updatedAt,
      ];
}

