import 'package:equatable/equatable.dart';

/// Pure domain entity representing an aggregated resource total for an incident.
class ResourceSummaryItem extends Equatable {
  final String resourceType;
  final double totalQuantity;
  final String unit;

  const ResourceSummaryItem({
    required this.resourceType,
    required this.totalQuantity,
    required this.unit,
  });

  /// Formatted display string, e.g. "120 Liters" or "5.5 Boxes"
  String get formattedTotal {
    final qtyStr = totalQuantity.truncateToDouble() == totalQuantity
        ? totalQuantity.toInt().toString()
        : totalQuantity.toStringAsFixed(1);
    return '$qtyStr $unit';
  }

  @override
  List<Object?> get props => [resourceType, totalQuantity, unit];
}

