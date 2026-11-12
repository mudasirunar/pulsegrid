import 'package:equatable/equatable.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/models/resource_log_model.dart';

/// Pure domain entity representing a resource logged against an incident.
/// Section 4.2: Resource Logging specifications.
class ResourceLogEntity extends Equatable {
  final String id;
  final String incidentId;
  final String resourceType;
  final double quantity;
  final String unit;
  final String? notes;
  final String loggedBy;
  final DateTime createdAt;

  const ResourceLogEntity({
    required this.id,
    required this.incidentId,
    required this.resourceType,
    required this.quantity,
    required this.unit,
    this.notes,
    required this.loggedBy,
    required this.createdAt,
  });

  /// Standard emergency resource categories for dropdowns and selection
  static const List<String> standardTypes = [
    'Water',
    'First Aid Kits',
    'Oxygen Tanks',
    'Blankets',
    'Food Rations',
    'Fuel',
    'Medical Kits',
    'Other',
  ];

  /// Recommended default units mapped to resource categories
  static const Map<String, String> defaultUnits = {
    'Water': 'Liters',
    'First Aid Kits': 'Kits',
    'Oxygen Tanks': 'Tanks',
    'Blankets': 'Units',
    'Food Rations': 'Packs',
    'Fuel': 'Liters',
    'Medical Kits': 'Kits',
    'Other': 'Units',
  };

  /// Common emergency unit options for selection
  static const List<String> standardUnits = [
    'Liters',
    'Kits',
    'Tanks',
    'Units',
    'Packs',
    'Boxes',
    'Bags',
    'Crates',
    'Persons',
  ];

  /// Validates resource logging inputs per PRD §4.2:
  /// - Quantities must strictly be greater than zero (> 0)
  /// - Type, unit, incidentId, and loggedBy must not be empty
  static void validate({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    required String loggedBy,
  }) {
    if (incidentId.trim().isEmpty) {
      throw const ValidationException('Incident ID cannot be empty.');
    }
    if (resourceType.trim().isEmpty) {
      throw const ValidationException('Resource type cannot be empty.');
    }
    if (unit.trim().isEmpty) {
      throw const ValidationException('Unit cannot be empty.');
    }
    if (loggedBy.trim().isEmpty) {
      throw const ValidationException('Logged by actor cannot be empty.');
    }
    if (quantity <= 0) {
      throw const ValidationException('Resource quantity must be greater than zero.');
    }
  }

  /// Converts this domain entity to the database persistence model
  ResourceLogModel toModel() {
    return ResourceLogModel(
      id: id,
      incidentId: incidentId,
      resourceType: resourceType,
      quantity: quantity,
      unit: unit,
      notes: notes,
      loggedBy: loggedBy,
      createdAt: createdAt,
    );
  }

  /// Reconstructs a domain entity from the database persistence model
  factory ResourceLogEntity.fromModel(ResourceLogModel model) {
    return ResourceLogEntity(
      id: model.id,
      incidentId: model.incidentId,
      resourceType: model.resourceType,
      quantity: model.quantity,
      unit: model.unit,
      notes: model.notes,
      loggedBy: model.loggedBy,
      createdAt: model.createdAt,
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

