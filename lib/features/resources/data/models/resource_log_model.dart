import 'package:equatable/equatable.dart';
import '../../../../core/database/database_constants.dart';

class ResourceLogModel extends Equatable {
  final String id;
  final String incidentId;
  final String resourceType;
  final double quantity;
  final String unit;
  final String? notes;
  final String loggedBy;
  final DateTime createdAt;

  const ResourceLogModel({
    required this.id,
    required this.incidentId,
    required this.resourceType,
    required this.quantity,
    required this.unit,
    this.notes,
    required this.loggedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colId: id,
      DatabaseConstants.colIncidentId: incidentId,
      DatabaseConstants.colResourceType: resourceType,
      DatabaseConstants.colQuantity: quantity,
      DatabaseConstants.colUnit: unit,
      DatabaseConstants.colNotes: notes,
      DatabaseConstants.colLoggedBy: loggedBy,
      DatabaseConstants.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory ResourceLogModel.fromMap(Map<String, dynamic> map) {
    return ResourceLogModel(
      id: map[DatabaseConstants.colId] as String,
      incidentId: map[DatabaseConstants.colIncidentId] as String,
      resourceType: map[DatabaseConstants.colResourceType] as String,
      quantity: (map[DatabaseConstants.colQuantity] as num).toDouble(),
      unit: map[DatabaseConstants.colUnit] as String,
      notes: map[DatabaseConstants.colNotes] as String?,
      loggedBy: map[DatabaseConstants.colLoggedBy] as String,
      createdAt: DateTime.parse(map[DatabaseConstants.colCreatedAt] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        incidentId,
        resourceType,
        quantity,
        unit,
        notes,
        loggedBy,
        createdAt,
      ];
}

