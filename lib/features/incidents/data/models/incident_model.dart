import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../../core/database/database_constants.dart';

class IncidentModel extends Equatable {
  final String id;
  final String title;
  final String category;
  final String severity; // Low, Medium, High, Critical
  final String description;
  final String status; // New, Assigned, In Progress, Resolved, Closed
  final int version;
  final double? latitude;
  final double? longitude;
  final String? manualLocationNotes;
  final List<String> photoPaths;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentModel({
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
    this.photoPaths = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String? get photoPath => photoPaths.isNotEmpty ? photoPaths.first : null;

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colId: id,
      DatabaseConstants.colTitle: title,
      DatabaseConstants.colCategory: category,
      DatabaseConstants.colSeverity: severity,
      DatabaseConstants.colDescription: description,
      DatabaseConstants.colStatus: status,
      DatabaseConstants.colVersion: version,
      DatabaseConstants.colLatitude: latitude,
      DatabaseConstants.colLongitude: longitude,
      DatabaseConstants.colManualLocationNotes: manualLocationNotes,
      DatabaseConstants.colPhotoPath: photoPaths.isEmpty ? null : jsonEncode(photoPaths),
      DatabaseConstants.colCreatedBy: createdBy,
      DatabaseConstants.colCreatedAt: createdAt.toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  factory IncidentModel.fromMap(Map<String, dynamic> map) {
    final rawPhoto = map[DatabaseConstants.colPhotoPath];
    List<String> photos = [];
    if (rawPhoto is List) {
      photos = rawPhoto.map((e) => e.toString()).toList();
    } else if (rawPhoto is String && rawPhoto.isNotEmpty) {
      if (rawPhoto.startsWith('[')) {
        try {
          final decoded = jsonDecode(rawPhoto);
          if (decoded is List) {
            photos = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          photos = [rawPhoto];
        }
      } else {
        photos = [rawPhoto];
      }
    }

    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        try {
          // Supports Cloud Firestore Timestamp without direct import
          final dynamic dyn = val;
          return dyn.toDate() as DateTime;
        } catch (_) {}
        try {
          return DateTime.parse(val.toString());
        } catch (_) {}
      }
      return DateTime.now();
    }

    return IncidentModel(
      id: (map[DatabaseConstants.colId] ?? '').toString(),
      title: (map[DatabaseConstants.colTitle] ?? '').toString(),
      category: (map[DatabaseConstants.colCategory] ?? 'Other').toString(),
      severity: (map[DatabaseConstants.colSeverity] ?? 'Medium').toString(),
      description: (map[DatabaseConstants.colDescription] ?? '').toString(),
      status: (map[DatabaseConstants.colStatus] ?? 'New').toString(),
      version: (map[DatabaseConstants.colVersion] as num?)?.toInt() ?? 1,
      latitude: (map[DatabaseConstants.colLatitude] as num?)?.toDouble(),
      longitude: (map[DatabaseConstants.colLongitude] as num?)?.toDouble(),
      manualLocationNotes: map[DatabaseConstants.colManualLocationNotes]?.toString(),
      photoPaths: photos,
      createdBy: (map[DatabaseConstants.colCreatedBy] ?? 'Unknown').toString(),
      createdAt: parseDate(map[DatabaseConstants.colCreatedAt]),
      updatedAt: parseDate(map[DatabaseConstants.colUpdatedAt]),
    );
  }

  IncidentModel copyWith({
    String? id,
    String? title,
    String? category,
    String? severity,
    String? description,
    String? status,
    int? version,
    double? latitude,
    double? longitude,
    String? manualLocationNotes,
    List<String>? photoPaths,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncidentModel(
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
      photoPaths: photoPaths ?? this.photoPaths,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        photoPaths,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
