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
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        try {
          final dynamic dyn = val;
          return dyn.toDate() as DateTime;
        } catch (_) {}
        try {
          return DateTime.parse(val.toString());
        } catch (_) {}
      }
      return DateTime.now();
    }

    return ResourceLogModel(
      id: (map[DatabaseConstants.colId] ?? '').toString(),
      incidentId: (map[DatabaseConstants.colIncidentId] ?? '').toString(),
      resourceType: (map[DatabaseConstants.colResourceType] ?? '').toString(),
      quantity: (map[DatabaseConstants.colQuantity] as num?)?.toDouble() ?? 0.0,
      unit: (map[DatabaseConstants.colUnit] ?? '').toString(),
      notes: map[DatabaseConstants.colNotes]?.toString(),
      loggedBy: (map[DatabaseConstants.colLoggedBy] ?? '').toString(),
      createdAt: parseDate(map[DatabaseConstants.colCreatedAt]),
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

